#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$ServicioId = "QrystalosBA"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Wrapper = Join-Path $Root "data\servicio\$ServicioId.exe"

$existente = Get-Service -Name $ServicioId -ErrorAction SilentlyContinue
if (-not $existente) {
    Write-Host "El servicio $ServicioId no está instalado."
    exit 0
}

if (Test-Path $Wrapper) {
    if ($existente.Status -eq "Running") {
        & $Wrapper stop
        Start-Sleep -Seconds 2
    }
    & $Wrapper uninstall
} else {
    if ($existente.Status -eq "Running") {
        Stop-Service -Name $ServicioId -Force
    }
    sc.exe delete $ServicioId | Out-Null
}

Write-Host "Servicio $ServicioId desinstalado. La app ya no arranca sola."
