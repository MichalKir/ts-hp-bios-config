FUNCTION Write-Log {
    <#
    .SYNOPSIS
    Write-Log in CmTrace format
    
    .DESCRIPTION
    This function is based on PSNLog and will write Log in CMTrace format
    
    .PARAMETER Message
    Specify message to log
    
    .PARAMETER MessageType
    Specify message type, information, warning or error
    
    .PARAMETER ExecutionScenario
    Specify during what scenario the function'll be used
    
    .EXAMPLE
    Write-Log -Message "Logging this message"
    Write-Log -Message "Error occured" -MessageType Error
    
    .NOTES
    Modules used:   https://github.com/MaikKoster/PSNLog
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
        [Parameter(Mandatory, HelpMessage = "Provide log message", ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [Parameter(Mandatory, HelpMessage = "Provide function name", ValueFromPipeline, Position = 1)]
        [AllowEmptyString()]
        [string]$FunctionName,
        [Parameter(Mandatory = $false, HelpMessage = "Specify message type", Position = 2)]
        [ValidateSet("Information", "Warning", "Error")]
        [string]$MessageType = "Information",
        [Parameter(Mandatory = $false, HelpMessage = "Specify leg execution scenario(OSD, Debug, OS)", Position = 2)]
        [ValidateSet("OSD", "OS", "Debug")]
        [string]$ExecutionScenario = "OSD"
    )
    Begin {
        # Get current module path
        $functionsDirectory = Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath 'functions'
        ## Set log location
        switch ($ExecutionScenario) {
            "OSD" {
                # Save to OSD log path
                try {
                    # Inititalize log location
                    Write-Verbose -Message "Attempting to inititalize TS-environment"
                    $tsEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment
                    $logPath = Join-Path -Path $tsEnvironment.Value("_SMSTSLogPath") -ChildPath  "HPBiosModule.log"
                }
                catch {
                    Write-Verbose -Message "Failed to initialize TS-environment"
                    Write-Error -ErrorRecord $_
                }
            }
            "OS" {
                $logPath = Join-Path -Path $env:windir -ChildPath "Logs\Software\HPBiosModule.log"
            }
            "Debug" {
                $logPath = Join-Path -Path (Split-Path -Path $functionsDirectory) -ChildPath "HPBiosModule.log"
            }
        }        
    }
    Process {
        try {
            # Import PSNLog-module
            Import-Module -FullyQualifiedName (Join-Path -Path $functionsDirectory -ChildPath "PSNLog") -Verbose:$false -ErrorAction Stop
            try {
                # Create CMTrace layout render
                Add-CMTraceLayoutRenderer -Component $FunctionName -ErrorAction Stop
            
                try {                               
                    # Consctruct PSNLog Target
                    $target = New-NLogFileTarget `
                        -Name $FunctionName `
                        -FileName $logPath `
                        -Layout '${cmtrace}' `
                        -ErrorAction Stop
                    try {
                        # Initialize PSNLog
                        Enable-NLogLogging -Target $target -DontRedirectMessages -ErrorAction Stop
                        try {
                            # Construct PSNLog message
                            $logger = Get-NLogLogger -ErrorAction Stop
                            Write-Verbose -Message "$functionName - $Message"                     
                            switch ($MessageType) {
                                "Information" {
                                    $logger.Info("$Message")
                                }
                                "Warning" {
                                    $logger.Warn("$Message")
                                }
                                "Error" {
                                    $logger.Error("$Message")
                                }
                            } 
                        }
                        catch {
                            Write-Error -ErrorRecord $_
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                catch {
                    Write-Error -ErrorRecord $_
                }
            }
            catch {
                Write-Error -ErrorRecord $_
            }
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
}

