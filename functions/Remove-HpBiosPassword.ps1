FUNCTION Remove-HpBiosPassword {
    <#
    .SYNOPSIS
    Remove HP BIOS password
    
    .DESCRIPTION
    This function'll remove HP BIOS password
    
    .PARAMETER ExecutionScenario
    Specify during what scenario the function'll be used
    
    .EXAMPLE
    Remove-HpBiosPassword
    Remove-HpBiosPassword -ExecutionScenario Debug
    
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
        try {
            # Backup current password, and used backuped password for execution
            Write-Log -Message "Attempting to backup: $currentBiosPassword"
            $backupPassword = Join-Path -Path (Split-Path -Path $currentBiosPassword) -ChildPath "backupCurrentBiosPwd.bin"
            if (-not (Test-Path -Path $backupPassword)) {
                Copy-Item -Path $currentBiosPassword -Destination $backupPassword -ErrorAction Stop
                Write-Log -Message "Successfully backuped BIOS-password to $backupPassword"
            }
            else {
                Write-Log -Message "Password-file is already backupped"
            }
            try {
                # remove BIOS-password
                Write-Log -Message "Attempting to execute BIOS Configuration Utility to remove BIOS-password"
                # Create arguments
                $arguments = "/cpwdfile:`"$backupPassword`" /npwdfile:`"`""
                
                Write-Log -Message "Arguments: $arguments"
                # Execute the Config Utility
                $process = Start-HpProcess -PathToExe $biosConfigurationUtility -Arguments $arguments -ErrorAction Stop
                # Check if process exit is approved
                if ($process.ExitCode -eq 0) {
                    Write-Log -Message "Successfully removed BIOS-password"
                    return ($LASTEXITCODE = 0)
                }
                else {
                    Write-Log -Message "Failed to remove BIOS-password!"
                    throw "Failed to remove BIOS-password, exit code: $($process.ExitCode), message: $($process.Output)"
                }                
            }
            catch {
                Write-Log -Message "Failed to remove BIOS-password, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
                Write-Error -ErrorRecord $_
            }            
        }
        catch {
            Write-Log -Message "Failed to backup BIOS-password, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)" -MessageType Error
            Write-Error -ErrorRecord $_
        }
    }
}