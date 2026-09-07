@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if %errorLevel% neq 0 (
  echo.
  echo  Se necesitan permisos de administrador para quitar el servicio.
  echo.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo  Desinstalando servicio Windows QrystalosBA...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\servicio\desinstalar.ps1"
echo.
pause
