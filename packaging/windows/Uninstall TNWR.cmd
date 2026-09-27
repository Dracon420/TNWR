@echo off
rem Removes T.N.W.R. Your reminders are kept unless you delete %APPDATA%\com.nagalarm.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
pause
