# Archivar SQL a sql_refe (PowerShell)
param(
  [Parameter(Mandatory = $true)][string]$IdReq
)

$root = Split-Path $PSScriptRoot -Parent
$sqlRoot = Join-Path $root "sql"
$sqlRefe = Join-Path $root "sql_refe"
$dest = Join-Path $sqlRefe $IdReq

$files = Get-ChildItem -Path $sqlRoot -File -Filter *.sql -ErrorAction SilentlyContinue
if (-not $files.Count) {
  Write-Error "No hay .sql en sql/"
  exit 1
}

New-Item -ItemType Directory -Path $dest -Force | Out-Null
$files | Move-Item -Destination $dest -Force
Write-Host "Archivados $($files.Count) archivos en $dest"
Write-Host "Carpeta sql/ limpia"
