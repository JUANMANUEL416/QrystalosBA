# Actualiza cola/manifest.json escaneando archivos .htm/.html
$colaDir = Join-Path $PSScriptRoot "..\cola"
$archivos = Get-ChildItem -Path $colaDir -File -Include *.htm,*.html -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notmatch '^(README|manifest)' } |
  ForEach-Object {
    @{
      nombre = $_.Name
      tipo = if ($_.Name -match 'lista|IX') { "lista" } else { "detalle" }
      descripcion = if ($_.Name -match 'lista|IX') { "Lista aval técnico — varios REQ" } else { "Detalle de un REQ" }
    }
  }

$manifest = @{
  generado = (Get-Date -Format "yyyy-MM-dd")
  archivos = @($archivos)
}

$out = Join-Path $colaDir "manifest.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $out -Encoding UTF8
Write-Host "Manifest actualizado: $out ($($archivos.Count) archivos)"
