@echo off
setlocal
py -3 "%~dp0sync-chat-qrystalos-ba.py" %* 2>nul
if errorlevel 1 python "%~dp0sync-chat-qrystalos-ba.py" %*
