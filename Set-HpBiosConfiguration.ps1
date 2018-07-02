[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to configure BIOS from legacy to EFI")]
    [ValidateNotNullOrEmpty()]
    [switch]$ConvertToUefi,
    [Parameter(Mandatory = $false, HelpMessage = "Specify if you want to use debug mode(changes logging path to localfolder)")]
    [ValidateNotNullOrEmpty()]
    [switch]$DebugMode
)
function Set-HPBios {
    [CmdletBinding()]
    param (
        ## Provide folder path to where the parameter is stored
        [Parameter(Mandatory = $true, HelpMessage = "Specify folder that contains BIOS-file")]
        [ValidateScript(
            {
                if (-not ($_ | Test-Path)) {
                    throw "Folder is missing"
                }
                else {
                    if ((Get-Item -Path $_).Attributes -notmatch 'Directory') {
                        throw "Path provided is not an directory"
                    }
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $FolderPath,
        ## Specify what exit codes are considered as success, default: 0, 1, 5, 13, 17 (See HP-documentation for more info)
        [Parameter(Mandatory = $false, HelpMessage = "Specify list of approved exit codes")]
        [ValidateNotNullOrEmpty()]
        [string[]]$ApprovedExitCodes = @(0, 1, 5, 13, 17)
    )
    begin {
        Write-Verbose -Message "Creating variables for BIOS-config tool"
        ### Paths for config utility and bios password
        ## Provide path for correct Config Utility based on OS-arch
        if ((Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture -match '64') {
            $biosTool = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosConfigUtility\BiosConfigUtility64.exe"
        }
        else {
            $biosTool = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosConfigUtility\BiosConfigUtility.exe"
        }

        ## Provide path for BIOS-password BIN
        $biosPassword = Join-Path -Path $PSScriptRoot -ChildPath "Tools\BiosPassword\BiosConfig.bin"
        
        ### Test paths
        ## Test if bios tool is present
        Write-Verbose -Message "Attempting to test if $biosTool is present"
        if (-not(Test-Path -Path $biosTool)) {
            throw "Failed to locate BIOS-tool, check if path is correct"
        }

        ## Test if password path is present
        Write-Verbose -Message "Attempting to test if $biosPassword is present"
        if (-not(Test-Path -Path $biosPassword)) {
            throw "Failed to locate BIOS-password, check if path is correct"
        }
    }
    process {

    }

}

Set-HPBios -FolderPath C:\Temp -Verbose