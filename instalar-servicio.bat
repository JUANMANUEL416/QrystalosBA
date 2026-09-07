@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if %errorLevel% neq 0 (
  echo.
  echo  Qrystalos BA — se necesitan permisos de administrador para crear el servicio.
  echo.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo  Instalando servicio Windows QrystalosBA...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\servicio\instalar.ps1"
set ERR=%errorLevel%
echo.
if %ERR% neq 0 (
  echo Fallo al instalar. Revise el mensaje de arriba y data\logs\
) else (
  echo El servidor queda en Automatic: arranca con Windows.
  echo Para abrir la app: abrir-app.bat
)
echo.
pause
exit /b %ERR%
