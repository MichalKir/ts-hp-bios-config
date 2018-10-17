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
        function Write-Log {
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
        
    }
}

Update-HpBios -ExecutionType NoPassowrdOrVersionCheck