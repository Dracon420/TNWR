# Builds the Windows beta download: dist\TNWR-Windows-beta-<version>.zip
# (release build + Microsoft C++ runtime + installer scripts + readme).
# Run from anywhere: powershell -ExecutionPolicy Bypass -File tools\package_windows.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

    $version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
    $name = "TNWR-Windows-beta-$version"
    $stage = Join-Path 'dist' $name
    Remove-Item $stage, "dist\$name.zip" -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force "$stage\app" | Out-Null

    Copy-Item 'build\windows\x64\runner\Release\*' "$stage\app" -Recurse

    # The app won't start on PCs without the Microsoft C++ runtime, and many
    # don't have it, so ship the three DLLs next to TNWR.exe.
    $crt = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT" -Directory |
        Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $crt) { throw 'Microsoft C++ runtime (VC Redist) not found in Visual Studio' }
    foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
        Copy-Item (Join-Path $crt.FullName $dll) "$stage\app"
    }

    Copy-Item 'packaging\windows\*' $stage
    Compress-Archive -Path $stage -DestinationPath "dist\$name.zip"
    $zip = Get-Item "dist\$name.zip"
    Write-Host ("Built {0} ({1:N1} MB)" -f $zip.FullName, ($zip.Length / 1MB))
} finally {
    Pop-Location
}
