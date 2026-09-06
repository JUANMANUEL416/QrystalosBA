# Actualiza sql/manifest.json y app/js/sql-manifest.js
$root = Split-Path $PSScriptRoot -Parent
$sqlRoot = Join-Path $root "sql"
$appJs = Join-Path $root "app\js\sql-manifest.js"

$archivos = @(Get-ChildItem -Path $sqlRoot -File -Filter *.sql -ErrorAction SilentlyContinue |
  Sort-Object Name |
  Select-Object -ExpandProperty Name)

$generado = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$manifest = @{
  generado = $generado
  ruta     = $sqlRoot
  archivos = $archivos
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $sqlRoot "manifest.json") -Encoding UTF8

$listaJs = ($archivos | ForEach-Object { "    `"$_`"" }) -join ",`n"
$js = @"
// Auto-generado — no editar. Ejecute: scripts\actualizar-manifest-sql.ps1
window.QRYS_SQL_MANIFEST = {
  generado: "$generado",
  archivos: [
$listaJs
  ]
};
"@

Set-Content -Path $appJs -Value $js -Encoding UTF8
Write-Host "OK: $($archivos.Count) .sql -> manifest.json + app/js/sql-manifest.js"
