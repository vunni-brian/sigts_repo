# =====================================================
# SIGTS DATABASE BACKUP SCRIPT (PowerShell)
# Smart Information Guide Tour System
# Bwindi Impenetrable National Park
# =====================================================
# Purpose: Automated backup of PostgreSQL database on Windows
# Usage: .\backup.ps1 [-BackupType Full|Schema|Data|Tables] [-Compress]
# =====================================================

param(
    [ValidateSet("Full", "Schema", "Data", "Tables")]
    [string]$BackupType = "Full",
    
    [switch]$Compress = $true,
    
    [switch]$NoLog = $false
)

# Load configuration
. "$PSScriptRoot\config.ps1"

# Create directories if they don't exist
$Directories = @($BackupConfig.Directory, $BackupConfig.LogDirectory)
foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Write-Host "Created directory: $Dir" -ForegroundColor Yellow
    }
}

# Set log file
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $BackupConfig.LogDirectory "backup_$Timestamp.log"

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $TimestampLog = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$TimestampLog [$Level] $Message"
    
    if (-not $NoLog) {
        Add-Content -Path $LogFile -Value $LogEntry
    }
    
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        default { Write-Host $LogEntry }
    }
}

# Function to test database connection
function Test-DatabaseConnection {
    Write-Log "Testing database connection..." -Level "INFO"
    
    $env:PGPASSWORD = $DBConfig.Password
    $result = & pg_isready -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Database connection successful" -Level "SUCCESS"
        return $true
    } else {
        Write-Log "Database connection failed: $result" -Level "ERROR"
        return $false
    }
}

# Function to get database size
function Get-DatabaseSize {
    $env:PGPASSWORD = $DBConfig.Password
    $query = "SELECT pg_database_size('$($DBConfig.Name)') / 1024 / 1024 as size_mb"
    
    $result = & psql -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User -d $DBConfig.Name -t -c $query 2>$null
    return [math]::Round([float]$result, 2)
}

# Function to perform full backup
function Backup-Full {
    $BackupFile = Join-Path $BackupConfig.Directory "sigts_full_$Timestamp.sql"
    $CompressedFile = "$BackupFile.zip"
    
    Write-Log "Starting FULL database backup..." -Level "INFO"
    
    $env:PGPASSWORD = $DBConfig.Password
    & pg_dump -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User `
        -F p -b -v -f $BackupFile $DBConfig.Name 2>> $LogFile
    
    if ($LASTEXITCODE -eq 0) {
        $Size = (Get-Item $BackupFile).Length / 1MB
        Write-Log "Backup created: $BackupFile ($([math]::Round($Size, 2)) MB)" -Level "SUCCESS"
        
        if ($Compress) {
            Write-Log "Compressing backup..." -Level "INFO"
            Compress-Archive -Path $BackupFile -DestinationPath $CompressedFile -Force
            Remove-Item $BackupFile -Force
            $CompressedSize = (Get-Item $CompressedFile).Length / 1MB
            Write-Log "Compressed backup: $CompressedFile ($([math]::Round($CompressedSize, 2)) MB)" -Level "SUCCESS"
        }
        
        return $true
    } else {
        Write-Log "Full backup failed" -Level "ERROR"
        return $false
    }
}

# Function to perform schema-only backup
function Backup-Schema {
    $BackupFile = Join-Path $BackupConfig.Directory "sigts_schema_$Timestamp.sql"
    $CompressedFile = "$BackupFile.zip"
    
    Write-Log "Starting SCHEMA-ONLY backup..." -Level "INFO"
    
    $env:PGPASSWORD = $DBConfig.Password
    & pg_dump -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User `
        --schema-only -f $BackupFile $DBConfig.Name 2>> $LogFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Schema backup created: $BackupFile" -Level "SUCCESS"
        
        if ($Compress) {
            Compress-Archive -Path $BackupFile -DestinationPath $CompressedFile -Force
            Remove-Item $BackupFile -Force
            Write-Log "Compressed schema backup: $CompressedFile" -Level "SUCCESS"
        }
        return $true
    } else {
        Write-Log "Schema backup failed" -Level "ERROR"
        return $false
    }
}

