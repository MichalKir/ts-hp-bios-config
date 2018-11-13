# BSD 3-Clause License
# 
# Copyright (c) 2018, Maik Koster
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#region Public module functions and data 

function Disable-NLogLogging {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    param(
    )

    process {
        do {
            if ([NLog.Logmanager]::IsLoggingEnabled()) {
                $null = [NLog.Logmanager]::DisableLogging()
            }
        } while ([NLog.Logmanager]::IsLoggingEnabled())
    }
}


function Enable-NLogLogging {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding(DefaultParameterSetName = 'ByFilename')]
    param(
        # Specifies the Filename to write log messages to.
        [Parameter(ParameterSetName = 'ByFilename', Position = 0)]
        [Alias('FullName')]
        [Alias('FilePath')]
        [string]$Filename,

        # Specifies the Target to write log messages to.
        [Parameter(ParameterSetName = 'ByTarget', Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [NLog.Targets.Target]$Target,

        # Specifies the minimum log level.
        [ValidateSet('Debug', 'Error', 'Fatal', 'Info', 'Off', 'Trace', 'Warn')]
        [Alias('MinLevel')]
        [string]$MinimumLevel = 'Debug',

        # Specifies the log message layout used to write to the file target
        [Parameter(ParameterSetName = 'ByFilename')]
        [string]$Layout = '${cmtrace}',

        # Specifies, if Messages written to Write-Verbose/Write-Host/Write-Warning/Write-Error should be
        # redirected to the logging Target automagically.
        # If set, the following configuration will be applied
        # Write-Verbose -> Log message on 'Debug' level
        # Write-Host -> Log message on 'Info' level
        # Write-Warning -> Log message on 'Warning' level
        # Write-Error -> Log message on 'Error' level
        [switch]$DontRedirectMessages
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByTarget') {
            if ([string]::IsNullOrEmpty($MinimumLevel)) {
                [NLog.Config.SimpleConfigurator]::ConfigureForTargetLogging($Target)
            }
            else {
                [NLog.Config.SimpleConfigurator]::ConfigureForTargetLogging($Target, [NLog.LogLevel]::FromString($MinimumLevel))
            }
        }
        else {
            $Target = New-NLogFileTarget -Filename $Filename -Layout $Layout
            $Config = New-Object NLog.Config.LoggingConfiguration
            $Config.AddTarget($Target)
            $Config.AddRule([NLog.LogLevel]::FromString($MinimumLevel), [NLog.LogLevel]::Fatal, $Target, "*")
            Set-NLogConfiguration -Configuration $Config
        }

        if (-Not([NLog.LogManager]::IsLoggingEnabled())) {
            [NLog.LogManager]::EnableLogging()
        }

        if (-Not($DontRedirectMessages.IsPresent)) {
            Set-MessageStreams -WriteVerbose -WriteWarning -WriteError
        }
    }
}


function Get-NLogConfiguration {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    [OutputType([NLog.Config.LoggingConfiguration])]
    param()

    process {
        if ($null -eq [NLog.LogManager]::Configuration) {
            New-Object NLog.Config.LoggingConfiguration
        }
        else {
            [NLog.LogManager]::Configuration
        }
    }
}



function Get-NLogLogger {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    [OutputType([NLog.Logger])]
    param(
        # Specifies the name of the NLog logger
        [Parameter(Position = 0)]
        [string]$LoggerName = (Get-PSCallStack)[1].Command
    )

    process {
        [NLog.LogManager]::GetLogger($LoggerName)
    }
}


