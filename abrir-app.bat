@echo off
setlocal
cd /d "%~dp0"
set PORT=8765
set URL=http://localhost:%PORT%/app/
set SVC=QrystalosBA

echo.
echo  Qrystalos BA
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\actualizar-manifest-sql.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://127.0.0.1:%PORT%/api/health'; if($r.StatusCode -eq 200){ exit 0 } } catch {}; exit 1"
if %errorLevel%==0 goto OPEN

sc query %SVC% >nul 2>&1
if %errorLevel%==0 (
  echo Iniciando servicio %SVC%...
  net start %SVC% >nul 2>&1
) else (
  echo No hay servicio Windows. Ventana temporal — use instalar-servicio.bat para dejarlo siempre encendido.
  python "%~dp0scripts\liberar_puerto.py" --port %PORT%
  if errorlevel 1 (
    echo No se pudo liberar el puerto %PORT%.
    pause
    exit /b 1
  )
  start "Qrystalos BA SERVIDOR" cmd /k "%~dp0servir-app.bat"
)

echo Esperando servidor en puerto %PORT%...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ok=$false; for($i=0;$i -lt 30;$i++){ try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://127.0.0.1:%PORT%/api/health'; if($r.StatusCode -eq 200){ $ok=$true; break } } catch {} Start-Sleep -Seconds 1 }; if(-not $ok){ Write-Host 'ERROR: el servidor no respondio en 30 s.' -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
  echo.
  echo No se pudo conectar. Si instaló el servicio, revise data\logs\
  echo   %URL%
  pause
  exit /b 1
)

:OPEN
echo Servidor listo. Abriendo navegador...
start "" "%URL%"
echo.
echo Listo. App: %URL%
echo.
