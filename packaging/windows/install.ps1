# Installs T.N.W.R. for the current user: no admin rights needed.
# Run via "Install TNWR.cmd". Re-running it updates an existing install.
param(
    [string]$Target = "$env:LOCALAPPDATA\Programs\TNWR",
    [switch]$NoShortcuts,
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'app'

Write-Host ''
Write-Host '  T.N.W.R. - The Naggy Wife Reminder' -ForegroundColor DarkYellow
Write-Host '  Installing...'

# An update: close the running copy so its files can be replaced.
Get-Process TNWR -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

New-Item -ItemType Directory -Force $Target | Out-Null
Copy-Item (Join-Path $source '*') $Target -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'uninstall.ps1') $Target -Force
Copy-Item (Join-Path $PSScriptRoot 'Uninstall TNWR.cmd') $Target -Force

$exe = Join-Path $Target 'TNWR.exe'
if (-not $NoShortcuts) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($folder in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop')) {
        $link = $shell.CreateShortcut((Join-Path $folder 'T.N.W.R.lnk'))
        $link.TargetPath = $exe
        $link.WorkingDirectory = $Target
        $link.Description = 'The Naggy Wife Reminder'
        $link.Save()
    }
}

Write-Host '  Done! T.N.W.R. is installed.' -ForegroundColor Green
Write-Host ''
Write-Host '  - Find it in the Start menu or on your desktop.'
Write-Host '  - It starts by itself when you sign in to Windows (in the tray, near the clock).'
Write-Host '  - Closing the window hides it to the tray; reminders keep working.'
Write-Host "  - To remove it later: double-click 'Uninstall TNWR' in $Target"
Write-Host ''
if (-not $NoLaunch) { Start-Process $exe }
