@echo off
cd /d "%~dp0"
sc query QrystalosBA 2>nul | find /I "RUNNING" >nul
if %errorLevel%==0 (
  echo.
  echo  El servicio Windows QrystalosBA ya esta en marcha.
  echo  App: http://localhost:8765/app/
  echo  No abra otra copia. Para reiniciar: reiniciar-servidor.bat
  echo.
  pause
  exit /b 0
)
echo Deteniendo servidores anteriores en puerto 8765...
python "%~dp0scripts\liberar_puerto.py" --port 8765
if errorlevel 1 (
  echo.
  echo AVISO: el puerto 8765 sigue ocupado. Ejecute reiniciar-servidor.bat
  echo.
  pause
  exit /b 1
)
echo.
echo  Qrystalos BA — servidor local ^(ventana temporal^)
echo  App:      http://localhost:8765/app/
echo  Para dejarlo siempre encendido: instalar-servicio.bat
echo  Ctrl+C para detener
echo.
python "%~dp0scripts\servir-qrystalos-ba.py"
if errorlevel 1 pause
