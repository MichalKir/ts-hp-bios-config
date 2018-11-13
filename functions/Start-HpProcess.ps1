FUNCTION Start-HpProcess {
    <#
    .SYNOPSIS
    Execute HP-related processes
    
    .DESCRIPTION
    This function is used to execute HP-processes
    
    .PARAMETER PathToExe
    Provide path to the process-file
    
    .PARAMETER Arguments
    Provide arguments for the process file
    
    .EXAMPLE
    Start-HpProcess -PathToExe (Get-HpRequiredFiles -FileType ConfigurationUtility) -Arguments "/nspwd:`"$(Get-HpRequiredFiles -FileType CurrentPasswordFile)`""
    
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
        [Parameter(Mandatory, HelpMessage = "Provide path to the .exe-file", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$PathToExe,
        [Parameter(Mandatory, HelpMessage = "Specify arguments to use with the .exe file", Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Arguments        
    )
    Process {
        try {
            # Populate default Write-Log parameters
            $functionName = $MyInvocation.MyCommand
            # Create ProcessStartInfo-object
            Write-Verbose -Message "$functionName - Attempting to create ProcessStartInfo-object"
            $processInformation = New-Object -TypeName System.Diagnostics.ProcessStartInfo
            $processInformation.FileName = "$PathToExe"
            $processInformation.RedirectStandardError = $true
            $processInformation.RedirectStandardOutput = $true
            $processInformation.UseShellExecute = $false
            $processInformation.Arguments = $Arguments
            Write-Verbose -Message "$functionName - Successfully created ProcessStartInfo-object"
            Write-Verbose -Message "path to exe: $PathToExe"
            try {
                # Create Process-object
                Write-Verbose -Message "$functionName - Attempting to create Process-object"
                $process = New-Object -TypeName System.Diagnostics.Process
                $process.StartInfo = $processInformation
                $process.Start() > $null
                $process.WaitForExit()
                # result hash table
                $objHashTable = [ordered]@{
                    "ExitCode"     = $process.ExitCode
                    "Output"       = $process.StandardOutput.ReadToEnd()
                    "ErrorMessage" = $process.StandardError.ReadToEnd()
                }
                Write-Verbose -Message "$functionName - Sucessfully created Process-object"
                return (New-Object psobject -Property $objHashTable)

            }
            catch {
                Write-Verbose -Message "$functionName - Failed to create Process-object"
                Write-Error -ErrorRecord $_
            }
        }
        catch {
            Write-Verbose -Message "$functionName - Failed to create ProcessStartInfo-object"
            Write-Error -ErrorRecord $_
        }
    }
}