# =====================================================
# SIGTS DATABASE RESTORE SCRIPT (PowerShell)
# Smart Information Guide Tour System
# Bwindi Impenetrable National Park
# =====================================================
# Purpose: Restore PostgreSQL database from backup on Windows
# Usage: .\restore.ps1 [-BackupFile <file>] [-ListBackups]
# =====================================================

param(
    [Parameter(ParameterSetName="Restore")]
    [string]$BackupFile,
    
    [Parameter(ParameterSetName="List")]
    [switch]$ListBackups,
    
    [switch]$Force
)

# Load configuration
. "$PSScriptRoot\config.ps1"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $BackupConfig.LogDirectory "restore_$Timestamp.log"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $TimestampLog = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$TimestampLog [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        default { Write-Host $LogEntry }
    }
}

# List available backups
function Show-Backups {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "AVAILABLE BACKUPS FOR RESTORE" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $Backups = Get-ChildItem -Path $BackupConfig.Directory -Filter "sigts_*.zip" | Sort-Object LastWriteTime -Descending
    
    if ($Backups.Count -eq 0) {
        Write-Host "No backups found in $($BackupConfig.Directory)" -ForegroundColor Yellow
    } else {
        Write-Host ("{0,-50} {1,15} {2,20}" -f "Filename", "Size", "Date") -ForegroundColor White
        Write-Host ("-" * 85) -ForegroundColor Gray
        
        foreach ($Backup in $Backups) {
            $Size = if ($Backup.Length -gt 1MB) { "{0:N2} MB" -f ($Backup.Length / 1MB) }
                    else { "{0:N2} KB" -f ($Backup.Length / 1KB) }
            Write-Host ("{0,-50} {1,15} {2,20}" -f $Backup.Name, $Size, $Backup.LastWriteTime)
        }
    }
    
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Test database connection
function Test-DatabaseConnection {
    $env:PGPASSWORD = $DBConfig.Password
    $result = & pg_isready -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User 2>&1
    return ($LASTEXITCODE -eq 0)
}

# Terminate existing connections
function Terminate-Connections {
    Write-Log "Terminating existing connections to database..." -Level "INFO"
    
    $env:PGPASSWORD = $DBConfig.Password
    & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d postgres -c @"
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = '$($DBConfig.Name)';
"@ 2>&1 | Out-Null
}

# Drop and recreate database
function Reset-Database {
    Write-Log "Dropping existing database..." -Level "WARNING"
    
    $env:PGPASSWORD = $DBConfig.Password
    & dropdb -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User --if-exists $DBConfig.Name 2>> $LogFile
    
    Write-Log "Creating new database..." -Level "INFO"
    & createdb -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User $DBConfig.Name 2>> $LogFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to create database" -Level "ERROR"
        return $false
    }
    
    # Enable extensions
    $env:PGPASSWORD = $DBConfig.Password
    & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d $DBConfig.Name -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>&1 | Out-Null
    & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d $DBConfig.Name -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" 2>&1 | Out-Null
    
    Write-Log "Database reset completed" -Level "SUCCESS"
    return $true
}

