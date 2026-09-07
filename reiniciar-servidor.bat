@echo off
cd /d "%~dp0"
sc query QrystalosBA >nul 2>&1
if %errorLevel%==0 (
  echo Reiniciando servicio QrystalosBA...
  net stop QrystalosBA >nul 2>&1
  net start QrystalosBA
  if errorlevel 1 (
    echo No se pudo iniciar el servicio. Revise data\logs\
    pause
    exit /b 1
  )
  echo Listo. http://localhost:8765/app/
  pause
  exit /b 0
)
echo No hay servicio. Liberando puerto 8765...
python "%~dp0scripts\liberar_puerto.py" --port 8765
if errorlevel 1 (
  echo.
  echo No se pudo liberar el puerto. Cierre ventanas "Qrystalos BA SERVIDOR".
  pause
  exit /b 1
)
echo.
echo Listo. Ahora ejecute abrir-app.bat  o  instalar-servicio.bat
pause
