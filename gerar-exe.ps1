# Gera o executável do Windows (um arquivo só) em build\windows\IdleTrain.exe
# Uso: powershell -ExecutionPolicy Bypass -File gerar-exe.ps1
# O modo trem flutuante só existe nesta versão desktop.
$ErrorActionPreference = "Stop"
$godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$root  = $PSScriptRoot
$out   = Join-Path $root "build\windows"
New-Item -ItemType Directory -Force $out | Out-Null

# Nome da branch + commit, mostrado no canto do jogo
$branch = (git -C $root rev-parse --abbrev-ref HEAD).Trim()
$commit = (git -C $root rev-parse --short HEAD).Trim()
$dirty  = if (git -C $root status --porcelain) { " *" } else { "" }
Set-Content (Join-Path $root "build_info.txt") "$branch ($commit$dirty)" -Encoding ascii
Write-Host "Versao: $branch ($commit$dirty)"
Write-Host "Exportando..."
& $godot --headless --path $root --export-release "Windows" "$out\IdleTrain.exe"
if (-not (Test-Path "$out\IdleTrain.exe")) { Write-Host "Falha na exportacao."; exit 1 }
Write-Host "Pronto: $out\IdleTrain.exe"
