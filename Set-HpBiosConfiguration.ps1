function Set-HPBios {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Specify folder that contains BIOS-file")]
        [ValidateScript(
            {
                if (-not ($_ | Test-Path)) {
                    throw "Folder is missing"
                    exit 1
                }
                else {
                    if ((Get-Item -Path $_).Attributes -notmatch 'Directory') {
                        throw "Path provided is not an directory"
                        exit 1
                    }
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $FolderPath
    )
}

