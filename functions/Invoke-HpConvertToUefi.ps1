FUNCTION Invoke-HpConvertToUefi {
    <#
    .SYNOPSIS
    Convert HP-BIOS to UEFI
    
    .DESCRIPTION
    This function'll convert HP-BIOS to UEFI from .REPSET-file located in computer model folder
    
    .PARAMETER ApprovedExitCodes
    Specify approved exit codes
    
    .PARAMETER NoBiosPassword
    Specify if you are not using BIOS-password in your setup
    
    .PARAMETER ExecutionScenario
    Specify during what scenario the function'll be used
    
    .EXAMPLE
    Invoke-HpConvertToUefi
    Invoke-HpConvertToUefi -ApprovedExitCodes @(0, 1, 5) -ExecutionScenario = OSD
    
    .NOTES
    Author:         Michal Kirejczyk
    Version:        1.0.0
    Date:           2018-11-13
    What's new:
                    1.0.0 (2018-11-13) - Function created
    .LINK
    https://github.com/MichalKir/ts-hp-bios-config
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Specify approved exit codes", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ApprovedExitCodes = @(0, 1, 5, 13, 17),
        [Parameter(Mandatory = $false, HelpMessage = "Specify if there is no BIOS-password", Position = 1)]
        [ValidateNotNullOrEmpty()]
        [switch]$NoBiosPassword,
        [Parameter(Mandatory = $false, HelpMessage = "Specify execution scenario (OSD, Debug, OS)", Position = 2)]
        [ValidateSet("OSD", "OS", "Debug")]
        [string]$ExecutionScenario = "OSD"
    )
    Begin {
        # Populate default Write-Log parameters
        $functionName = $MyInvocation.MyCommand
        $PSDefaultParameterValues.Clear()
        $PSDefaultParameterValues.Add('Write-Log:ExecutionScenario', "$ExecutionScenario")
        $PSDefaultParameterValues.Add('Write-Log:FunctionName', "$functionName")
        $PSDefaultParameterValues.Add('Write-Log:ErrorAction', "SilentlyContinue")
        # If verbose write verbose
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            $PSDefaultParameterValues.Add('Write-Log:Verbose', $true)
            $PSDefaultParameterValues.Add('Get-HpRequiredFiles:Verbose', $true)
            $PSDefaultParameterValues.Add('Start-HpProcess:Verbose', $true)
        }
        # Make sure that exit code 0 is always present in approved exit codes
        if (-not($ApprovedExitCodes -contains 0)) {
            [string[]]$ApprovedExitCodes += 0
            $ApprovedExitCodes
        }
        # Search for bios password if nobiospassword is not specified
        if (-not($NoBiosPassword)) {
            try {
                # GetBios password
                Write-Log -Message "Attempting to get current password file path"
                $currentBiosPassword = Get-HpRequiredFiles -FileType CurrentPasswordFile -ErrorAction Stop
                Write-Log -Message "Located current password, path: $currentBiosPassword"
            }
            catch {
                Write-Log -Message "Failed to get current password path, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
                Write-Error -ErrorRecord $_
            }                        
        }
        try {
            # Get bios config file
            Write-Log -Message "Attempting to get BIOS to UEFI configuration file"
            $biosConfigurationFile = Get-HpRequiredFiles -FileType ConvertToUefiFile -ErrorAction Stop
            Write-Log -Message "Located BIOS to UEFI configuration file, path: $biosConfigurationFile"
            try {
                # Get bios configuration utility
                Write-Log -Message "Attempting to get BIOS configuration utility path"
                $biosConfigurationUtility = Get-HpRequiredFiles -FileType ConfigurationUtility -ErrorAction Stop
                Write-Log -Message "Located BIOS configuration utility, path: $biosConfigurationUtility"
            }
            catch {
                Write-Log -Message "Failed to get BIOS configuration utility path, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
                Write-Error -ErrorRecord $_
            }
        }
        catch {
            Write-Log -Message "Failed to get BIOS to UEFI configuration file path, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
            Write-Error -ErrorRecord $_
        }
    }
    Process {
        if (-not($NoBiosPassword)) {
            # Backup current password, and used backuped password for execution if needed
            $backupPassword = Join-Path -Path (Split-Path -Path $currentBiosPassword) -ChildPath "backupCurrentBiosPwd.bin"
            if (-not (Test-Path -Path $backupPassword)) {
                try {                
                    Write-Log -Message "Attempting to backup: $currentBiosPassword"
                    Copy-Item -Path $currentBiosPassword -Destination $backupPassword -ErrorAction Stop
                    Write-Log -Message "Successfully backuped BIOS-password to $backupPassword"
                }
                catch {
                    Write-Log -Message "Failed to backup BIOS-password, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
                    Write-Error -ErrorRecord $_
                }
            }
            else {
                Write-Log -Message "Password-file is already backupped"
            }
        }
        try {
            # Convert bios to uefi
            Write-Log -Message "Attempting to execute BIOS Configuration Utility to convert BIOS to UEFI"
            # Create arguments based on -NoBiosPassword
            if (-not($NoBiosPassword)) {
                $arguments = "/set:`"$biosConfigurationFile`" /cpwdfile:`"$backupPassword`""
            }
            else {
                $arguments = "/set:`"$biosConfigurationFile`""
            }
            Write-Log -Message "Arguments: $arguments"
            # Execute the Config Utility
            $process = Start-HpProcess -PathToExe $biosConfigurationUtility -Arguments $arguments -ErrorAction Stop
            # Check if exit code is approved
            if ($ApprovedExitCodes -contains $process.ExitCode) {
                Write-Log -Message "Successfully converted BIOS to UEFI, process exit code: $($process.ExitCode)"
                return ($LASTEXITCODE = 0)
            }
            else {
                throw "Failed to convert BIOS to UEFI, exit code: $($process.ExitCode)!"
            }
        }
        catch {
            Write-Log -Message "Failed to convert BIOS to UEFI, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
            Write-Error -ErrorRecord $_
        }
    }
}
