powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy ByPass -file "%~DP0Set-HpBiosConfiguration.ps1" -ConvertToUefi
exit /b %errorlevel%