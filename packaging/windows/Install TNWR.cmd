@echo off
rem Installs T.N.W.R. for this Windows user (no admin needed).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
