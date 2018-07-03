<#
.SYNOPSIS
    Configure HP-Bios based on computer model.
.DESCRIPTION
    This script will configure or convert your legacy BIOS to UEFI based on computer model that is currently running the Task Sequence.
    See ReadMe for more information.
.PARAMETER ApprovedExitCodes
    Specify exit codes that are considered as 'Success', see "BIOS Configuration Utility User's Guide".
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
    .\Set-HpBiosConfiguration.ps1 -SetBiosPassword
    # Configure Legacy to UEFI
    .\Set-HpBiosConfiguration.ps1 -ConvertToUefi
    # Configure BIOS and and don't use an Bios-password
    .\Set-HpBiosConfiguration.ps1 -DontUseBiosPassword
.NOTES
    FileName:   Set-HpBiosConfiguration.ps1
    Author:     MichalKir
    Created:    2018-07-02
    Tested:     WinPE 1803
    
    Version history:
        1.0 (2018-07-02) - Created Set-HpBiosConfiguration.ps1 script
#>
[CmdletBinding()]
param(
    ## Specify what exit codes are considered as success, default: 0, 1, 5, 13, 17 (See HP-documentation for more info)
    [Parameter(Mandatory = $false, HelpMessage = "Specify list of approved exit codes")]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApprovedExitCodes = @(0, 1, 5, 13, 17),
    ## Specify if you want to convert Legacy to EFI
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to set BIOS-password during BIOS-configuration")]
    [ValidateNotNullOrEmpty()]
    [switch]$SetBiosPassword,
    ## Specify if you want to convert Legacy to EFI
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you are not using BIOS-password")]
    [ValidateNotNullOrEmpty()]
    [switch]$DontUseBiosPassword,    
    ## Specify if you want to convert Legacy to EFI
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to configure BIOS from legacy to EFI")]
    [ValidateNotNullOrEmpty()]
    [switch]$ConvertToUefi,
    ## Specify if you want to debug the app (changes log path to local path)
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to use debug mode(changes logging path to localfolder)")]
    [ValidateNotNullOrEmpty()]
    [switch]$DebugMode
)
begin {
    ############################### DO NOT CHANGE ######################################## 
    ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
    $computerModelFolders = $null
    $biosTool = $null
    $biosPassword = $null
    $computerModel = $null
    $tsEnvironment = $null
    $logDirectory = $null
    $biosPasswordPath = $null
    $biosPassword = $null
    $processPassword = $null
    $modelFolder = $null
    $computerModelFolders = $null
    $biosFile = $null
    $argumentConfig = $null
    $processBiosConfig = $null
    ############################### DO NOT CHANGE - END ######################################## 
    
    ## Path to where folder containing computer models-folders are stored
    $computerModelFolders = (Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "BiosFiles")).FullName
    
    ## Bios utility
    if ((Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture -match '64') {
        ## X64
        $biosTool = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosConfigUtility\BiosConfigUtility64.exe"
    }
    else {
        ## X86
        $biosTool = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosConfigUtility\BiosConfigUtility.exe"
    }

    ## Test if HP BIOS-utility is present
    Write-Log -Message "Attempting to test if $biosTool is present"
    if (-not(Test-Path -Path $biosTool)) {
        Write-Log -Message "Failed to locate BIOS-tool, check if path is correct" -MessageType Warning ; break
    }

    ## Path to BIOS-password
    if (-not($DontUseBiosPassword)) {
        $biosPassword = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosPassword\BiosConfig.bin"

        ## Test if BIOS-password is present
        Write-Log -Message "Attempting to test if $biosPassword-file is present"
        if (-not(Test-Path -Path $biosPassword)) {
            Write-Log -Message "Failed to locate BIOS-tool, check if path is correct" -MessageType Warning ; break
        }
    }
    
    ## Computer model
    $computerModel = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
    $computerModel = $computerModel.TrimStart('HP').TrimStart('Hewlett-Packard').TrimStart('')
    
    ## Log path
    if (-not($DebugMode)) {
        $tsEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Continue
        $logDirectory = $tsEnvironment.Value("_SMSTSLogPath")
    }
    else {
        $logDirectory = $PSScriptRoot
    }
}
process {
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
    
    ## Set HP-password
    if ($SetBiosPassword) {
        try {
            ## Create copy of BIOS-password, some config utility versions do remove BIOS-password when used to set bios-password
            Write-Log -Message "Attempting to create copy of BIOS-password"
            $biosPasswordPath = Join-Path -Path (Split-Path -Path $biosPassword) -ChildPath 'setPassword.bin'
            Copy-Item -Path $biosPassword -Destination $biosPasswordPath -ErrorAction Stop > $null
            try {
                ## Set BIOS-password
                Write-Log -Message "Attempting to set BIOS-password"
                $processPassword = Start-Process -FilePath $biosTool -ArgumentList "/nspwd:`"$biosPasswordPath`"" `
                    -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                ## Handle exit code 10 as success(error 10 occurs when bios password is already present)                                    
                if (($processPassword.ExitCode -eq '10') -or ($processPassword.ExitCode -eq '0')) {
                    Write-Log -Message "Set BIOS password exited with: $($processPassword.ExitCode)"
                    $Global:LASTEXITCODE = 0
                }
                else {
                    Write-Log -Message "Set BIOS password exited with: $($processPassword.ExitCode)" -MessageType Error                  
                    [System.Environment]::Exit($processPassword.ExitCode)
                }
            }
            catch {
                Write-Log -Message "Failed to set HP-Bios password, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error
            }
        }
        catch {
            Write-Log -Message "Failed to copy BIOS-password, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error
        }
    }    
    ## Get computer model folder
    foreach ($modelFolder in $computerModelFolders) {
        ## If computer model folder is matching WMI ComputerModel, execute the configuration
        if ($modelFolder -match $computerModel) {
            Write-Log -Message "Found matching folder: $modelFolder"
            try {
                ## Get correct BIOS-config file based on last write time
                Write-Log -Message "Attempting to get .REPSET-file"                
                if (-not($ConvertToUefi)) {
                    ## Search for regular BIOS-password
                    $biosFile = (Get-ChildItem -Path $modelFolder -Recurse -Filter *.REPSET -Exclude *EFI* -ErrorAction Stop `
                            | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName                
                }
                else {
                    ## Search for legacy to uefi BIOS-file
                    $biosFile = (Get-ChildItem -Path $modelFolder -Recurse -Filter *.REPSET -Include *EFI* -ErrorAction Stop `
                            | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName                
                } 
                try {                    
                    ## Configure bios
                    Write-Log -Message "Attempting to configure HP-bios using: $biosFile"
                    if (-not($DontUseBiosPassword)) {
                        ## argument for bios that are password protected
                        $argumentConfig = "/set:`"$biosFile`" /cspwd:`"$biosPassword`""
                    }
                    else {
                        ## argument for bios that is not password protected
                        $argumentConfig = "/set:`"$biosFile`""
                    }
                    $processBiosConfig = Start-Process -FilePath $biosTool -ArgumentList $argumentConfig -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                    ## Check if exit code is approved
                    if ($ApprovedExitCodes -contains $processBiosConfig.ExitCode) {
                        Write-Log -Message "Successfully configured BIOS, exit code: $($processBiosConfig.ExitCode)"
                        [System.Environment]::Exit(0)
                    }
                    else {
                        Write-Log -Message "Failed to configure BIOS, exit code: $($processBiosConfig.ExitCode)"
                        [System.Environment]::Exit($processBiosConfig.ExitCode)
                    }
                }
                catch {
                    Write-Log -Message "Failed to execute process, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error
                }

            }
            catch {
                Write-Log -Message "Failed to get .REPSET-file, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error
            }
        }
    }
}