function New-NLogFileTarget {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdLetBinding(DefaultParameterSetName = 'ByTypeName')]
    [OutputType([NLog.Targets.FileTarget])]
    param(
        # Specifies the Name of the target
        # If no name is supplied, a random string will be used
        [Parameter(Position = 0)]
        [string]$Name,

        # Specifies the name and path to write to.
        # This FileName string is a layout which may include instances of layout renderers. This lets
        # you use a single target to write to multiple files.
        # The following value makes NLog write logging events to files based on the log level in the
        # directory where the script runs. ${env:scriptroot}/${level}.log
        # All Debug messages will go to Debug.log, all Info messages will go to Info.log and so on.
        # You can combine as many of the layout renderers as you want to produce an arbitrary log file name.
        # If no filename is supplied, the name of the calling script will be used and written to the
        # current users %Temp% directory. if not called from a script, the name will default to 'PSNLog'
        [Parameter(Position = 1)]
        [string]$FileName,

        # Specifies the layout that is used to render the log message
        [string]$Layout,

        # Specifies the name of the file to be used for an archive.
        # It may contain a special placeholder {#####} that will be replaced with a sequence of numbers
        # depending on the archiving strategy. The number of hash characters used determines the number
        # of numerical digits to be used for numbering files.
        # warning when deleting archives files is enabled (e.g. maxArchiveFiles ), the folder of the
        # archives should different than the log files.
        [string]$ArchiveFileName,

        # Specifies the way archives are numbered.
        # Possible values:
        # - Rolling  - Rolling style numbering (the most recent is always #0 then #1, ..., #N).
        # - Sequence - Sequence style numbering. The most recent archive has the highest number.
        # - Date     - Date style numbering. The date is formatted according to the value of archiveDateFormat.
        #              Warning: combining this mode with archiveAboveSize is not supported. Archive files are not merged.
        # - DateAndSequence - Combination of Date and Sequence .Archives will be stamped with the prior period
        #                     (Year, Month, Day) datetime. The most recent archive has the highest number
        #                     (in combination with the date). The date is formatted according to the value of archiveDateFormat.
        [ValidateSet('Rolling', 'Sequence', 'Date', 'DateAndSequence')]
        [string]$ArchiveNumbering,

        # Specifies the date format used for archive numbering. Default format depends on the archive period.
        # This option works only when the "ArchiveNumbering" parameter is set to Date or DateAndSequence
        [string]$ArchiveDateFormat,

        # Specifies wheter to automatically archive log files every time the specified time passes.
        # Possible values are:
        # Day - Archive daily.
        # Hour - Archive every hour.
        # Minute - Archive every minute.
        # Month - Archive every month.
        # None - Don't archive based on time.
        # Year - Archive every year.
        # Sunday - Archive every Sunday. Introduced in NLog 4.4.4.
        # Monday - Archive every Monday. Introduced in NLog 4.4.4.
        # Tuesday - Archive every Tuesday. Introduced in NLog 4.4.4.
        # Wednesday - Archive every Wednesday. Introduced in NLog 4.4.4.
        # Thursday - Archive every Thursday. Introduced in NLog 4.4.4.
        # Friday - Archive every Friday. Introduced in NLog 4.4.4.
        # Saturday - Archive every Saturday. Introduced in NLog 4.4.4.
        [ValidateSet('Day', 'Hour', 'Minute', 'Month', 'None', 'Year', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$ArchiveEvery,

        # Specifies the maximum number of archive files that should be kept.
        # If MaxArchiveFiles is less or equal to 0, old files aren't deleted
        [int]$MaxArchiveFiles = 0,

        # Specifies whether to compress the archive files into the zip files.
        [switch]$EnableArchiveFileCompression
    )

    process {
        $FileTarget = New-NLogTarget -Name $Name -FileTarget

        if ([string]::IsNullOrEmpty($FileName)) {
            $ScriptName = Get-PSCallStack | Select-Object -Last 1 -ExpandProperty 'ScriptName'

            if ([string]::IsNullOrEmpty($ScriptName)) {
                # Default to module name if no further information is supplied.
                $ScriptName = 'PSNlog.log'
            }
            else {
                $ScriptName = (Split-Path -Path $ScriptName -Leaf) -replace '.ps1|.psm1', '.log'
            }

            $FileTarget.FileName = "$Env:Temp\$ScriptName"
        }
        else {
            $FileTarget.FileName = $FileName
        }

        if (-Not([string]::IsNullOrEmpty($Layout))) {
            $FileTarget.Layout = $Layout
        }

        # Archive settings
        if (-Not([string]::IsNullOrEmpty($ArchiveFileName))) {
            $FileTarget.ArchiveFileName = $ArchiveFileName
            $FileTarget.MaxArchiveFiles = $MaxArchiveFiles
            $FileTarget.EnableArchiveFileCompression = $enableArchiveFileCompression.IsPresent

            if (-Not([string]::IsNullOrEmpty($ArchiveNumbering))) {
                $FileTarget.ArchiveNumbering = $ArchiveNumbering

                if (($ArchiveNumbering -eq 'Date') -or ($ArchiveNumbering -eq 'DateAndSequence')) {
                    if (-Not([string]::IsNullOrEmpty($ArchiveDateFormat))) {
                        $FileTarget.ArchiveDateFormat = $ArchiveDateFormat
                    }
                }
            }

            if (-Not([string]::IsNullOrEmpty($ArchiveEvery))) {
                $FileTarget.ArchiveEvery = $ArchiveEvery
            }
        }

        $FileTarget
    }
}


function New-NLogRule {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdLetBinding(DefaultParameterSetName = 'MinLevel')]
    [OutputType([NLog.Config.LoggingRule])]
    param(
        # Specifies the Logger name pattern
        # It may include the '*' wildcard at the beginning, at the end or at both ends.
        [Parameter(ParameterSetName = 'DisabledRule', Position = 0)]
        [Parameter(ParameterSetName = 'MinLevel', Position = 0)]
        [Parameter(ParameterSetName = 'MinMaxLevel', Position = 0)]
        [string]$LoggerNamePattern = '*',

        # Specifies if the rule should be disabled by default.
        [Parameter(ParameterSetName = 'DisabledRule', Mandatory)]
        [switch]$Disabled,

        # Specifies the minimum log level needed to trigger this rule.
        [Parameter(ParameterSetName = 'MinLevel', Mandatory)]
        [Parameter(ParameterSetName = 'MinMaxLevel', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Debug', 'Error', 'Fatal', 'Info', 'Off', 'Trace', 'Warn')]
        [Alias('MinLevel')]
        [string]$MinimumLevel,

        # Specifies the maximum log level needed to trigger this rule.
        [Parameter(ParameterSetName = 'MinMaxLevel', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Debug', 'Error', 'Fatal', 'Info', 'Off', 'Trace', 'Warn')]
        [Alias('MaxLevel')]
        [string]$MaximumLevel,

        # Specifies the target to be written to when the rule matches.
        [Parameter(ParameterSetName = 'DisabledRule', Mandatory)]
        [Parameter(ParameterSetName = 'MinLevel', Mandatory)]
        [Parameter(ParameterSetName = 'MinMaxLevel', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [NLog.Targets.Target]$Target
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'DisabledRule' {New-Object NLog.Config.LoggingRule($LoggerNamePattern, $Target); break}
            'MinLevel' {New-Object NLog.Config.LoggingRule($LoggerNamePattern, [NLog.LogLevel]::FromString($MinimumLevel), $Target); break}
            'MinMaxLevel' {New-Object NLog.Config.LoggingRule($LoggerNamePattern, [NLog.LogLevel]::FromString($MinimumLevel), [NLog.LogLevel]::FromString($MaximumLevel), $Target); break}
        }
    }
}


function New-NLogTarget {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdLetBinding(DefaultParameterSetName = 'ByTypeName')]
    [OutputType([NLog.Targets.Target])]
    param(
        # Specifies the Name of the target
        # If no name is supplied, a random string will be used
        [Parameter(Position = 0)]
        [string]$Name,

        # Specifies the type name of the target.
        # Can be used to create targets not explicitly covered by any switch
        [Parameter(ParameterSetName = 'ByTypeName', Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetType,

        # Specifies to create a new NullTarget
        # NullTargets discards any log messages. Used mainly for debugging and benchmarking.
        [Parameter(ParameterSetName = 'NullTarget', Mandatory)]
        [switch]$NullTarget,

        # Specifies to create a new ConsoleTarget
        # Writes log messages to the console.
        [Parameter(ParameterSetName = 'ConsoleTarget', Mandatory)]
        [switch]$ConsoleTarget,

        # Specifies to create a new DatabaseTarget
        # Writes log messages to the database using an ADO.NET provider.
        [Parameter(ParameterSetName = 'DatabaseTarget', Mandatory)]
        [switch]$DatabaseTarget,

        # Specifies to create a new DebugTarget
        # Mock target - useful for testing.
        [Parameter(ParameterSetName = 'DebugTarget', Mandatory)]
        [switch]$DebugTarget,

        # Specifies to create a new EventLogTarget
        # Writes log message to the Event Log.
        [Parameter(ParameterSetName = 'EventLogTarget', Mandatory)]
        [switch]$EventLogTarget,

        # Specifies to create a new FileTarget
        # Writes log messages to one or more files.
        [Parameter(ParameterSetName = 'FileTarget', Mandatory)]
        [switch]$FileTarget,

        # Specifies to create a new MailTarget
        # Sends log messages by email using SMTP protocol.
        [Parameter(ParameterSetName = 'MailTarget', Mandatory)]
        [switch]$MailTarget,

        # Specifies to create a new MemoryTarget
        # Writes log messages to an ArrayList in memory for programmatic retrieval.
        [Parameter(ParameterSetName = 'MemoryTarget', Mandatory)]
        [switch]$MemoryTarget,

        # Specifies to create a new NetworkTarget
        # Sends log messages over the network.
        [Parameter(ParameterSetName = 'NetworkTarget', Mandatory)]
        [switch]$NetworkTarget,

        # Specifies to create a new NLogViewerTarget
        # Sends log messages to the remote instance of NLog Viewer.
        [Parameter(ParameterSetName = 'NLogViewerTarget', Mandatory)]
        [switch]$NLogViewerTarget,

        # Specifies to create a new PerformanceCounterTarget
        # Increments specified performance counter on each write.
        [Parameter(ParameterSetName = 'PerformanceCounterTarget', Mandatory)]
        [switch]$PerformanceCounterTarget,

        # Specifies to create a new WebServiceTarget
        # Calls the specified web service on each log message.
        [Parameter(ParameterSetName = 'WebServiceTarget', Mandatory)]
        [switch]$WebServiceTarget
    )

    process {
        $Target = $null
        switch ($PSCmdlet.ParameterSetName) {
            'ByTypeName' {
                if ($TargetType -like 'NLog.Targets.*') {
                    $Target = New-Object "$TargetType"
                }
                elseif ($TargetType -like 'Targets.*') {
                    $Target = New-Object "NLog.$TargetType"
                }
                else {
                    $Target = New-Object "NLog.Targets.$TargetType"
                }
                break
            }
            'NullTarget' {$Target = New-Object NLog.Targets.NullTarget; break}
            'ConsoleTarget' {$Target = New-Object NLog.Targets.ConsoleTarget; break}
            'DatabaseTarget' {$Target = New-Object NLog.Targets.DatabaseTarget; break}
            'DebugTarget' {$Target = New-Object NLog.Targets.DebugTarget; break}
            'EventLogTarget' {$Target = New-Object NLog.Targets.EventLogTarget; break}
            'FileTarget' {$Target = New-Object NLog.Targets.FileTarget; break}
            'MailTarget' {$Target = New-Object NLog.Targets.MailTarget; break}
            'MemoryTarget' {$Target = New-Object NLog.Targets.MemoryTarget; break}
            'NetworkTarget' {$Target = New-Object NLog.Targets.NetworkTarget; break}
            'NLogViewerTarget' {$Target = New-Object NLog.Targets.NLogViewerTarget; break}
            'PerformanceCounterTarget' {$Target = New-Object NLog.Targets.PerformanceCounterTarget; break}
            'WebServiceTarget' {$Target = New-Object NLog.Targets.WebServiceTarget; break}
        }

        if ($null -ne $Target) {
            if ([string]::IsNullOrEmpty($Name)) {
                # Generate random string
                $Name = -join ((65..90) | Get-Random -Count 6 | ForEach-Object {[char]$_})
            }
            $Target.Name = $Name
            $Target
        }
    }
}


function Read-NLogConfiguration {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    [OutputType([NLog.Config.LoggingConfiguration])]
    param(
        # Specifies the name and path to the NLog configuration file
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {(Test-Path $_) -and ((Get-Item $_).Extension -match '\.(config|nlog)')})]
        [Alias('FullName')]
        [string]$Filename
    )

    process {
        New-Object NLog.Config.XmlLoggingConfiguration($Filename, $true)
    }
}


function Set-NLogConfiguration {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdLetBinding()]
    [OutputType([NLog.Config.LoggingConfiguration])]
    param(
        # Specifies the NLog configuration
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [NLog.Config.LoggingConfiguration]$Configuration
    )

    process {
        [NLog.LogManager]::Configuration = $Configuration
        Set-ScriptRoot
    }
}


function Test-NLogLogging {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    [OutputType([boolean])]
    param()

    process {
        [NLog.Logmanager]::IsLoggingEnabled()
    }
}


function Write-NLogError {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    param(
        [Parameter(ParameterSetName = 'WithException', Mandatory)]
        [Exception]$Exception,

        [Parameter(Position = 0, ParameterSetName = 'NoException', Mandatory, ValueFromPipeline)]
        [Parameter(ParameterSetName = 'WithException')]
        [AllowNull()]
        [AllowEmptyString()]
        [Alias('Msg')]
        [string]$Message,

        [Parameter(ParameterSetName = 'ErrorRecord', Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(ParameterSetName = 'NoException')]
        [Parameter(ParameterSetName = 'WithException')]
        [System.Management.Automation.ErrorCategory]$Category,

        [Parameter(ParameterSetName = 'NoException')]
        [Parameter(ParameterSetName = 'WithException')]
        [String]$ErrorId,

        [Parameter(ParameterSetName = 'NoException')]
        [Parameter(ParameterSetName = 'WithException')]
        [Object]$TargetObject,

        [string]$RecommendedAction,

        [Alias('Activity')]
        [string]$CategoryActivity,

        [Alias('Reason')]
        [string]$CategoryReason,

        [Alias('TargetName')]
        [string]$CategoryTargetName,

        [Alias('TargetType')]
        [string]$CategoryTargetType
    )

    begin {
        $Logger = Get-NLogLogger
    }

    process {
        # Write to Log if possible
        if ($null -ne $Logger) {
            $Logger.Error($Message)
        }

        # Write to original Message Stream
        Microsoft.PowerShell.Utility\Write-Error @PSBoundParameters
    }
}


function Write-NLogHost {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    param(
        [Parameter(Position = 0)]
        [object]$Object,
        [switch]$NoNewline,
        [object]$Separator,
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor
    )

    begin {
        $Logger = Get-NLogLogger
    }

    process {
        # Write to Log if possible
        if ($null -ne $Logger) {
            $Logger.Info($Object.ToString())
        }

        # Write to original Message Stream
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
    }
}


function Write-NLogVerbose {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [Alias('Msg')]
        [string]$Message
    )

    begin {
        $Logger = Get-NLogLogger
    }

    process {
        # Write to Log if possible
        if ($null -ne $Logger) {
            $Logger.Debug($Message)
        }

        # Write to original Message Stream
        Microsoft.PowerShell.Utility\Write-Verbose @PSBoundParameters
    }
}


function Write-NLogWarning {
    <#
    .EXTERNALHELP PSNLog-help.xml
    #>
    [CmdLetBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [Alias('Msg')]
        [string]$Message
    )

    begin {
        $Logger = Get-NLogLogger
    }

    process {
        # Write to Log if possible
        if ($null -ne $Logger) {
            $Logger.Warn($Message)
        }

        # Write to original Message Stream
        Microsoft.PowerShell.Utility\Write-Warning @PSBoundParameters
    }
}


#endregion

#region Private Module functions and data

function Add-CMTraceLayoutRenderer {
    <#
        .SYNOPSIS
        Adds a CMTrace Layout Renderer

        .DESCRIPTION
        The Add-CMTraceLayoutRenderer Cmdlet adds a new layout renderer called 'cmtrace' that
        writes the message in a format that can be easily consumed by the CMTrace.exe log viewer.

        .EXAMPLE
        PS C:\>Add-CMTraceLayoutRenderer

        Adds the CMTrace Layout renderer.

        .NOTES
        This CmdLet is called automatically, when the PSNlog module is imported.
        It's not accessible outside of the module.
        !Custom modification! Function modified to accept component parameter and is now executed outside the .psm1-file

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]
    [CmdLetBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Component
    )
    begin {
        $Global:componentName = $Component
    }
    process {
        $CMTrace = {
            param(
                $logEvent
            )

            if ($null -ne $logEvent) {
                # Evaluate caller information
                $Callstack = Get-PSCallStack
                if ($null -ne $Callstack) {
                    try {
                        if ($Callstack.count -gt 1) {
                            $Caller = $Callstack[1]
                        }
                        else {
                            $Caller - $Callstack
                        }
                        $Source = $Caller.Location -replace '<No file>', ''
                    }
                    catch {}
                }

                if ($null -ne $logEvent.Level) {
                    switch ($logEvent.Level.ToString()) {
                        'Debug' { $Sev = 1 }
                        'Error' { $Sev = 3 }
                        'Fatal' { $Sev = 3 }
                        'Info' { $Sev = 1 }
                        'Trace' { $Sev = 1 }
                        'Warn' { $Sev = 2 }
                        'Info' { $Sev = 1 }
                    }
                }
                else {
                    $Sev = 1
                }

                # Get Timezone Bias to allign log entries through different timezones
                if ($null -eq $Global:TimezoneBias) {
                    try {
                        [int]$Global:TimezoneBias = [System.TimeZone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
                    }
                    catch {}
                }
                $Date = Get-Date -Format 'MM-dd-yyyy'
                $Time = Get-Date -Format 'HH:mm:ss.fff'
                $TimeString = "$Time$Global:TimezoneBias"

                $Message = "<![LOG[$($logEvent.Message)]LOG]!><time=`"$TimeString`" date=`"$Date`" component=`"$componentName`" context=`"`" type=`"$Sev`" thread=`"0`" file=`"$Source`">"
                $Message
            }
            else {
                'No logEvent object supplied.'
            }
        }
        [NLog.LayoutRenderers.LayoutRenderer]::Register('cmtrace', [Func[NLog.LogEventInfo, object]] $CMTrace)
    }
}

function Set-MessageStreams {
    <#
        .SYNOPSIS
        Overrides Write-Verbose, Write-Host, Write-Warning and Write-Error to write to a log file.

        .DESCRIPTION
        Overrides Write-Verbose, Write-Host, Write-Warning and Write-Error to write to a log file.
        The native Cmdlets will be called as well.

        .EXAMPLE
        PS C:>Set-MessageStreams -WriteVerbose -WriteWarning -WriteError

        Redirect Write-Verbose, Write-Warning and Write-Error
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalAliases', '')]
    [CmdLetBinding(SupportsShouldProcess)]
    param(
        # Specifies if Write-Verbose calls should be redirected to Write-NLogVerbose
        [Parameter(ParameterSetName = 'Add')]
        [switch]$WriteVerbose,

        # Specifies if Write-Host calls should be redirected to Write-NLogHost
        [Parameter(ParameterSetName = 'Add')]
        [switch]$WriteHost,

        # Specifies if Write-Warning calls should be redirected to Write-NLogWarning
        [Parameter(ParameterSetName = 'Add')]
        [switch]$WriteWarning,

        # Specifies if Write-Error calls should be redirecte to Write-NLogError
        [Parameter(ParameterSetName = 'Add')]
        [switch]$WriteError,

        # Specifies if the alias added by this function should be removed
        [Parameter(ParameterSetName = 'Remove')]
        [switch]$Remove
    )

    process {
        if ($WriteVerbose.IsPresent) {
            if (-Not(Test-Path 'Alias:\Write-Verbose')) {
                New-Alias -Name 'Write-Verbose' -Value 'Write-NLogVerbose' -Scope Global
            }
        }
        if ($WriteHost.IsPresent) {
            if (-Not(Test-Path 'Alias:\Write-Host')) {
                New-Alias -Name 'Write-Host' -Value 'Write-NLogHost' -Scope Global
            }
        }
        if ($WriteWarning.IsPresent) {
            if (-Not(Test-Path 'Alias:\Write-Warning')) {
                New-Alias -Name 'Write-Warning' -Value 'Write-NLogWarning' -Scope Global
            }
        }
        if ($WriteError.IsPresent) {
            if (-Not(Test-Path 'Alias:\Write-Error')) {
                New-Alias -Name 'Write-Error' -Value 'Write-NLogError' -Scope Global
            }
        }
        if ($Remove.IsPresent) {
            if (Test-Path 'Alias:\Write-Verbose') {
                Remove-Item 'Alias:\Write-Verbose' -Force
            }
            if (Test-Path 'Alias:\Write-Warning') {
                Remove-Item 'Alias:\Write-Warning' -Force
            }
            if (Test-Path 'Alias:\Write-Error') {
                Remove-Item 'Alias:\Write-Error' -Force
            }
            if (Test-Path 'Alias:\Write-Host') {
                Remove-Item 'Alias:\Write-Host' -Force
            }
        }
    }
}

function Set-ScriptRoot {
    <#
        .SYNOPSIS
        Sets the 'scriptroot' variable.

        .DESCRIPTION
        Sets the NLog 'scriptroot' variable to the location of the calling script.
        This variable can be used to automatically create log files at the same location as the script.

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdLetBinding()]
    param()

    process {
        if ($null -eq [NLog.LogManager]::Configuration) {
            [NLog.LogManager]::Configuration = New-Object NLog.Config.LoggingConfiguration
        }

        $ScriptName = Get-PSCallStack | Select-Object -Last 1 -ExpandProperty 'ScriptName'
        if ([string]::IsNullOrEmpty($ScriptName)) {
            $ScriptLocation = (Get-Location).ToString()
        }
        else {
            $ScriptLocation = Split-Path -Path $ScriptName -Parent
        }
        [NLog.LogManager]::Configuration.Variables['scriptroot'] = $ScriptLocation
    }
}

#endregion

#region Module Initialization

# Create a logger instance in module scope 
$Script:Logger = Get-NLogLogger -LoggerName 'PSNLog' 
  
# Create a 'scriptroot' variable based on the script file importing the module or the current location 
# This eases defining a proper log path 
Set-ScriptRoot 
  
# Add CMTrace Layout renderer 
# Add-CMTraceLayoutRenderer
#endregion
