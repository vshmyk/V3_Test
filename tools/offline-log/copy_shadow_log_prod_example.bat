@echo off
setlocal

REM Production example for AOtransact source:
REM   Source drive: D:
REM   Database/log folder in shadow: Oasis_Database
REM   Log file: Oasis_Log.LDF
REM   Output copy: C:\Temp\Oasis_Log_from_shadow.LDF

set DRIVE=D:
set REL_PATH=Oasis_Database\Oasis_Log.LDF
set DST=C:\Temp\Oasis_Log_from_shadow.LDF
set TMPFILE=%TEMP%\aotransact_shadow_create_out.txt
set SHADOW_DEVICE=

if not exist C:\Temp (
    mkdir C:\Temp
)

echo Creating shadow copy for %DRIVE%
vssadmin create shadow /for=%DRIVE% > "%TMPFILE%" 2>&1
if errorlevel 1 (
    echo Failed to create shadow copy.
    type "%TMPFILE%"
    exit /b 1
)

for /f "tokens=1,* delims=:" %%A in ('findstr /I "Shadow Copy Volume Name" "%TMPFILE%"') do (
    set SHADOW_DEVICE=%%B
)

if "%SHADOW_DEVICE%"=="" (
    echo Failed to parse shadow device from vssadmin output.
    type "%TMPFILE%"
    exit /b 1
)

set SHADOW_DEVICE=%SHADOW_DEVICE: =%

echo Shadow device: %SHADOW_DEVICE%
echo Copying:
echo   %SHADOW_DEVICE%\%REL_PATH%
echo to
echo   %DST%

copy /Y "%SHADOW_DEVICE%\%REL_PATH%" "%DST%"
if errorlevel 1 (
    echo Copy failed.
    exit /b 1
)

echo.
echo Done.
echo Output file: %DST%
echo Shadow output log: %TMPFILE%
echo.
echo Note: this script does not delete the shadow copy.
echo If you want cleanup after copy, use:
echo   vssadmin delete shadows /for=%DRIVE% /oldest /quiet

endlocal
