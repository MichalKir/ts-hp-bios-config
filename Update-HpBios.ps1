FUNCTION Update-HpBios {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Specify approved exit codes", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ApprovedExitcodes = @(0, 1, 5, 13, 17, 3010),
        [Parameter(Mandatory = $true, HelpMessage = "Set execution type", Position = 1)]
        [ValidateSet("SetPasswordAndCheckVersion", "NoPassword", "NoVersionCheck", "NoPassowrdOrVersionCheck")]
        [string]$ExecutionType,
        [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to run the script in debug mode", Position = 4)]
        [ValidateNotNullOrEmpty()]
        [switch]$DebugMode
    )
    DynamicParam {
        switch ($ExecutionType) {
            "SetPasswordAndCheckVersion" {
                ## Param bios version xml name
                $attributeBiosVersionXmlName = New-Object System.Management.Automation.ParameterAttribute
                $attributeBiosVersionXmlName.Position = 2
                $attributeBiosVersionXmlName.Mandatory = $true
                $attributeBiosVersionXmlName.HelpMessage = "Specify BIOS-version XML-file name"
                ## Param bios password file name
                $attributeBiosPasswordFileName = New-Object System.Management.Automation.ParameterAttribute
                $attributeBiosPasswordFileName.Position = 3
                $attributeBiosPasswordFileName.Mandatory = $true
                $attributeBiosPasswordFileName.HelpMessage = "Specify BIOS-password file name"
                ## Attribute collection Bios XML
                $attributeCollectionBiosXml = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $attributeCollectionBiosXml.Add($attributeBiosVersionXmlName)
                ## Attribute collection Bios Password
                $attributeCollectionBiosPassword = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $attributeCollectionBiosPassword.Add($attributeBiosPasswordFileName)
                ## Create parameters
                $biosVersionXmlName = New-Object System.Management.Automation.RuntimeDefinedParameter("BiosVersionXmlName", [string], $attributeCollectionBiosXml)
                $biosPasswordFileName = New-Object System.Management.Automation.RuntimeDefinedParameter("BiosPasswordFileName", [string], $attributeCollectionBiosPassword)
                ## Parameter dictionary
                $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $paramDictionary.Add("BiosVersionXmlName", $biosVersionXmlName)
                $paramDictionary.Add("BiosPasswordFileName", $biosPasswordFileName)
                return $paramDictionary
            }
            "NoPassword" {
                ## Param bios version xml name
                $attributeBiosVersionXmlName = New-Object System.Management.Automation.ParameterAttribute
                $attributeBiosVersionXmlName.Position = 2
                $attributeBiosVersionXmlName.Mandatory = $true
                $attributeBiosVersionXmlName.HelpMessage = "Specify BIOS-version XML-file name"
                ## Attribute collection Bios XML
                $attributeCollectionBiosXml = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $attributeCollectionBiosXml.Add($attributeBiosVersionXmlName)
                ## Create parameters
                $biosVersionXmlName = New-Object System.Management.Automation.RuntimeDefinedParameter("BiosVersionXmlName", [string], $attributeCollectionBiosXml)
                ## Parameter dictionary
                $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $paramDictionary.Add("BiosVersionXmlName", $biosVersionXmlName)
                return $paramDictionary
            }
            "NoVersionCheck" {
                ## Param bios password file name
                $attributeBiosPasswordFileName = New-Object System.Management.Automation.ParameterAttribute
                $attributeBiosPasswordFileName.Position = 2
                $attributeBiosPasswordFileName.Mandatory = $true
                $attributeBiosPasswordFileName.HelpMessage = "Specify BIOS-password file name"
                ## Attribute collection Bios Password
                $attributeCollectionBiosPassword = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $attributeCollectionBiosPassword.Add($attributeBiosPasswordFileName)
                ## Create parameters
                $biosPasswordFileName = New-Object System.Management.Automation.RuntimeDefinedParameter("BiosPasswordFileName", [string], $attributeCollectionBiosPassword)
                ## Parameter dictionary
                $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $paramDictionary.Add("BiosPasswordFileName", $biosPasswordFileName)
                return $paramDictionary
            }
        }
    }
    Begin {
        ############################### DO NOT CHANGE ########################################     
        ## Spec variables that will be used in the script(do not change, these'll be defined later on)
        $computerModelName = $null
        $pathComputerModel = $null
        $pathBiosUpdateFile = $null
        ############################### DO NOT CHANGE - END ########################################
        ## Get computer model
        $computerModelName = (Get-CimInstance -ClassName Cim_ComputerSystem).Model
        $computerModelName = ($computerModelName).Trim("HP").Trim("Hewlett-Packard").Replace("35W", " ").Trim()
        ## Get computer model path
        $pathComputerModel = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$computerModelName* `
                | Where-Object {$_.Attributes -eq "Directory"} | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        ## Get BIOS-update file
        $pathBiosUpdateFile = (Get-ChildItem -Path $pathComputerModel -Recurse -Include *.cab, *.cab | Select-Object -First 1).FullName
        
        ## Create variables based on ExecutionType
        switch ($ExecutionType) {
            "SetPasswordAndCheckVersion" {
                ## Spec variables that will be used in the script(do not change, these'll be defined later on)
                $pathBiosVersionXml = $null
                $pathBiosPassword = $null
                ## Redefine dynamic parameters
                $BiosVersionXmlName = $biosVersionXmlName.Value
                $BiosPasswordFileName = $biosPasswordFileName.Value
                ## Get BIOS-xml file
                $pathBiosVersionXml = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$BiosVersionXmlName* -Include *.xml | Select-Object -First 1).FullName
                ## Get BIOS-password file
                $pathBiosPassword = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$BiosPasswordFileName* -Include *.bin | Select-Object -First 1).FullName                
            }
            "NoPassword" {
                ## Spec variables that will be used in the script(do not change, these'll be defined later on)
                $pathBiosVersionXml = $null
                ## Redefine dynamic parameters
                $BiosVersionXmlName = $biosVersionXmlName.Value
                ## Get BIOS-xml file
                $pathBiosVersionXml = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$BiosVersionXmlName* -Include *.xml | Select-Object -First 1).FullName
            }
            "NoVersionCheck" {
                ## Spec variables that will be used in the script(do not change, these'll be defined later on)
                $pathBiosPassword = $null
                ## Redefine dynamic parameters
                $BiosPasswordFileName = $biosPasswordFileName.Value
                ## Get BIOS-password file
                $pathBiosPassword = (Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *$BiosPasswordFileName* -Include *.bin | Select-Object -First 1).FullName  
            }
        }

        ####### FUNCTIONS
        ## Write-Log
        FUNCTION Write-Log {
            # Based on: https://janikvonrotz.ch/2017/10/26/powershell-logging-in-cmtrace-format/
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $false, HelpMessage = "Specify log name")]
                [ValidateNotNullOrEmpty()]
                [string]$LogName = "BiosUpdate.log",
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

        FUNCTION Test-BiosUpdateNeeded {    
            <#
            .SYNOPSIS
            Test if BIOS-update is needed
            
            .DESCRIPTION
            Test if BIOS-update is needed based on targeted version in BIOS-xml file
            
            .PARAMETER ComputerModel
            Specify computer model to test if parameter set is Default
            
            .PARAMETER XmlPath
            Specify path to BIOS-xml file if parameter set is Default 

            .PARAMETER DebugMode
            Specify if you want to test against custom targeted BIOS-version

            .PARAMETER TargetedBiosVersion
            Specify targeted BIOS-version
            
            .EXAMPLE
            Test-BiosUpdateNeeded -ComputerModel "HP EliteBook 840 G5" -XmlPath (Join-Path -Path $PSScriptRoot -ChildPath "BiosFiles\BiosUpdate.xml")
            Test-BiosUpdateNeeded -DebugMode -TargetedBiosVersion "01.03.00" 
            Author:         Mickis
            Version:        1.0.0
            Date:           2018-10-17

            Version history:
                - 1.0.0 (2018-10-17) - Script created
            #>                    
            [CmdletBinding(DefaultParameterSetName = "Default")]
            Param (
                [Parameter(Mandatory = $true, HelpMessage = "Specify computer model name", ParameterSetName = "Default")]
                [ValidateNotNullOrEmpty()]
                [string]$ComputerModel,
                [Parameter(Mandatory = $true, HelpMessage = "Provide BIOS-xml file path", ParameterSetName = "Default")]
                [ValidateScript( {
                        if (-not ($_ | Test-Path)) {
                            throw "File is missing"
                        }
                        if ((Get-Item -Path $_).Extension -notmatch 'xml') {
                            throw "File is not .xml"
                        }
                        return $true
                    })]
                [ValidateNotNullOrEmpty()]
                [System.IO.FileInfo]$XmlPath,
                [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to run the function in the debug mode", ParameterSetName = "DebugMode")]
                [ValidateNotNullOrEmpty()]
                [switch]$DebugMode,
                [Parameter(Mandatory = $true, HelpMessage = "Specify targeted BIOS version", ParameterSetName = "DebugMode")]
                [ValidateNotNullOrEmpty()]
                [string]$TargetedBiosVersion
            )
            Begin {
                ## Spec variables that will be used in the script(do not change, these'll be defined later on)
                $readBiosXml = $null
                $getCurrentBiosVersion = $null
                $getTargetedBiosVersion = $null
            }
            Process {
                try {
                    if (-not($DebugMode)) {
                        ## Get targeted BIOS-version
                        $getTargetedBiosVersion = ($readBiosXml.ComputerModels.ComputerModel | Where-Object {$_.Name -match $ComputerModel}).BIOS
                        ## Read XML-file
                        [xml]$readBiosXml = Get-Content -Path $XmlPath.FullName
                    }
                    else {
                        $getTargetedBiosVersion = $TargetedBiosVersion
                    }                    
                    ## Get current BIOS-version
                    $getCurrentBiosVersion = (Get-CimInstance -ClassName Cim_BiosElement).SMBIOSBIOSVersion
                                        
                    ## Check if Update is needed
                    if ($getCurrentBiosVersion -notmatch $getTargetedBiosVersion) {
                        return "UpdateNeeded"
                    }
                    else {
                        return "UpdateNotNeeded"
                    }
                }
                catch {
                    Write-Error -ErrorRecord $_
                }
            }
        }

        ## Invoke-HpBiosUpdateUtility
        FUNCTION Invoke-HpBiosUpdateUtility {
            [CmdletBinding(DefaultParameterSetName = "Default")]
            Param (
                [Parameter(Mandatory = $false, HelpMessage = "Specify approved exit codes", ParameterSetName = "Default")]
                [Parameter(Mandatory = $false, HelpMessage = "Specify approved exit codes", ParameterSetName = "NoBiosPassword")]
                [ValidateNotNullOrEmpty()]
                [string[]]$ApprovedExitcodes = $ApprovedExitcodes,
                [Parameter(Mandatory = $false, HelpMessage = "Provide BIOS-update file path", ParameterSetName = "Default")]
                [Parameter(Mandatory = $false, HelpMessage = "Provide BIOS-update file path", ParameterSetName = "NoBiosPassword")]
                [ValidateScript( {
                        if (-not ($_ | Test-Path)) {
                            throw "File is missing"
                        }
                        if ((Get-Item -Path $_).Extension -notmatch 'bin') {
                            throw "File is not .bin"
                        }
                        return $true
                    })]
                [ValidateNotNullOrEmpty()]
                [System.IO.FileInfo]$UpdateFilePath,
                [Parameter(Mandatory = $true, HelpMessage = "Provide BIOS-password file path", ParameterSetName = "Default")]
                [ValidateScript( {
                        if (-not ($_ | Test-Path)) {
                            throw "File is missing"
                        }
                        if ((Get-Item -Path $_).Extension -notmatch 'bin') {
                            throw "File is not .bin"
                        }
                        return $true
                    })]
                [ValidateNotNullOrEmpty()]
                [System.IO.FileInfo]$PasswordFilePath,
                [Parameter(Mandatory = $true, HelpMessage = "Specify this if you BIOS is not password protected", ParameterSetName = "NoBiosPassword")]
                [ValidateNotNullOrEmpty()]
                [switch]$DontUsePassword
            )
            Begin {
                ## Spec variables that will be used in the script(do not change, these'll be defined later on)
                $biosUpdateUtilityPath = $null
                $biosUpdateUtilityProcess = $null
                $arguments = $null
                $fileName = $null
                ## Get BIOS-file name
                $fileName = Split-Path -Path $UpdateFilePath.FullName -Leaf
                ## Determinate Bios utility
                ## if file is .BIN
                if (Get-Item -Path $fileName | Where-Object {$_.Extension -match "bin"}) {
                    if ([Environment]::Is64BitOperatingSystem -eq $true) {
                        ## If HpFirmwareUpdRec is present, use it instead of HpBiosUpdRec
                        if (Get-ChildItem -Path $PSScriptRoot -Filter "HPBIOSUPDREC64.exe" -Recurse) {
                            $biosUpdateUtilityPath = (Get-ChildItem -Path $PSScriptRoot -Filter "HPBIOSUPDREC64.exe" -Recurse | Select-Object -First 1).FullName
                        }
                        if (Get-ChildItem -Path $PSScriptRoot -Filter "HpFirmwareUpdRec64.exe" -Recurse) {
                            $biosUpdateUtilityPath = (Get-ChildItem -Path $PSScriptRoot -Filter "HpFirmwareUpdRec64.exe" -Recurse | Select-Object -First 1).FullName
                        }
                    }
                    else {
                        if (Get-ChildItem -Path $PSScriptRoot -Filter "HPBIOSUPDREC.exe" -Recurse) {
                            $biosUpdateUtilityPath = (Get-ChildItem -Path $PSScriptRoot -Filter "HPBIOSUPDREC.exe" -Recurse | Select-Object -First 1).FullName
                        }
                        if (Get-ChildItem -Path $PSScriptRoot -Filter "HpFirmwareUpdRec.exe" -Recurse) {
                            $biosUpdateUtilityPath = (Get-ChildItem -Path $PSScriptRoot -Filter "HpFirmwareUpdRec.exe" -Recurse | Select-Object -First 1).FullName
                        }
                    }
                    ## Arguments
                    if (-not ($DontUsePassword)) {
                        $arguments = "-p`"$($PasswordFilePath.FullName)`" -f`"$($UpdateFilePath.FullName)`" -b -s -r"
                    }
                    else {
                        $arguments = "-f`"$($UpdateFilePath.FullName)`" -b -s -r"
                    }
                } 
                ## If file is .CAB
                else {
                    $biosUpdateUtilityPath = (Get-ChildItem -Path $PSScriptRoot -Filter "HPQFlash.exe" -Recurse | Select-Object -First 1).FullName 
                    if (-not ($DontUsePassword)) {
                        $arguments = "-p`"$($PasswordFilePath.FullName)`" -f`"$($UpdateFilePath.FullName)`" -s"
                    }
                    else {
                        $arguments = "-f`"$($UpdateFilePath.FullName)`" -s"
                    }
                }
                ## Make sure that BIOS-config tool is present
                if (-not ($biosUpdateUtilityPath)) {
                    throw "BIOS-update tool is missing"
                }                  
            }
            Process {
                ## Execute update process
                $biosUpdateUtilityProcess = Start-Process -FilePath $biosUpdateUtilityPath -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden -ErrorAction Stop
                if ($ApprovedExitcodes -contains $biosUpdateUtilityProcess.ExitCode) {
                    $LASTEXITCODE = 0
                }
                else {
                    $LASTEXITCODE = $biosUpdateUtilityProcess.ExitCode
                    throw "Failed to update HP BIOS"
                }
            }
        }
        ## Set HP BIOS Password
        FUNCTION Set-HpBiosPassword {
            [CmdletBinding()]
            Param (
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
            Begin {
                ## Spec variables that will be used in the script(do not change, these'll be defined later on)0
                $passwordPathResolved = $null
                $passwordBackup = $null

                $passwordPathResolved = $PasswordPath.FullName
                $passwordBackup = Join-Path -Path (Split-Path -Path $passwordPath) -ChildPath 'UseThisToSetPassword.bin'
            }
            Process {
                try {
                    ## create backup for password file, some BCU-versiones remove the .bin-file on password set                
                    if (-not(Test-Path -Path $passwordBackup)) {
                        Write-Verbose -Message "Attempting to make copy of $passwordPathResolved" -ErrorAction SilentlyContinue
                        try {
                            Copy-Item -Path $passwordPathResolved -Destination $passwordBackup -ErrorAction Stop
                        }
                        catch {
                            Write-Error -ErrorRecord $_ ; break
                        }

                    }
                    ## The tool is exiting with exit code 10 if password is already set, so report error 10 as success
                    Invoke-HpBiosConfigurationUtility -ApprovedExitCodes @(0, 10) -Arguments "/nspwd:`"$passwordBackup`"" -ErrorAction Stop            
                }
                catch {
                    Write-Error -ErrorRecord $_ ; break
                }
            }
        }
    }
}

Update-HpBios -ExecutionType NoPassowrdOrVersionCheck