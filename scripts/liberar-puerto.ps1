param([int]$Port = 8765, [int]$MaxIntentos = 8)
for ($i = 0; $i -lt $MaxIntentos; $i++) {
    $pids = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
    if (-not $pids) { return $true }
    foreach ($procId in $pids) {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 400
}
$pids = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
if ($pids) {
    Write-Host "Aviso: aun hay procesos en puerto $Port : $($pids -join ', ')"
    return $false
}
return $true
