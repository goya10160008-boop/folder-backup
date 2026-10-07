# Folder Backup Script (with logging)

# 1. Settings: change these to your own folders
$source      = "C:\Users\JADE\OneDrive\Desktop\Claude Code\BackupTest\Source"
$destination = "C:\Users\JADE\OneDrive\Desktop\Claude Code\BackupTest\Backups"

# The Logs folder is created next to this script file
$logFolder   = Join-Path $PSScriptRoot "Logs"

# 2. Build the names for this run (timestamp keeps every run separate)
$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath = Join-Path $destination "Backup_$timestamp"
$logFile    = Join-Path $logFolder "BackupLog_$timestamp.txt"

# 3. Create the Logs folder if it doesn't exist yet
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# 4. A small helper that writes a line to the screen AND to the log file
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time [$Level] $Message"

    Add-Content -Path $logFile -Value $line

    if ($Level -eq "ERROR") {
        Write-Host $line -ForegroundColor Red
    } else {
        Write-Host $line
    }
}

# 5. Start the backup
Write-Log "Backup started"
Write-Log "Source: $source"
Write-Log "Destination: $backupPath"

# Check the source folder exists
if (-not (Test-Path $source)) {
    Write-Log "Source folder not found: $source" "ERROR"
    Write-Log "Backup stopped" "ERROR"
    exit 1
}

# Create the backup folder and copy everything
try {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    $fileCount = (Get-ChildItem -Path $source -Recurse -File).Count

    Copy-Item -Path "$source\*" -Destination $backupPath -Recurse -ErrorAction Stop

    Write-Log "Copied $fileCount file(s)"
    Write-Log "Backup completed successfully"
}
catch {
    Write-Log "Backup failed: $($_.Exception.Message)" "ERROR"
}

Write-Host "Log saved to: $logFile" -ForegroundColor Green