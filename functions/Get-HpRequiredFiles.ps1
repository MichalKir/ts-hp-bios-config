FUNCTION Get-HpRequiredFiles {
    <#
    .SYNOPSIS
    Get HP-Bios files
    
    .DESCRIPTION
    This function will get necessary HP-files to use for the rest of the module
    
    .PARAMETER FileType
    Specify what file you are looking for
        
    .EXAMPLE
    Get-HpRequiredFiles -FileType ConfigurationUtility

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
        [Parameter(Mandatory, HelpMessage = "Specify file you are looking for", Position = 0)]
        [ValidateSet("ConfigurationUtility", "BinUpdateUtility", "CabUpdateUtility", "CurrentPasswordFile", "OldPasswordFile", "BiosConfigurationFile", "ConvertToUefiFile")]
        [string]$FileType
    )
    Begin {
        # Populate default Write-Log parameters
        $functionName = $MyInvocation.MyCommand
        # Get current module path
        Write-Verbose -Message "$functionName - Attempting to determine module folder path"
        $moduleDirectory = Split-Path $script:MyInvocation.MyCommand.Path
        Write-Verbose -Message "$functionName - Module folder path is: $moduleDirectory"
    }
    Process {
        switch ($FileType) {
            "ConfigurationUtility" {
                # Set file name based on os arch 
                if ([System.Environment]::Is64BitOperatingSystem) {
                    $fileName = "BiosConfigUtility64.exe"
                }
                else {
                    $fileName = "BiosConfigUtility.exe"
                }
                try {
                    # Search for the file
                    Write-Verbose -Message "$functionName - Attempting to search for the $fileName"
                    if ($result = (Get-ChildItem -Path $moduleDirectory -Filter $fileName -Recurse | Select-Object -First 1).FullName) {
                        Write-Verbose -Message "$functionName - Located $fileName, path: $result"
                        return $result
                    }
                    else {
                        Write-Verbose -Message "$functionName - $fileName is missing!"
                        throw "$fileName is missing!"
                    }
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to search for the $fileName, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                }                
            }
            "BinUpdateUtility" {
                # Set file name based on os arch 
                if ([System.Environment]::Is64BitOperatingSystem) {
                    $fileName = "HpFirmwareUpdRec64.exe"
                }
                else {
                    $fileName = "HpFirmwareUpdRec.exe"
                }
                try {
                    # Search for the file
                    Write-Verbose -Message "$functionName - Attempting to search for the $fileName"
                    if ($result = (Get-ChildItem -Path $moduleDirectory -Filter $fileName -Recurse | Select-Object -First 1).FullName) {
                        Write-Verbose -Message "$functionName - Located $fileName, path: $result"
                        return $result
                    }
                    else {
                        Write-Verbose -Message "$functionName - $fileName is missing!"
                        throw "$fileName is missing!"
                    }
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to search for the $fileName, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                } 
            }
            "CabUpdateUtility" {
                # Set file name
                $fileName = "HPQFlash.exe"
                try {
                    # Search for the file
                    Write-Verbose -Message "$functionName - Attempting to search for the $fileName"
                    if ($result = (Get-ChildItem -Path $moduleDirectory -Filter $fileName -Recurse | Select-Object -First 1).FullName) {
                        Write-Verbose -Message "$functionName - Located $fileName, path: $result"
                        return $result
                    }
                    else {
                        Write-Verbose -Message "$functionName - $fileName is missing!"
                        throw "$functionName - $fileName is missing!"
                    }
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to search for the $fileName, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                } 
            }
            "CurrentPasswordFile" {
                # Set file name
                $fileName = "CurrentBiosPassword.bin"
                try {
                    # Search for the file
                    Write-Verbose -Message "$functionName - Attempting to search for the $fileName"
                    if ($result = (Get-ChildItem -Path $moduleDirectory -Filter $fileName -Recurse | Select-Object -First 1).FullName) {
                        Write-Verbose -Message "$functionName - Located $fileName, path: $result"
                        return $result
                    }
                    else {
                        Write-Verbose -Message "$functionName - $fileName is missing!"
                        throw "$functionName - $fileName is missing!"
                    }
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to search for the $fileName, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                }
            }
            "OldPasswordFile" {
                # Set file name
                $fileName = "OldBiosPassword.bin"
                try {
                    # Search for the file
                    Write-Verbose -Message "$functionName - Attempting to search for the $fileName"
                    if ($result = (Get-ChildItem -Path $moduleDirectory -Filter $fileName -Recurse | Select-Object -First 1).FullName) {
                        Write-Verbose -Message "$functionName - Located $fileName, path: $result"
                        return $result
                    }
                    else {
                        Write-Verbose -Message "$functionName - $fileName is missing!"
                        throw "$functionName - $fileName is missing!"
                    }
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to search for the $fileName, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                }
            }
            "BiosConfigurationFile" {
                try {
                    # Get computer model
                    Write-Verbose -Message "$functionName - Attempting to get computer model"
                    $computerModel = ((Get-CimInstance -ClassName Cim_ComputerSystem -ErrorAction Stop).Model).Trim("HP").Trim("Hewlett-Packard").Trim('')
                    Write-Verbose -Message "$functionName - Computer model is: $computerModel"
                    try {
                        # Get computer model folder
                        Write-Verbose -Message "Attempting to search for the computer model folder"
                        $computerModelFolder = (Get-ChildItem -Path $moduleDirectory -Recurse -Filter *$computerModel* | Select-Object -First 1).FullName
                        Write-Verbose -Message "$functionName - Computer model folder is: $computerModelFolder"
                        try {
                            # Get .REPSET file
                            Write-Verbose -Message "$functionName - Attempting to search for the BIOS-configuration file"
                            if ($result = (Get-ChildItem -Path $computerModelFolder -Recurse -Filter *.REPSET -Exclude *EFI*, *UEFI* `
                                        | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName) {
                                Write-Verbose -Message "$functionName - Located BIOS-configuration file, path: $result"
                                return $result
                            }
                            else {
                                Write-Verbose -Message "$functionName - BIOS-configuration file is missing!"
                                throw "$functionName - BIOS-configuration file is missing!"
                            }
                        }
                        catch {
                            Write-Verbose -Message "$functionName - Failed to search for the BIOS-configuration file, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                            Write-Error -ErrorRecord $_
                        }
                    }
                    catch { 
                        Write-Verbose -Message "$functionName - Failed to locate computer model folder, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                        Write-Error -ErrorRecord $_
                    }                    
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to get computer model, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                }
            }
            "ConvertToUefiFile" {
                try {
                    # Get computer model
                    Write-Verbose -Message "$functionName - Attempting to get computer model"
                    $computerModel = ((Get-CimInstance -ClassName Cim_ComputerSystem -ErrorAction Stop).Model).Trim("HP").Trim("Hewlett-Packard").Trim('')
                    $biosFilesDirectory = Join-Path -Path $moduleDirectory -ChildPath "BiosFiles"
                    Write-Verbose -Message "$functionName - Computer model is: $computerModel"
                    try {
                        # Get computer model folder
                        Write-Verbose -Message "Attempting to search for the computer model folder"
                        $computerModelFolder = (Get-ChildItem -Path $moduleDirectory -Recurse -Filter *$computerModel* | Select-Object -First 1).FullName
                        Write-Verbose -Message "$functionName - Computer model folder is: $computerModelFolder"
                        try {
                            # Get .REPSET file
                            Write-Verbose -Message "$functionName - Attempting to search for the convert to UEFI-file"
                            if ($result = (Get-ChildItem -Path $computerModelFolder -Recurse -Filter *.REPSET -Include *EFI*, *UEFI* `
                                        | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName) {
                                Write-Verbose -Message "$functionName - Located convert to UEFI-file, path: $result"
                                return $result
                            }
                            else {
                                Write-Verbose -Message "$functionName - Convert to UEFI-file is missing!"
                                throw "$functionName - Convert to UEFI-file is missing!"
                            }
                        }
                        catch {
                            Write-Verbose -Message "$functionName - Failed to search for the convert to UEFI-file, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                            Write-Error -ErrorRecord $_
                        }
                    }
                    catch {
                        Write-Verbose -Message "$functionName - Failed to locate computer model folder, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                        Write-Error -ErrorRecord $_
                    }
                    
                }
                catch {
                    Write-Verbose -Message "$functionName - Failed to get computer model, line: $($_.InvocationInfo.ScriptLineNumber), exception: $($_.Exception.Message)"
                    Write-Error -ErrorRecord $_
                }
            }
        }
    }
}
