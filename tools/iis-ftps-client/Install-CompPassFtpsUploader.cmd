@echo off
setlocal
if exist "%~dp0AOtransact.FtpsUploader.exe" (
  "%~dp0AOtransact.FtpsUploader.exe" install
  exit /b %errorlevel%
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-FtpsUploader.ps1"
exit /b %errorlevel%
