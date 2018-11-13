FUNCTION Set-HpBiosPassword {
    <#
    .SYNOPSIS
    Set HP BIOS password
    
    .DESCRIPTION
    This function'll set HP BIOS password
    
    .PARAMETER ChangeBiosPassword
    Specify this if you want to change BIOS password

    .PARAMETER ExecutionScenario
    Specify during what scenario the function'll be used
    
    .EXAMPLE
    Set-HpBiosPassword
    Set-HpBiosPassword -ChangeBiosPassword
    Set-HpBiosPassword -ExecutionScenario Debug
    
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
        [Parameter(Mandatory = $false, HelpMessage = "Specify this if you want to change old BIOS-password", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [switch]$ChangeBiosPassword,
        [Parameter(Mandatory = $false, HelpMessage = "Specify execution scenario (OSD, Debug, OS)", Position = 1)]
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
        try {
            # Get Current password file
            Write-Log -Message "Attempting to get current password file path"
            $currentBiosPassword = Get-HpRequiredFiles -FileType CurrentPasswordFile -ErrorAction Stop
            Write-Log -Message "Located current password, path: $currentBiosPassword"
            try {
                # Get bios configuration utility
                Write-Log -Message "Attempting to get BIOS configuration utility path"
                $biosConfigurationUtility = Get-HpRequiredFiles -FileType ConfigurationUtility -ErrorAction Stop
                Write-Log -Message "Located BIOS configuration utility, path: $biosConfigurationUtility"
                # Locate old password if changebiospassword specified
                if ($ChangeBiosPassword) {
                    try {
                        Write-Log -Message "Attempting to get old password file path"
                        $oldBiosPassword = Get-HpRequiredFiles -FileType OldPasswordFile -ErrorAction Stop
                        Write-Log -Message "Located old password, path: $oldBiosPassword"
                    }
                    catch {
                        Write-Log -Message "Failed to get old password path, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
                        Write-Error -ErrorRecord $_
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to get BIOS configuration utility path, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
                Write-Error -ErrorRecord $_
            }
        }
        catch {
            Write-Log -Message "Failed to get current password path, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
            Write-Error -ErrorRecord $_
        }
    }
    Process {
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
        try {
            # Set BIOS-password
            Write-Log -Message "Attempting to execute BIOS Configuration Utility to set BIOS-password"
            # Create arguments based on the execution type
            if (-not($ChangeBiosPassword)) {
                $arguments = "/npwdfile:`"$backupPassword`""
            } 
            else {
                $arguments = "/cpwdfile:`"$oldBiosPassword`" /npwdfile:`"$backupPassword`""
            }
            Write-Log -Message "Arguments: $arguments"
            # Execute the Config Utility
            $process = Start-HpProcess -PathToExe $biosConfigurationUtility -Arguments $arguments -ErrorAction Stop
            # Check if process exit is approved
            if ($process.ExitCode -eq 0) {
                $actionSuccess = $true
            }
            elseif ($process.ExitCode -eq 10) {
                # On error ten, check if error is due to password already set or that password is invalid
                if ($process.Output | Where-Object {$_ -match "Password is set, but no password file is provided"}) {
                    $actionSuccess = $true
                }
                else {
                    $actionSuccess = $false
                }                    
            }
            else {
                $actionSuccess = $false
            }                
            # Set result based on actionSuccess
            if ($actionSuccess -eq $true) {
                Write-Log -Message "Successfully sat BIOS-password"
                return ($LASTEXITCODE = 0)
            }
            else {
                throw "Failed to set BIOS-password, exit code: $($process.ExitCode)!"
            }
        }
        catch {
            Write-Log -Message "Failed to set BIOS-password, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
            Write-Error -ErrorRecord $_
        }            
    }
}