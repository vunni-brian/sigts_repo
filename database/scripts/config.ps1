# =====================================================
# SIGTS DATABASE CONFIGURATION FILE
# Smart Information Guide Tour System
# Bwindi Impenetrable National Park
# =====================================================

# Database Configuration
$Script:DBConfig = @{
    Name = "sigts_bwindi"
    User = "postgres"
    Host = "localhost"
    Port = 5432
    Password = "sigts@t"
}

# Backup Configuration
$Script:BackupConfig = @{
    Directory = "C:\Backups\SIGTS"
    RetentionDays = 30
    LogDirectory = "C:\Logs\SIGTS"
    Compression = $true
}

# PostgreSQL Paths (adjust if different)
$Script:PGPaths = @{
    Bin = "C:\Program Files\PostgreSQL\15\bin"
    Data = "C:\Program Files\PostgreSQL\15\data"
}

# Email Configuration (optional - for notifications)
$Script:EmailConfig = @{
    Enabled = $false
    SmtpServer = "smtp.bwindi.go.ug"
    From = "backup@bwindi.go.ug"
    To = "admin@bwindi.go.ug"
}

# Add PostgreSQL to PATH for the current session
$env:Path += ";$($Script:PGPaths.Bin)"