# Restore from backup
function Restore-Backup {
    param([string]$BackupFilePath)
    
    Write-Log "Restoring from backup: $BackupFilePath" -Level "INFO"
    
    # Create temp directory for extraction
    $TempDir = Join-Path $env:TEMP "sigts_restore_$Timestamp"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    try {
        # Extract zip file
        Write-Log "Extracting backup file..." -Level "INFO"
        Expand-Archive -Path $BackupFilePath -DestinationPath $TempDir -Force
        
        # Find SQL file
        $SqlFile = Get-ChildItem -Path $TempDir -Filter "*.sql" | Select-Object -First 1
        
        if (-not $SqlFile) {
            Write-Log "No SQL file found in backup" -Level "ERROR"
            return $false
        }
        
        Write-Log "Found SQL file: $($SqlFile.Name)" -Level "INFO"
        
        # Restore database
        Write-Log "Restoring database (this may take a while)..." -Level "INFO"
        $env:PGPASSWORD = $DBConfig.Password
        & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d $DBConfig.Name `
            -v ON_ERROR_STOP=1 -f $SqlFile.FullName 2>> $LogFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Database restore completed successfully" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Database restore failed" -Level "ERROR"
            return $false
        }
    }
    finally {
        # Cleanup temp directory
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Verify restore
function Verify-Restore {
    Write-Log "Verifying restore..." -Level "INFO"
    
    $env:PGPASSWORD = $DBConfig.Password
    
    # Check table count
    $TableCount = & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d $DBConfig.Name -t -c @"
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
"@ 2>> $LogFile
    $TableCount = $TableCount.Trim()
    Write-Log "Tables restored: $TableCount" -Level "INFO"
    
    # Check key tables
    $KeyTables = @("users", "animals", "locations", "sightings")
    foreach ($Table in $KeyTables) {
        $RowCount = & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d $DBConfig.Name -t -c "SELECT COUNT(*) FROM $Table;" 2>> $LogFile
        $RowCount = $RowCount.Trim()
        if ($RowCount -match "^\d+$") {
            Write-Log "Table '$Table': $RowCount rows" -Level "INFO"
        } else {
            Write-Log "Table '$Table': Not found or empty" -Level "WARNING"
        }
    }
    
    Write-Log "Restore verification completed" -Level "SUCCESS"
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "SIGTS DATABASE RESTORE UTILITY" -ForegroundColor Cyan
    Write-Host "Smart Information Guide Tour System" -ForegroundColor Cyan
    Write-Host "Bwindi Impenetrable National Park" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "Database: $($DBConfig.Name)" -ForegroundColor White
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # List backups if requested
    if ($ListBackups) {
        Show-Backups
        exit 0
    }
    
    # Check if backup file specified
    if (-not $BackupFile) {
        Write-Host "`nNo backup file specified." -ForegroundColor Yellow
        Show-Backups
        Write-Host "`nUsage: .\restore.ps1 -BackupFile <filename> [-Force]" -ForegroundColor White
        Write-Host "Example: .\restore.ps1 -BackupFile sigts_full_20250421_120000.zip" -ForegroundColor White
        exit 1
    }
    
    # Validate backup file
    $FullBackupPath = Join-Path $BackupConfig.Directory $BackupFile
    if (-not (Test-Path $FullBackupPath)) {
        Write-Log "Backup file not found: $FullBackupPath" -Level "ERROR"
        exit 1
    }
    
    # Confirm restore
    if (-not $Force) {
        Write-Host ""
        Write-Host "WARNING: This will overwrite the entire database!" -ForegroundColor Red
        $Confirm = Read-Host "Type 'RESTORE' to continue"
        if ($Confirm -ne "RESTORE") {
            Write-Host "Restore cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Test database connection
    if (-not (Test-DatabaseConnection)) {
        Write-Log "Cannot connect to database" -Level "ERROR"
        exit 1
    }
    
    # Terminate connections and reset database
    Terminate-Connections
    if (-not (Reset-Database)) {
        Write-Log "Failed to reset database" -Level "ERROR"
        exit 1
    }
    
    # Restore from backup
    if (Restore-Backup -BackupFilePath $FullBackupPath) {
        Verify-Restore
        
        Write-Host ""
        Write-Log "=========================================" -Level "SUCCESS"
        Write-Log "RESTORE COMPLETED SUCCESSFULLY" -Level "SUCCESS"
        Write-Log "Database: $($DBConfig.Name)" -Level "INFO"
        Write-Log "Backup used: $BackupFile" -Level "INFO"
        Write-Log "Log file: $LogFile" -Level "INFO"
        Write-Log "=========================================" -Level "SUCCESS"
    } else {
        Write-Log "Restore failed" -Level "ERROR"
        exit 1
    }
}

# Run main function
Main