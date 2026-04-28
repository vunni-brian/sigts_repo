@echo off
REM =====================================================
REM SIGTS DATABASE BACKUP SCRIPT (Batch)
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

REM Get current timestamp
for /f "tokens=1-6 delims=/: " %%a in ('echo %date% %time%') do (
    set YEAR=%%c
    set MONTH=%%a
    set DAY=%%b
    set HOUR=%%d
    set MINUTE=%%e
    set SECOND=%%f
)
set TIMESTAMP=%YEAR%%MONTH%%DAY%_%HOUR%%MINUTE%%SECOND%

REM Create directories
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set LOG_FILE=%LOG_DIR%\backup_%TIMESTAMP%.log
set BACKUP_FILE=%BACKUP_DIR%\sigts_full_%TIMESTAMP%.sql

echo =========================================
echo SIGTS DATABASE BACKUP UTILITY
echo Bwindi Impenetrable National Park
echo =========================================
echo Date: %date% %time%
echo Database: %DB_NAME%
echo Backup file: %BACKUP_FILE%
echo =========================================

REM Check PostgreSQL connection
echo %date% %time% - Checking PostgreSQL connection... >> %LOG_FILE%
set PGPASSWORD=%DB_PASSWORD%
pg_isready -h %DB_HOST% -p %DB_PORT% -U %DB_USER% >> %LOG_FILE% 2>&1
if %errorlevel% neq 0 (
    echo %date% %time% - ERROR: PostgreSQL is not running >> %LOG_FILE%
    echo ERROR: PostgreSQL is not running
    pause
    exit /b 1
)

REM Perform backup
echo %date% %time% - Starting database backup... >> %LOG_FILE%
set PGPASSWORD=%DB_PASSWORD%
pg_dump -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -F p -b -v -f "%BACKUP_FILE%" %DB_NAME% >> %LOG_FILE% 2>&1

if %errorlevel% equ 0 (
    echo %date% %time% - Backup completed successfully >> %LOG_FILE%
    echo Backup completed successfully
    
    REM Compress backup
    echo Compressing backup...
    powershell -Command "Compress-Archive -Path '%BACKUP_FILE%' -DestinationPath '%BACKUP_FILE%.zip' -Force"
    del "%BACKUP_FILE%"
    echo Backup compressed: %BACKUP_FILE%.zip
    
    REM Clean backups older than 30 days
    echo Cleaning old backups...
    forfiles /p "%BACKUP_DIR%" /m "sigts_*.zip" /d -30 /c "cmd /c del @file" 2>nul
    
    echo =========================================
    echo BACKUP COMPLETED SUCCESSFULLY
    echo Backup location: %BACKUP_DIR%
    echo Log file: %LOG_FILE%
    echo =========================================
) else (
    echo %date% %time% - ERROR: Backup failed >> %LOG_FILE%
    echo ERROR: Backup failed
    echo Check log file: %LOG_FILE%
    pause
    exit /b 1
)

pause