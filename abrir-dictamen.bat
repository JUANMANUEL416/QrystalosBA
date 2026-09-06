@echo off
cd /d "%~dp0"
set ID=20260829-0100016193
if exist "dictamenes\%ID%.html" (
  echo Abriendo dictamenes\%ID%.html
  start "" "%~dp0dictamenes\%ID%.html"
) else (
  echo No encontrado: dictamenes\%ID%.html
  pause
)
