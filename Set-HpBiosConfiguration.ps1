
<#
.SYNOPSIS
    Configure HP-Bios based on computer model.
.DESCRIPTION
    This script will configure or convert your legacy BIOS to UEFI based on computer model that is currently running the Task Sequence.
    See ReadMe for more information.
.PARAMETER ApprovedExitCodes
    Specify exit codes that are considered as 'Success', see "BIOS Configuration Utility User's Guide".
.PARAMETER BiosPasswordFileName
    Specify BIOS-password file name
.PARAMETER SetBiosPassword
    Specify if you want to set BIOS-password during the script execution.
.PARAMETER DontUseBiosPassword
    Specify if you don't want to use BIOS-password.
.PARAMETER ConvertToUefi
    Specify if you want to convert BIOS to UEFI, the tool will look for file that contains EFI in file name.
.PARAMETER DebugMode
    Specify if you want to run tool from Windows, the log path will change to PSScriptRoot.
.EXAMPLE
    # Configure BIOS
    .\Set-HpBiosConfiguration.ps1
    # Configure BIOS and set BIOS-password
    .\Set-HpBiosConfiguration.ps1 -BiosPasswordFileName BiosPassword.bin -SetBiosPassword
    # Configure Legacy to UEFI
    .\Set-HpBiosConfiguration.ps1 -ConvertToUefi -BiosPasswordFileName BiosPassword.bin
    # Configure BIOS and and don't use an Bios-password
    .\Set-HpBiosConfiguration.ps1 -DontUseBiosPassword
.NOTES
    FileName:   Set-HpBiosConfiguration.ps1
    Author:     MichalKir
    Created:    2018-07-06
    Tested:     WinPE 1803
    
    Version history:
        1.1 (2018-07-06) - Seperated script into functions(for Pester testing), added BiosPasswordFileName
        1.0 (2018-07-02) - Created Set-HpBiosConfiguration.ps1 script
