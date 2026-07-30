@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%CompTrans.config"

if not exist "%CONFIG_FILE%" (
    echo Config file not found: "%CONFIG_FILE%"
    exit /b 1
)

for %%V in (
    BACKUP_DIR
    STATE_FILE
    TRANSACTION_FINAL_FILE
    TEMP_TRANSACTION_FILE
    WORK_DIR
    ARCHIVE_DIR
    TABLE_LIST
    DBTRAN_PATH
    ZIP_EXE_PATH
    DELSHADOW_SCRIPT
    SOURCE_DRIVE
    SOURCE_LOG_RELATIVE_PATH
) do set "%%V="

for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    set "KEY=%%A"
    set "VALUE=%%B"

    if defined KEY if not "!KEY:~0,1!"==";" if not "!KEY:~0,1!"=="#" (
        for /f "tokens=* delims= " %%K in ("!KEY!") do set "KEY=%%K"
        if defined VALUE (
            for /f "tokens=* delims= " %%V in ("!VALUE!") do set "VALUE=%%V"
        )
        set "!KEY!=!VALUE!"
    )
)

for %%V in (
    BACKUP_DIR
    STATE_FILE
    TRANSACTION_FINAL_FILE
    TEMP_TRANSACTION_FILE
    WORK_DIR
    ARCHIVE_DIR
    TABLE_LIST
    DBTRAN_PATH
    ZIP_EXE_PATH
    DELSHADOW_SCRIPT
    SOURCE_DRIVE
    SOURCE_LOG_RELATIVE_PATH
) do (
    if not defined %%V (
        echo Missing config value: %%V
        exit /b 1
    )
)

if not exist "%DBTRAN_PATH%" (
    echo dbtran executable not found: "%DBTRAN_PATH%"
    exit /b 1
)

if not exist "%ZIP_EXE_PATH%" (
    echo 7-Zip executable not found: "%ZIP_EXE_PATH%"
    exit /b 1
)

if not exist "%DELSHADOW_SCRIPT%" (
    echo DelShadow script not found: "%DELSHADOW_SCRIPT%"
    exit /b 1
)

set "CONFIG_TABLE_LIST=%TABLE_LIST%"
set "TABLE_LIST="
:build_tables
if "%~1"=="" goto tables_ready
if defined TABLE_LIST (
    set "TABLE_LIST=!TABLE_LIST!,%~1"
) else (
    set "TABLE_LIST=%~1"
)
shift
goto build_tables

:tables_ready
if not defined TABLE_LIST set "TABLE_LIST=%CONFIG_TABLE_LIST%"
if not defined TABLE_LIST (
    echo No OASIS tables were provided.
    echo Set TABLE_LIST in "%CONFIG_FILE%" or pass tables on the command line.
    echo Example: %~nx0 oasis.CHSC_USERS oasis.CHSC_POLINE oasis.CHSC_PROJECT
    exit /b 1
)

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%"

set "LASTOFFSET="
if exist "%STATE_FILE%" (
    for /f "tokens=*" %%A in ('findstr /C:"Transaction log ends at offset " "%STATE_FILE%"') do (
        set "LINE=%%A"
        set "LASTOFFSET=!LINE:*Transaction log ends at offset =!"
    )
)

if "!LASTOFFSET!"=="" (
    set "LASTOFFSET=00000000000001"
)

set "TMPFILE=%TEMP%\CompTrans_shadow_create.out"
set "SHADOWCOPY="
set "SHADOWCOPY_ID="

vssadmin create shadow /for=%SOURCE_DRIVE% > "%TMPFILE%" 2>&1
if errorlevel 1 (
    echo Failed to create shadow copy.
    type "%TMPFILE%"
    del "%TMPFILE%" >nul 2>&1
    exit /b 1
)

for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"Shadow Copy ID" "%TMPFILE%"') do (
    set "SHADOWCOPY_ID=%%B"
)

for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"Shadow Copy Volume Name" "%TMPFILE%"') do (
    set "SHADOWCOPY=%%B"
)

del "%TMPFILE%" >nul 2>&1

for /f "tokens=* delims= " %%A in ("!SHADOWCOPY_ID!") do set "SHADOWCOPY_ID=%%A"
for /f "tokens=* delims= " %%A in ("!SHADOWCOPY!") do set "SHADOWCOPY=%%A"

if "!SHADOWCOPY_ID!"=="" (
    echo Failed to parse shadow copy ID.
    exit /b 1
)

if "!SHADOWCOPY!"=="" (
    echo Failed to parse shadow copy volume name.
    exit /b 1
)

> "%DELSHADOW_SCRIPT%" (
    echo delete shadows id !SHADOWCOPY_ID!
    echo exit
)

set "SOURCE_FILE=!SHADOWCOPY!\%SOURCE_LOG_RELATIVE_PATH%"

mklink /D "%BACKUP_DIR%" "!SHADOWCOPY!" >nul

set SOURCE_FILE="%BACKUP_DIR%\!SOURCE_LOG_RELATIVE_PATH!"

echo !SOURCE_FILE!

if errorlevel 1 (
    echo Failed to create symbolic link: "%BACKUP_DIR%"
    diskshadow /s "%DELSHADOW_SCRIPT%" >nul 2>&1
    exit /b 1
)

echo Using transaction offset: !LASTOFFSET!
echo Tables: !TABLE_LIST!

"%DBTRAN_PATH%" "!SOURCE_FILE!" -y -ir !LASTOFFSET! -q -it "!TABLE_LIST!" -n "%TRANSACTION_FINAL_FILE%"
if errorlevel 1 goto cleanup_fail

"%DBTRAN_PATH%" "!SOURCE_FILE!" -y -ir !LASTOFFSET! -it "oasis.CHSC_USERS" -n "%TEMP_TRANSACTION_FILE%" > "%STATE_FILE%"
if errorlevel 1 goto cleanup_fail

if "!LASTOFFSET!"=="00000000000001" (
    for /f "tokens=*" %%A in ('findstr /C:"Transaction log ends at offset " "%STATE_FILE%"') do (
        set "LINE=%%A"
        set "LASTOFFSET=!LINE:*Transaction log ends at offset =!"
    )
)

if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%"

diskshadow /s "%DELSHADOW_SCRIPT%"
if errorlevel 1 (
    echo Warning: diskshadow cleanup reported an error for !SHADOWCOPY_ID!
)

if not exist "%ARCHIVE_DIR%" mkdir "%ARCHIVE_DIR%"

set "ZIP_FILE=%WORK_DIR%\!LASTOFFSET!.zip"
"%ZIP_EXE_PATH%" a -r "!ZIP_FILE!" "%TRANSACTION_FINAL_FILE%"
if errorlevel 1 exit /b 1

move /Y "!ZIP_FILE!" "%ARCHIVE_DIR%" >nul
forfiles /P "%ARCHIVE_DIR%" /M *.zip /D -5 /C "cmd /c del /q @path" >nul 2>&1
del "%WORK_DIR%\*.trn" >nul 2>&1

endlocal
exit /b 0

:cleanup_fail
set "ERR=%ERRORLEVEL%"
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%"
diskshadow /s "%DELSHADOW_SCRIPT%" >nul 2>&1
endlocal & exit /b %ERR%
