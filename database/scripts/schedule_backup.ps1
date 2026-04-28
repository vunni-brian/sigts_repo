# =====================================================
# SCHEDULE AUTOMATED BACKUPS (PowerShell)
# Smart Information Guide Tour System
# Bwindi Impenetrable National Park
# =====================================================
# Purpose: Create scheduled task for automatic daily backups
# Run as Administrator
# =====================================================

# Run as Administrator check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupScript = Join-Path $ScriptPath "backup.ps1"

# Task configuration
$TaskName = "SIGTS_Daily_Backup"
$TaskDescription = "Automated daily backup of SIGTS database for Bwindi National Park"

# Create trigger (daily at 2:00 AM)
$Trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

# Create action (run PowerShell with backup script)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$BackupScript`" -BackupType Full"

# Create settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries $false `
    -DontStopIfGoingOnBatteries $true `
    -StartWhenAvailable $true `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -RestartCount 3

# Register task
Register-ScheduledTask -TaskName $TaskName `
    -Trigger $Trigger `
    -Action $Action `
    -Settings $Settings `
    -Description $TaskDescription `
    -RunLevel Highest

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "SCHEDULED TASK CREATED SUCCESSFULLY" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Task Name: $TaskName" -ForegroundColor White
Write-Host "Schedule: Daily at 2:00 AM" -ForegroundColor White
Write-Host "Script: $BackupScript" -ForegroundColor White
Write-Host ""
Write-Host "To verify, open Task Scheduler and look for '$TaskName'" -ForegroundColor Yellow
Write-Host "To run manually: .\backup.ps1" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Green