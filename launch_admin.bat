@echo off
cd /d "%~dp0"
powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0launch_admin.ps1\"' -Verb RunAs -Wait"
pause
