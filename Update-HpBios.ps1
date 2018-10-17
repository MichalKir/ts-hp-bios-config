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
}
