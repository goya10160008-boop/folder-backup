# Folder Backup Script V2 (parameters + retention cleanup)
#
# Examples:
#   .\BackupV2.ps1                          # uses the default folders below
#   .\BackupV2.ps1 -KeepDays 14             # keep backups for 14 days
#   .\BackupV2.ps1 -DryRun                  # show what cleanup WOULD delete

# 0. Parameters: must be the first thing in the script.
#    Defaults are your V1 folders, so it still works with no arguments.
param(
    [string]$Source      = "C:\Users\JADE\OneDrive\Desktop\Claude Code\BackupTest\Source",
    [string]$Destination = "C:\Users\JADE\OneDrive\Desktop\Claude Code\BackupTest\Backups",
    [int]$KeepDays       = 7,
    [switch]$DryRun
)

# The Logs folder is created next to this script file
$logFolder = Join-Path $PSScriptRoot "Logs"

# 1. Build the names for this run
$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath = Join-Path $Destination "Backup_$timestamp"
$logFile    = Join-Path $logFolder "BackupLog_$timestamp.txt"

# 2. Create the Logs folder if it doesn't exist yet
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# 3. Log helper (now with a WARN level too)
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time [$Level] $Message"

    Add-Content -Path $logFile -Value $line

    switch ($Level) {
        "ERROR" { Write-Host $line -ForegroundColor Red }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line }
    }
}

# 4. Start the backup
Write-Log "Backup started"
Write-Log "Source: $Source"
Write-Log "Destination: $backupPath"

# Check the source folder exists
if (-not (Test-Path $Source)) {
    Write-Log "Source folder not found: $Source" "ERROR"
    Write-Log "Backup stopped" "ERROR"
    exit 1
}

# NEW: stop if there is nothing to back up (Copy-Item would throw an error)
$fileCount = (Get-ChildItem -Path $Source -Recurse -File).Count
if ($fileCount -eq 0) {
    Write-Log "Source folder is empty, nothing to back up" "WARN"
    exit 0
}

# 5. Create the backup folder and copy everything
try {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Copy-Item -Path "$Source\*" -Destination $backupPath -Recurse -ErrorAction Stop

    # NEW: verify the copy by counting files in the backup
    $copiedCount = (Get-ChildItem -Path $backupPath -Recurse -File).Count
    if ($copiedCount -ne $fileCount) {
        Write-Log "File count mismatch: source $fileCount, backup $copiedCount" "WARN"
    }

    Write-Log "Copied $copiedCount of $fileCount file(s)"
    Write-Log "Backup completed successfully"
}
catch {
    Write-Log "Backup failed: $($_.Exception.Message)" "ERROR"
    exit 1   # NEW: tell the caller (Task Scheduler etc.) that it failed
}

# 6. NEW: retention cleanup, delete backups older than $KeepDays days
Write-Log "Checking for backups older than $KeepDays day(s)"

$cutoff = (Get-Date).AddDays(-$KeepDays)
$oldBackups = Get-ChildItem -Path $Destination -Directory -Filter "Backup_*" |
    Where-Object { $_.CreationTime -lt $cutoff }

if (-not $oldBackups) {
    Write-Log "No old backups to delete"
}
else {
    foreach ($old in $oldBackups) {
        try {
            Remove-Item -Path $old.FullName -Recurse -Force -WhatIf:$DryRun -ErrorAction Stop
            if ($DryRun) {
                Write-Log "[DRY RUN] Would delete: $($old.Name)"
            } else {
                Write-Log "Deleted old backup: $($old.Name)"
            }
        }
        catch {
            Write-Log "Could not delete $($old.Name): $($_.Exception.Message)" "ERROR"
        }
    }
}

Write-Host "Log saved to: $logFile" -ForegroundColor Green