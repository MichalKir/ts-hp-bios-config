powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy ByPass -file "%~DP0Update-HpBios.ps1" -ExecutionType SetPasswordAndCheckVersion -BiosVersionXmlName BiosUpdate.xml -BiosPasswordFileName BiosPassword.bin
exit /b %errorlevel%