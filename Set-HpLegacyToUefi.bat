powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy ByPass -file "%~DP0Set-HpBiosConfiguration.ps1" -SetBiosPassword -ConvertToUefi
exit /b %errorlevel%