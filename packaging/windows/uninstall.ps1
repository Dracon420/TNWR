# Removes T.N.W.R. installed by install.ps1. Run via "Uninstall TNWR.cmd".
# Your reminders are kept (in %APPDATA%\com.nagalarm) unless you add -RemoveData.
param(
    [string]$Target = $PSScriptRoot,
    [switch]$RemoveData
)
$ErrorActionPreference = 'Continue'
Write-Host '  Removing T.N.W.R. ...'

Get-Process TNWR -ErrorAction SilentlyContinue | Stop-Process -Force

# The app's "start with Windows" entries (written by launch_at_startup).
foreach ($key in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run') {
    Remove-ItemProperty -Path $key -Name 'T.N.W.R.' -ErrorAction SilentlyContinue
}
foreach ($folder in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop')) {
    Remove-Item (Join-Path $folder 'T.N.W.R.lnk') -ErrorAction SilentlyContinue
}
if ($RemoveData) {
    Remove-Item "$env:APPDATA\com.nagalarm" -Recurse -Force -ErrorAction SilentlyContinue
}

# This script lives in the folder being removed, so delete it just after exiting.
Start-Process cmd.exe -WindowStyle Hidden -ArgumentList '/c', "timeout /t 2 >nul & rmdir /s /q `"$Target`""
Write-Host '  T.N.W.R. has been removed.' -ForegroundColor Green
