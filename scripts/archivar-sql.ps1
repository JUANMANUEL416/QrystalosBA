# Archivar SQL del caso a sql_refe (PowerShell)
param(
  [Parameter(Mandatory = $true)][string]$IdReq,
  [Parameter(Mandatory = $true)][string]$IdCaso
)

$root = Split-Path $PSScriptRoot -Parent
$sqlRoot = Join-Path $root "activo\$IdCaso\sql"
$sqlRefe = Join-Path $root "sql_refe"
$dest = Join-Path $sqlRefe $IdReq

if (-not (Test-Path $sqlRoot)) {
  Write-Error "No existe activo/$IdCaso/sql/"
  exit 1
}

$files = Get-ChildItem -Path $sqlRoot -File -Filter *.sql -ErrorAction SilentlyContinue
if (-not $files.Count) {
  Write-Error "No hay .sql en activo/$IdCaso/sql/"
  exit 1
}

New-Item -ItemType Directory -Path $dest -Force | Out-Null
$files | Move-Item -Destination $dest -Force
Write-Host "Archivados $($files.Count) archivos de activo/$IdCaso/sql en $dest"
