#Requires -RunAsAdministrator
<#
  Instala el servicio Windows "QrystalosBA".
  Arranque automático, reinicio si falla, http://127.0.0.1:8765
#>
$ErrorActionPreference = "Stop"

$ServicioId = "QrystalosBA"
$WinSwVersion = "v2.12.0"
$WinSwUrl = "https://github.com/winsw/winsw/releases/download/$WinSwVersion/WinSW-x64.exe"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DataDir = Join-Path $Root "data\servicio"
$LogDir = Join-Path $Root "data\logs"
$Wrapper = Join-Path $DataDir "$ServicioId.exe"
$XmlPath = Join-Path $DataDir "$ServicioId.xml"
$ScriptPy = Join-Path $Root "scripts\servir-qrystalos-ba.py"

function Test-Health {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:8765/api/health"
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Get-PythonExe {
    $cmds = @(
        @{ File = "py"; Args = @("-3", "-c", "import sys; print(sys.executable)") },
        @{ File = "python"; Args = @("-c", "import sys; print(sys.executable)") }
    )
    foreach ($c in $cmds) {
        $cmd = Get-Command $c.File -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        try {
            $exe = & $cmd.Source @($c.Args) 2>$null | Select-Object -Last 1
            if ($exe -and (Test-Path $exe)) { return $exe.Trim() }
        } catch { }
    }
    throw "No se encontró Python. Instálelo y deje 'py' o 'python' en el PATH."
}

if (-not (Test-Path $ScriptPy)) {
    throw "No está el servidor: $ScriptPy"
}

New-Item -ItemType Directory -Force -Path $DataDir, $LogDir | Out-Null

Write-Host "Python..."
$python = Get-PythonExe
Write-Host "  $python"

if (-not (Test-Path $Wrapper)) {
    Write-Host "Descargando WinSW $WinSwVersion..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $WinSwUrl -OutFile $Wrapper -UseBasicParsing
}

$xml = @"
<service>
  <id>$ServicioId</id>
  <name>Qrystalos BA</name>
  <description>Servidor local de la oficina Qrystalos BA (http://127.0.0.1:8765/app/)</description>
  <executable>$python</executable>
  <arguments>"$ScriptPy"</arguments>
  <workingdirectory>$Root</workingdirectory>
  <env name="PYTHON_BOT" value="C:\Users\JOSE MANUEL\AppData\Local\Programs\Python\Python312\python.exe"/>
  <env name="QRISTALOS_BOT_USERPROFILE" value="C:\Users\JOSE MANUEL"/>
  <logpath>$LogDir</logpath>
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>8</keepFiles>
  </log>
  <onfailure action="restart" delay="5 sec"/>
  <onfailure action="restart" delay="10 sec"/>
  <onfailure action="restart" delay="30 sec"/>
  <resetfailure>1 hour</resetfailure>
  <startmode>Automatic</startmode>
  <stoptimeout>15 sec</stoptimeout>
</service>
"@
Set-Content -Path $XmlPath -Value $xml -Encoding UTF8

$existente = Get-Service -Name $ServicioId -ErrorAction SilentlyContinue
if ($existente) {
    Write-Host "El servicio ya existe: se reinstala."
    if ($existente.Status -eq "Running") {
        & $Wrapper stop
        Start-Sleep -Seconds 2
    }
    & $Wrapper uninstall
    Start-Sleep -Seconds 1
}

Write-Host "Instalando servicio $ServicioId..."
& $Wrapper install
if ($LASTEXITCODE -ne 0) {
    throw "WinSW install falló (código $LASTEXITCODE)."
}

sc.exe failure $ServicioId reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
sc.exe config $ServicioId start= auto | Out-Null

Write-Host "Iniciando..."
& $Wrapper start

$ok = $false
for ($i = 0; $i -lt 30; $i++) {
    if (Test-Health) { $ok = $true; break }
    Start-Sleep -Seconds 1
}

$svc = Get-Service -Name $ServicioId
Write-Host ""
Write-Host "Servicio: $($svc.DisplayName)  estado=$($svc.Status)  inicio=$($svc.StartType)"
if ($ok) {
    Write-Host "Listo: http://localhost:8765/app/"
} else {
    Write-Host "AVISO: el servicio está $($svc.Status) pero /api/health no respondió en 30 s."
    Write-Host "Revise $LogDir"
    exit 1
}