# Function to perform data-only backup
function Backup-Data {
    $BackupFile = Join-Path $BackupConfig.Directory "sigts_data_$Timestamp.sql"
    $CompressedFile = "$BackupFile.zip"
    
    Write-Log "Starting DATA-ONLY backup..." -Level "INFO"
    
    $env:PGPASSWORD = $DBConfig.Password
    & pg_dump -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User `
        --data-only --column-inserts -f $BackupFile $DBConfig.Name 2>> $LogFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Data backup created: $BackupFile" -Level "SUCCESS"
        
        if ($Compress) {
            Compress-Archive -Path $BackupFile -DestinationPath $CompressedFile -Force
            Remove-Item $BackupFile -Force
            Write-Log "Compressed data backup: $CompressedFile" -Level "SUCCESS"
        }
        return $true
    } else {
        Write-Log "Data backup failed" -Level "ERROR"
        return $false
    }
}

# Function to backup specific tables
function Backup-Tables {
    $Tables = @("users", "tourists", "animals", "locations", "sightings", 
                "tour_sessions", "cultural_narratives", "parks")
    $SuccessCount = 0
    
    Write-Log "Starting TABLE-SPECIFIC backups..." -Level "INFO"
    
    foreach ($Table in $Tables) {
        $BackupFile = Join-Path $BackupConfig.Directory "sigts_table_${Table}_$Timestamp.sql"
        
        $env:PGPASSWORD = $DBConfig.Password
        & pg_dump -h $DBConfig.Host -p $DBConfig.Port -U $DBConfig.User `
            --table=$Table -f $BackupFile $DBConfig.Name 2>> $LogFile
        
        if ($LASTEXITCODE -eq 0) {
            if ($Compress) {
                $CompressedFile = "$BackupFile.zip"
                Compress-Archive -Path $BackupFile -DestinationPath $CompressedFile -Force
                Remove-Item $BackupFile -Force
            }
            Write-Log "Table backup completed: $Table" -Level "SUCCESS"
            $SuccessCount++
        } else {
            Write-Log "Table backup failed: $Table" -Level "WARNING"
        }
    }
    
    Write-Log "Table backups completed: $SuccessCount of $($Tables.Count)" -Level "INFO"
    return $SuccessCount -eq $Tables.Count
}

# Function to clean old backups
function Clean-OldBackups {
    Write-Log "Cleaning backups older than $($BackupConfig.RetentionDays) days..." -Level "INFO"
    
    $CutoffDate = (Get-Date).AddDays(-$BackupConfig.RetentionDays)
    $OldBackups = Get-ChildItem -Path $BackupConfig.Directory -Filter "sigts_*" | 
                  Where-Object { $_.LastWriteTime -lt $CutoffDate }
    
    foreach ($Backup in $OldBackups) {
        Remove-Item -Path $Backup.FullName -Force
        Write-Log "Removed old backup: $($Backup.Name)" -Level "INFO"
    }
    
    Write-Log "Cleaned $($OldBackups.Count) old backup(s)" -Level "SUCCESS"
}

# Function to list available backups
function Show-Backups {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "AVAILABLE BACKUPS" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $Backups = Get-ChildItem -Path $BackupConfig.Directory -Filter "sigts_*" | Sort-Object LastWriteTime -Descending
    
    if ($Backups.Count -eq 0) {
        Write-Host "No backups found" -ForegroundColor Yellow
    } else {
        Write-Host ("{0,-40} {1,15} {2,20}" -f "Filename", "Size", "Date") -ForegroundColor White
        Write-Host ("-" * 75) -ForegroundColor Gray
        
        foreach ($Backup in $Backups) {
            $Size = if ($Backup.Length -gt 1MB) { "{0:N2} MB" -f ($Backup.Length / 1MB) }
                    else { "{0:N2} KB" -f ($Backup.Length / 1KB) }
            Write-Host ("{0,-40} {1,15} {2,20}" -f $Backup.Name, $Size, $Backup.LastWriteTime)
        }
    }
    
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "SIGTS DATABASE BACKUP UTILITY" -ForegroundColor Cyan
    Write-Host "Smart Information Guide Tour System" -ForegroundColor Cyan
    Write-Host "Bwindi Impenetrable National Park" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "Database: $($DBConfig.Name)" -ForegroundColor White
    Write-Host "Backup Type: $BackupType" -ForegroundColor White
    Write-Host "Backup Directory: $($BackupConfig.Directory)" -ForegroundColor White
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Test database connection
    if (-not (Test-DatabaseConnection)) {
        Write-Log "Backup aborted due to connection failure" -Level "ERROR"
        exit 1
    }
    
    # Get database size
    $DbSize = Get-DatabaseSize
    Write-Log "Database size: $DbSize MB" -Level "INFO"
    
    # Perform backup based on type
    $Success = $false
    switch ($BackupType) {
        "Full" { $Success = Backup-Full }
        "Schema" { $Success = Backup-Schema }
        "Data" { $Success = Backup-Data }
        "Tables" { $Success = Backup-Tables }
    }
    
    if ($Success) {
        # Clean old backups
        Clean-OldBackups
        
        Write-Host ""
        Write-Log "=========================================" -Level "SUCCESS"
        Write-Log "BACKUP COMPLETED SUCCESSFULLY" -Level "SUCCESS"
        Write-Log "Backup location: $($BackupConfig.Directory)" -Level "INFO"
        Write-Log "Log file: $LogFile" -Level "INFO"
        Write-Log "=========================================" -Level "SUCCESS"
    } else {
        Write-Log "Backup failed" -Level "ERROR"
        exit 1
    }
}

# Run main function
Main