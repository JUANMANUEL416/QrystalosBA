@echo off
setlocal
cd /d "%~dp0"
set PORT=8765
set URL=http://localhost:%PORT%/app/

echo.
echo  Qrystalos BA — iniciando...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\actualizar-manifest-sql.ps1"
python "%~dp0scripts\liberar_puerto.py" --port %PORT%
if errorlevel 1 (
  echo.
  echo No se pudo liberar el puerto %PORT%. Cierre ventanas del servidor y reintente.
  pause
  exit /b 1
)

start "Qrystalos BA SERVIDOR" cmd /k "%~dp0servir-app.bat"

echo Esperando servidor en puerto %PORT%...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ok=$false; for($i=0;$i -lt 30;$i++){ try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://127.0.0.1:%PORT%/api/health'; if($r.StatusCode -eq 200){ $ok=$true; break } } catch {} Start-Sleep -Seconds 1 }; if(-not $ok){ Write-Host 'ERROR: el servidor no respondio en 30 s.' -ForegroundColor Red; Write-Host 'Revise la ventana Qrystalos BA SERVIDOR.' -ForegroundColor Yellow; exit 1 }"

if errorlevel 1 (
  echo.
  echo No se pudo conectar al servidor. Deje abierta la ventana del servidor y abra manualmente:
  echo   %URL%
  pause
  exit /b 1
)

echo Servidor listo. Abriendo navegador...
start "" "%URL%"
echo.
echo Listo. NO cierre la ventana "Qrystalos BA SERVIDOR" mientras use la app.
echo Dictamen directo: http://localhost:%PORT%/dictamenes/20260829-0100016193.html
echo.
