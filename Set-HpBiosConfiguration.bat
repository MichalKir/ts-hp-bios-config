powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy ByPass -file "%~DP0Set-HpBiosConfiguration.ps1" -BiosPasswordFileName BiosPassword.bin -SetBiosPassword
exit /b %errorlevel%