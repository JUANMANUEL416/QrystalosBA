@echo off
cd /d "%~dp0"
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
echo  Qrys.Quatec — servidor local
echo  App:      http://localhost:8765/app/
echo  Dictamen: http://localhost:8765/dictamenes/20260829-0100016193.html
echo  Ctrl+C para detener
echo.
python "%~dp0scripts\servir-quatec.py"
if errorlevel 1 pause