#>
[CmdletBinding(DefaultParameterSetName = "Default")]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Specify list of approved exit codes", ParameterSetName = "Default")]
    [Parameter(Mandatory = $false, HelpMessage = "Specify list of approved exit codes", ParameterSetName = "NoPassword")]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApprovedExitCodes = @(0, 1, 5, 13, 17),
    [Parameter(Mandatory = $true, HelpMessage = "Specify BIOS-password file name", ParameterSetName = "Default")]
    [ValidateNotNullOrEmpty()]
    [string]$BiosPasswordFileName,
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to set BIOS-password during BIOS-configuration", ParameterSetName = "Default")]
    [ValidateNotNullOrEmpty()]
    [switch]$SetBiosPassword,
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you are not using BIOS-password", ParameterSetName = "NoPassword")]
    [ValidateNotNullOrEmpty()]
    [switch]$DontUseBiosPassword,
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to configure BIOS from legacy to EFI", ParameterSetName = "Default")]
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to configure BIOS from legacy to EFI", ParameterSetName = "NoPassword")]
    [ValidateNotNullOrEmpty()]
    [switch]$ConvertToUefi,
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to use debug mode(changes logging path to localfolder)", ParameterSetName = "Default")]
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to use debug mode(changes logging path to localfolder)", ParameterSetName = "NoPassword")]
    [ValidateNotNullOrEmpty()]
    [switch]$DebugMode
)
begin {
    ############################### DO NOT CHANGE ######################################## 
    ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
    $biosPasswordPath = $null
    $computerModelName = $null
    $computerModelFolder = $null
    $repsetFile = $null
    ############################### DO NOT CHANGE - END ######################################## 
    ## Get BIOS-password if used
    if (-not($DontUseBiosPassword)) {
        $biosPasswordPath = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$BiosPasswordFileName* -Include *.bin | Select-Object -First 1).FullName
        if (-not ($biosPasswordPath)) {
            throw 'BIOS-password is missing'
        }
    }

    ## Get Computer Model
    $computerModelName = ((Get-CimInstance -ClassName Win32_ComputerSystem).Model).TrimStart('HP').TrimStart('Hewlett-Packard').TrimStart('')
    ## Get Computer Model Folder Path
    $computerModelFolder = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$computerModelName* | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    ## Get .REPSET-file
    if (-not($ConvertToUefi)) {
        $repsetFile = (Get-ChildItem -Path $computerModelFolder -Recurse -Filter *.REPSET -Exclude *EFI* | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
    else {
        $repsetFile = (Get-ChildItem -Path $computerModelFolder -Recurse -Filter *.REPSET -Include *EFI* | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
    ####### FUNCTIONS
    ## Write-Log
    ## Write LOG-function
    function Write-Log {
        # Based on: https://janikvonrotz.ch/2017/10/26/powershell-logging-in-cmtrace-format/
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false, HelpMessage = "Specify log name")]
            [ValidateNotNullOrEmpty()]
            [string]$LogName = "BiosConfiguration.log",
            [Parameter(Mandatory = $true, HelpMessage = "Provide log message")]
            [ValidateNotNullOrEmpty()]
            [string]$Message,
            [Parameter(Mandatory = $false, HelpMessage = "Specify message type")]
            [ValidateSet('Information', 'Warning', 'Error')]
            [string]$MessageType = 'Information'
        )
        begin {
            ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
            $tsEnvironment = $null
            $logDirectory = $null
            $logFilePath = $null
            $constructMessage = $null

            ## LOG Variables
            if (-not($DebugMode)) {
                $tsEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Continue
                $logDirectory = $tsEnvironment.Value("_SMSTSLogPath")
            }
            else {
                $logDirectory = $PSScriptRoot
            }
            ## Manage message type
            switch ($MessageType) {
                "Information" {
                    [int]$MessageType = 1
                    Write-Host -Object $Message
                }
                "Warning" {
                    [int]$MessageType = 2
                    Write-Host -Object $Message -BackgroundColor Yellow
                }
                "Error" {
                    [int]$MessageType = 3
                    Write-Host -Object $Message -BackgroundColor Red
                }
            }
            ## Generate log file path
            $logFilePath = Join-Path -Path $logDirectory -ChildPath $LogName
            ## Construct message
            $constructMessage = "<![LOG[$Message]LOG]!>" + `
                "<time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" " + `
                "date=`"$(Get-Date -Format "M-d-yyyy")`" " + `
                "component=`"BiosConfiguration`" " + `
                "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + `
                "type=`"$Type`" " + `
                "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " + `
                "file=`"`">"
        }
        process {
            ## Append message to log file
            Add-Content -Path $logFilePath -Value $constructMessage -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }   
    ## BIOS-configuration utility
    function Invoke-HpBiosConfigurationUtility {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false, HelpMessage = "Approved exit codes for the script execution")]
            [ValidateNotNullOrEmpty()]
            [string[]]$ApprovedExitCodes = @(0),
            [Parameter(Mandatory = $true, HelpMessage = "Specify arguments that will be used for the execution")]
            [ValidateNotNullOrEmpty()]
            [string]$Arguments
        )
        begin {
            ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
            $bcuName = $null
            $bcuPath = $null
            $bcuProcess = $null

            ## Search for BIOS-utility based on system
            if ((Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture -match '64') {
                $bcuName = 'BiosConfigUtility64.exe'
            }
            else {
                $bcuName = 'BiosConfigUtility.exe'   
            }

            ## Search for file
            try {
                $bcuPath = (Get-ChildItem -Path $PSScriptRoot -Filter $bcuName -Recurse | Select-Object -First 1 -ErrorAction Stop).FullName
            }
            catch {
                Write-Log -Message "Failed to get $bcuName, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error -ErrorAction SilentlyContinue
                Write-Error -ErrorRecord $_ ; break
            }
        }
        process {
            if ($bcuPath) {
                ## Execute BCU
                try {
                    Write-Log -Message "Attempting to execute $bcuName using argument: $Arguments" -ErrorAction SilentlyContinue
                    $bcuProcess = Start-Process -FilePath $bcuPath -ArgumentList "$Arguments" -PassThru -Wait -WindowStyle Hidden -ErrorAction Stop
                    if ($ApprovedExitCodes -contains $bcuProcess.ExitCode) {
                        $LASTEXITCODE = 0
                    }
                    else {
                        Write-Log -Message "Failed to execute $bcuName, exit code: $($bcuProcess.ExitCode)" -MessageType Error -ErrorAction SilentlyContinue
                        $LASTEXITCODE = $bcuProcess.ExitCode
                        Write-Error -Message "Failed to execute $bcuName, exit code: $($bcuProcess.ExitCode)" ; break
                    }

                }
                catch {
                    Write-Log -Message "Failed to execute $bcuName, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error -ErrorAction SilentlyContinue
                    Write-Error -ErrorRecord $_
                }
            }
            else {
                Write-Log -Message "$bcuName is missing!" -MessageType Error -ErrorAction SilentlyContinue
                Write-Error -Message "$bcuName is missing!" ; break
            }
        
        }

    }
    ## Set HP BIOS Password
    function Set-HpBiosPassword {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, HelpMessage = "Specify password file")]
            [ValidateNotNullOrEmpty()]
            [ValidateScript( {
                    if (-Not ($_ | Test-Path)) {
                        throw "File is missing"
                    }
                    if ((Get-Item -Path $_).Extension -notmatch 'bin') {
                        throw "File is not .bin"
                    }
                    return $true
                })]
            [System.IO.FileInfo]$PasswordPath
        )
        begin {
            ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
            $passwordPathResolved = $null
            $passwordBackup = $null

            $passwordPathResolved = $PasswordPath.FullName
            $passwordBackup = Join-Path -Path (Split-Path -Path $passwordPath) -ChildPath 'UseThisToSetPassword.bin'
        }
        process {
            try {
                ## create backup for password file, some BCU-versiones remove the .bin-file on password set                
                if (-not(Test-Path -Path $passwordBackup)) {
                    Write-Log -Message "Attempting to make copy of $passwordPathResolved" -ErrorAction SilentlyContinue
                    try {
                        Copy-Item -Path $passwordPathResolved -Destination $passwordBackup -ErrorAction Stop
                    }
                    catch {
                        Write-Log -Message "Failed to make password backup, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error -ErrorAction SilentlyContinue
                        Write-Error -ErrorRecord $_ ; break
                    }

                }
                ## The tool is exiting with exit code 10 if password is already set, so report error 10 as success
                Invoke-HpBiosConfigurationUtility -ApprovedExitCodes @(0, 10) -Arguments "/nspwd:`"$passwordBackup`"" -ErrorAction Stop            
            }
            catch {
                Write-Log -Message "Failed to set BIOS-password, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error -ErrorAction SilentlyContinue
                Write-Error -ErrorRecord $_ ; break
            }
        }
    }

    function Invoke-ConfigureHpBios {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, HelpMessage = "Provide path to Computer Model configuration")]
            [ValidateNotNullOrEmpty()]
            [ValidateScript( {
                    if (-Not ($_ | Test-Path)) {
                        throw "File is missing"
                    }
                    if ((Get-Item -Path $_).Extension -notmatch 'REPSET') {
                        throw "File is not .REPSET"
                    }
                    return $true
                })]
            [System.IO.FileInfo]$ConfigFile,
            [Parameter(Mandatory = $false, HelpMessage = "Specify password file")]
            [ValidateNotNullOrEmpty()]
            [ValidateScript( {
                    if (-Not ($_ | Test-Path)) {
                        throw "File is missing"
                    }
                    if ((Get-Item -Path $_).Extension -notmatch 'bin') {
                        throw "File is not .bin"
                    }
                    return $true
                })]
            [System.IO.FileInfo]$PasswordPath,
            [Parameter(Mandatory = $false, HelpMessage = "Approved exit codes for the script execution")]
            [ValidateNotNullOrEmpty()]
            [string[]]$ApprovedExitCodes = @(0)
        )
        begin {
            ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
            $argument = $null
            
            if ($PasswordPath) {
                $argument = "/set:`"$ConfigFile`" /cspwd:`"$PasswordPath`""
            }
            else {
                $argument = "/set:`"$ConfigFile`""
            }
        }
        process {
            try {
                Write-Log -Message "Attempting to configure HP-BIOS using arguments: $argument" -ErrorAction SilentlyContinue
                Invoke-HpBiosConfigurationUtility -ApprovedExitCodes $ApprovedExitCodes -Arguments $argument -ErrorAction Stop
            }
            catch {
                Write-Log -Message "Failed to set BIOS-config, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error -ErrorAction SilentlyContinue
                Write-Error -ErrorRecord $_ ; break
            }
        }
    }
}
process {
    ## Set BIOS-password
    if ($SetBiosPassword) {
        try {
            Set-HpBiosPassword -PasswordPath $biosPasswordPath -ErrorAction Stop
        }
        catch {
            Write-Error -ErrorRecord $_ ; break
        }
    }
    ## Configure BIOS
    try {
        ## Command when password is specified
        if (-not($DontUseBiosPassword)) {
            Invoke-ConfigureHpBios -ConfigFile $repsetFile -ApprovedExitCodes $ApprovedExitCodes -PasswordPath $biosPasswordPath -ErrorAction Stop
        }
        ## Command when no password is specified
        else {
            Invoke-ConfigureHpBios -ConfigFile $repsetFile -ApprovedExitCodes $ApprovedExitCodes -ErrorAction Stop
        }
    }
    catch {
        Write-Error -ErrorRecord $_ ; break
    }
}