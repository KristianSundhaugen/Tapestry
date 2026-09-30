@echo off
rem Tapestry launcher for cmd.exe and PowerShell (Windows Terminal).
rem Runs bin\tapestry.ps1 with PowerShell 7 if installed, else Windows PowerShell,
rem with -ExecutionPolicy Bypass for this one process, so no policy change is needed.
rem Usage: bin\tapestry doctor ^| install ^| status [id] ^| window ^| setup ^| new "idea" ^| run ^<id^> ^| help
setlocal
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (set "TAPESTRY_PS=pwsh") else (set "TAPESTRY_PS=powershell")
%TAPESTRY_PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0tapestry.ps1" %*
exit /b %ERRORLEVEL%
