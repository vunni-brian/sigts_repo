@echo off
REM =====================================================
REM SIGTS DATABASE RESTORE SCRIPT (Batch)
REM Smart Information Guide Tour System
REM Bwindi Impenetrable National Park
REM =====================================================

setlocal enabledelayedexpansion

REM Configuration
set DB_NAME=sigts_bwindi
set DB_USER=postgres
set DB_HOST=localhost
set DB_PORT=5432
set DB_PASSWORD=sigts@t
set BACKUP_DIR=C:\Backups\SIGTS
set LOG_DIR=C:\Logs\SIGTS

set LOG_FILE=%LOG_DIR%\restore_%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
set LOG_FILE=%LOG_FILE: =0%

echo =========================================
echo SIGTS DATABASE RESTORE UTILITY
echo Bwindi Impenetrable National Park
echo =========================================
echo Date: %date% %time%
echo Database: %DB_NAME%
echo =========================================

REM List available backups
echo.
echo Available backups:
echo.
dir "%BACKUP_DIR%\sigts_*.zip" /b
echo.
echo =========================================

REM Get backup file from user
set /p BACKUP_FILE="Enter backup filename: "

if "%BACKUP_FILE%"=="" (
    echo No backup file specified
    pause
    exit /b 1
)

set FULL_PATH=%BACKUP_DIR%\%BACKUP_FILE%

if not exist "%FULL_PATH%" (
    echo Backup file not found: %FULL_PATH%
    pause
    exit /b 1
)

REM Confirm restore
echo.
echo WARNING: This will overwrite the entire database!
set /p CONFIRM="Type 'RESTORE' to continue: "

if not "%CONFIRM%"=="RESTORE" (
    echo Restore cancelled
    pause
    exit /b 0
)

REM Extract backup
echo %date% %time% - Extracting backup... >> %LOG_FILE%
set EXTRACT_DIR=%TEMP%\sigts_restore
if exist "%EXTRACT_DIR%" rmdir /s /q "%EXTRACT_DIR%"
mkdir "%EXTRACT_DIR%"

powershell -Command "Expand-Archive -Path '%FULL_PATH%' -DestinationPath '%EXTRACT_DIR%' -Force"

REM Find SQL file
for /r "%EXTRACT_DIR%" %%f in (*.sql) do set SQL_FILE=%%f

if "%SQL_FILE%"=="" (
    echo %date% %time% - ERROR: No SQL file found in backup >> %LOG_FILE%
    echo ERROR: No SQL file found in backup
    pause
    exit /b 1
)

REM Terminate connections
echo %date% %time% - Terminating existing connections... >> %LOG_FILE%
set PGPASSWORD=%DB_PASSWORD%
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '%DB_NAME%';" > nul 2>&1

REM Drop and recreate database
echo %date% %time% - Dropping existing database... >> %LOG_FILE%
set PGPASSWORD=%DB_PASSWORD%
dropdb -h %DB_HOST% -p %DB_PORT% -U %DB_USER% --if-exists %DB_NAME% >> %LOG_FILE% 2>&1

echo %date% %time% - Creating new database... >> %LOG_FILE%
createdb -h %DB_HOST% -p %DB_PORT% -U %DB_USER% %DB_NAME% >> %LOG_FILE% 2>&1

if %errorlevel% neq 0 (
    echo %date% %time% - ERROR: Failed to create database >> %LOG_FILE%
    echo ERROR: Failed to create database
    pause
    exit /b 1
)

REM Enable extensions
set PGPASSWORD=%DB_PASSWORD%
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "CREATE EXTENSION IF NOT EXISTS postgis;" > nul 2>&1
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" > nul 2>&1

REM Restore database
echo %date% %time% - Restoring database... >> %LOG_FILE%
set PGPASSWORD=%DB_PASSWORD%
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -v ON_ERROR_STOP=1 -f "%SQL_FILE%" >> %LOG_FILE% 2>&1

if %errorlevel% equ 0 (
    echo %date% %time% - Restore completed successfully >> %LOG_FILE%
    echo Restore completed successfully
) else (
    echo %date% %time% - ERROR: Restore failed >> %LOG_FILE%
    echo ERROR: Restore failed
    echo Check log file: %LOG_FILE%
    pause
    exit /b 1
)

REM Cleanup
rmdir /s /q "%EXTRACT_DIR%"

echo =========================================
echo RESTORE COMPLETED SUCCESSF