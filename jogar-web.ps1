# Exporta o jogo para Web e abre no navegador (http://localhost:8060)
# Uso: clique direito -> "Executar com o PowerShell"  ou  powershell -ExecutionPolicy Bypass -File jogar-web.ps1
param([switch]$Release)  # -Release: exporta sem depuração (mais rápido)
$ErrorActionPreference = "Stop"
$godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
$root  = $PSScriptRoot
$out   = Join-Path $root "build\web"
$port  = 8060

New-Item -ItemType Directory -Force $out | Out-Null

# Nome da branch + commit, mostrado no canto do jogo
$branch = (git -C $root rev-parse --abbrev-ref HEAD).Trim()
$commit = (git -C $root rev-parse --short HEAD).Trim()
$dirty  = if (git -C $root status --porcelain) { " *" } else { "" }
Set-Content (Join-Path $root "build_info.txt") "$branch ($commit$dirty)" -Encoding ascii
Write-Host "Versao: $branch ($commit$dirty)"
Write-Host "Exportando..."
$mode = if ($Release) { "--export-release" } else { "--export-debug" }
Write-Host "Modo: $(if ($Release) { "release" } else { "debug" })"
& $godot --headless --path $root $mode "Web" "$out\index.html"
if (-not (Test-Path "$out\index.html")) { Write-Host "Falha na exportacao. Modelos de exportacao instalados?"; Read-Host "Enter para sair"; exit 1 }

$types = @{ ".html"="text/html"; ".js"="application/javascript"; ".wasm"="application/wasm";
            ".pck"="application/octet-stream"; ".png"="image/png"; ".ico"="image/x-icon"; ".svg"="image/svg+xml" }
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Jogo em http://localhost:$port  (Ctrl+C para parar)"
Start-Process "http://localhost:$port/"
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq "") { $rel = "index.html" }
    $file = Join-Path $out $rel
    $res = $ctx.Response
    if ((Test-Path $file -PathType Leaf) -and ([IO.Path]::GetFullPath($file).StartsWith($out))) {
      $ext = [IO.Path]::GetExtension($file)
      $res.ContentType = if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" }
      $res.Headers.Add("Cache-Control", "no-store")
      $bytes = [IO.File]::ReadAllBytes($file)
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else { $res.StatusCode = 404 }
    $res.Close()
  }
} finally { $listener.Stop() }
