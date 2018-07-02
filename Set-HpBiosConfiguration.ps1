[CmdletBinding()]
param(
    ## Specify what exit codes are considered as success, default: 0, 1, 5, 13, 17 (See HP-documentation for more info)
    [Parameter(Mandatory = $false, HelpMessage = "Specify list of approved exit codes")]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApprovedExitCodes = @(0, 1, 5, 13, 17),
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
    ## Path to where folders containing computer model are stored
    $computerModelFolders = (Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "BiosFiles")).FullName
    
    ## Bios utility
    if ((Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture -match '64') {
        $biosTool = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosConfigUtility\BiosConfigUtility64.exe"
    }
    else {
        $biosTool = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosConfigUtility\BiosConfigUtility.exe"
    }

    ## Bios password
    $biosPassword = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosPassword\BiosConfig.bin"
    
    ## Computer model
    $computerModel = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
    $computerModel = $computerModel.TrimStart('HP').TrimStart('Hewlett-Packard').TrimStart('')
    
    ## Log path
    if (-not($DebugMode)) {
        $tsEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Continue
        $logDirectory = Join-Path -Path $tsEnvironment.Value("_SMSTSLogPath")
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

    ## Test if bios utility is present
    Write-Log -Message "Attempting to test if $biosTool is present"
    if (-not(Test-Path -Path $biosTool)) {
        Write-Log -Message "Failed to locate BIOS-tool, check if path is correct" -MessageType Warning ; break
    }
    
    ## Test if bios password is present
    Write-Log -Message "Attempting to test if $biosPassword is present"
    if (-not(Test-Path -Path $biosPassword)) {
        Write-Log -Message "Failed to locate BIOS-tool, check if path is correct" -MessageType Warning ; break
    }
    
    ## Get computer model folder
    foreach ($modelFolder in $computerModelFolders) {
        if ($modelFolder -match $computerModel) {
            Write-Log -Message "Found matching folder: $modelFolder"
            try {
                ## Get correct BIOS-config file based on last write time
                Write-Log -Message "Attempting to get .REPSET-file"
                if (-not($ConvertToUefi)) {
                    $biosFile = (Get-ChildItem -Path $modelFolder -Recurse -Filter *.REPSET -Exclude *EFI* -ErrorAction Stop `
                            | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName                
                }
                else {
                    $biosFile = (Get-ChildItem -Path $modelFolder -Recurse -Filter *.REPSET -Include *EFI* -ErrorAction Stop `
                            | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName                
                } 
                try {
                    ## Configure bios
                    Write-Log -Message "Attempting to configure HP-bios using: $biosFile"
                    $process = Start-Process -FilePath $biosTool -ArgumentList "/set:`"$biosFile`" /cspwd:`"$biosPassword`"" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                    ## Check if exit code is approved
                    if ($ApprovedExitCodes -contains $process.ExitCode) {
                        Write-Log -Message "Successfully configured BIOS, exit code: $($process.ExitCode)"
                        [System.Environment]::Exit(0)
                    }
                    else {
                        Write-Log -Message "Failed to configure BIOS, exit code: $($process.ExitCode)"
                        [System.Environment]::Exit($process.ExitCode)
                    }
                }
                catch {
                    Write-Log -Message "Failed to execute process, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error
                }

            }
            catch {
                Write-Log -Message "Failed to get .REPSET-file, line: $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -MessageType Error
            }
            break
        }
    }
}

