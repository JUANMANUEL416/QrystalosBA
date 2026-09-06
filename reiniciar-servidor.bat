@echo off
cd /d "%~dp0"
echo Matando procesos en puerto 8765...
python "%~dp0scripts\liberar_puerto.py" --port 8765
if errorlevel 1 (
  echo.
  echo No se pudo liberar el puerto. Cierre manualmente ventanas "Qrystalos BA SERVIDOR".
  pause
  exit /b 1
)
echo.
echo Listo. Ahora ejecute abrir-app.bat
pause
