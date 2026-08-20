# XMUSIC Windows Release build script
# Requires: Flutter SDK + Visual Studio 2022 (Desktop development with C++)
# Run in PowerShell: .\tool\build_windows.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

Write-Host "==> flutter pub get"
flutter pub get

Write-Host "==> generate launcher icons"
dart run flutter_launcher_icons

Write-Host "==> flutter build windows --release"
flutter build windows --release

$buildDir = Join-Path "build" "windows\x64\runner\Release"
if (-not (Test-Path $buildDir)) {
    throw "Build output not found: $buildDir"
}

$distDir = Join-Path "dist" "XMUSIC-Windows-x64"
$zipPath = Join-Path "dist" "XMUSIC-Windows-x64.zip"

if (Test-Path $distDir) { Remove-Item -Recurse -Force $distDir }
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

New-Item -ItemType Directory -Force -Path "dist" | Out-Null
Copy-Item -Recurse -Force $buildDir $distDir

Compress-Archive -Path $distDir -DestinationPath $zipPath -Force

$exe = Join-Path $distDir "xmusic.exe"
$exeSize = (Get-Item $exe).Length / 1MB
$zipSize = (Get-Item $zipPath).Length / 1MB

Write-Host ""
Write-Host "Build complete."
Write-Host "  EXE folder: $distDir"
Write-Host "  Main EXE:   $exe ($([math]::Round($exeSize, 2)) MB)"
Write-Host "  ZIP pack:   $zipPath ($([math]::Round($zipSize, 2)) MB)"
Write-Host ""
Write-Host "Run: .\dist\XMUSIC-Windows-x64\xmusic.exe"
