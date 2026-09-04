@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_gpu_torch.ps1"
echo.
pause
