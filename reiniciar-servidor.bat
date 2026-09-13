@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if %errorLevel% neq 0 (
  echo.
  echo  Reiniciar Qrystalos BA requiere permisos de administrador
  echo  ^(el servicio Windows QrystalosBA debe detenerse^).
  echo.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

sc query QrystalosBA >nul 2>&1
if %errorLevel%==0 (
  echo Reiniciando servicio QrystalosBA...
  net stop QrystalosBA
  timeout /t 2 /nobreak >nul
  net start QrystalosBA
  if errorlevel 1 (
    echo No se pudo iniciar el servicio. Revise data\logs\
    pause
    exit /b 1
  )
) else (
  echo No hay servicio Windows. Liberando puerto 8765...
  python "%~dp0scripts\liberar_puerto.py" --port 8765
  if errorlevel 1 (
    echo.
    echo No se pudo liberar el puerto. Cierre ventanas "Qrystalos BA SERVIDOR".
    pause
    exit /b 1
  )
  echo Inicie el servidor con abrir-app.bat o servir-app.bat
  pause
  exit /b 0
)

echo Esperando /api/health...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ok=$false; for($i=0;$i -lt 20;$i++){ try { $r=Invoke-RestMethod -TimeoutSec 3 'http://127.0.0.1:8765/api/health'; if($r.features -contains 'imagenesAnalisis'){ Write-Host 'OK: capturas para analisis disponibles.' -ForegroundColor Green; $ok=$true; break } elseif($r.ok){ Write-Host 'AVISO: servidor activo pero SIN capturas (codigo viejo en memoria?).' -ForegroundColor Yellow; $ok=$true; break } } catch {} Start-Sleep -Seconds 1 }; if(-not $ok){ Write-Host 'ERROR: /api/health no respondio.' -ForegroundColor Red; exit 1 }"

echo.
echo Listo. Abra http://localhost:8765/app/ y pulse Ctrl+F5
pause
