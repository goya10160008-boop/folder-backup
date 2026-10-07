BeforeAll {
    $ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot "..\BackupV2.ps1")).Path

    function Invoke-Backup {
        param([string[]]$ScriptArgs)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs | Out-Null
        return $LASTEXITCODE
    }
}

Describe "BackupV2.ps1" {

    BeforeEach {
        $Root = Join-Path ([System.IO.Path]::GetTempPath()) ("bk_" + [guid]::NewGuid())
        $Src  = Join-Path $Root "Source"
        $Dst  = Join-Path $Root "Backups"
        New-Item -ItemType Directory -Path (Join-Path $Src "sub") -Force | Out-Null
        Set-Content -Path (Join-Path $Src "a.txt") -Value "hello"
        Set-Content -Path (Join-Path $Src "sub\b.txt") -Value "world"
    }

    AfterEach {
        Remove-Item -Path $Root -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "creates a timestamped backup containing all files, including subfolders" {
        $code = Invoke-Backup -ScriptArgs @("-Source", $Src, "-Destination", $Dst)
        $code | Should -Be 0
        $backups = Get-ChildItem -Path $Dst -Directory -Filter "Backup_*"
        $backups.Count | Should -Be 1
        Test-Path (Join-Path $backups[0].FullName "a.txt")     | Should -BeTrue
        Test-Path (Join-Path $backups[0].FullName "sub\b.txt") | Should -BeTrue
    }

    It "exits with code 1 when the source folder does not exist" {
        $code = Invoke-Backup -ScriptArgs @("-Source", (Join-Path $Root "Nope"), "-Destination", $Dst)
        $code | Should -Be 1
    }

    It "exits cleanly and creates no backup when the source is empty" {
        Get-ChildItem -Path $Src -Recurse -File | Remove-Item -Force
        $code = Invoke-Backup -ScriptArgs @("-Source", $Src, "-Destination", $Dst)
        $code | Should -Be 0
        Test-Path $Dst | Should -BeFalse
    }

    It "deletes backups older than KeepDays" {
        $old = New-Item -ItemType Directory -Path (Join-Path $Dst "Backup_2020-01-01_00-00-00") -Force
        $old.CreationTime = (Get-Date).AddDays(-30)
        $code = Invoke-Backup -ScriptArgs @("-Source", $Src, "-Destination", $Dst, "-KeepDays", "7")
        $code | Should -Be 0
        Test-Path $old.FullName | Should -BeFalse
    }

    It "does not delete anything with -DryRun" {
        $old = New-Item -ItemType Directory -Path (Join-Path $Dst "Backup_2020-01-01_00-00-00") -Force
        $old.CreationTime = (Get-Date).AddDays(-30)
        $code = Invoke-Backup -ScriptArgs @("-Source", $Src, "-Destination", $Dst, "-KeepDays", "7", "-DryRun")
        $code | Should -Be 0
        Test-Path $old.FullName | Should -BeTrue
    }
}
