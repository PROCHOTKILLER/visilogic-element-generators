<#
.SYNOPSIS
    verify_operands.ps1 - Structural and Subroutine Coverage Auditor for VisiLogic Operands (.csv).
.DESCRIPTION
    Validates a VisiLogic operands CSV file against all import constraints:
    1. Exact row count (8,193 lines = 1 header + 8,192 address rows 0..8191)
    2. Exact 18-column header sequence
    3. Valid delimiter count per row (18 commas)
    4. Maximum 50-character limit on user operand descriptions
    5. Duplicate tag detection within user memory columns
    6. Optional coverage check against compiled *.vlx ladder subroutines
#>

param(
    [string]$CsvPath = "",
    [string]$VlxDir = ""
)

if (-not [string]::IsNullOrWhiteSpace($VlxDir) -and [IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($CsvPath) { $argList += @("-CsvPath", "`"$CsvPath`"") }
        if ($VlxDir) { $argList += @("-VlxDir", "`"$VlxDir`"") }
        $p = Start-Process -FilePath $sysWow64 -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $CsvPath = Join-Path $scriptDir "DEMO_OPERANDS.csv"
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   VISILOGIC OPERANDS CSV INTEGRITY AUDITOR                           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $CsvPath)) {
    Write-Host "[ERROR] Target CSV file does not exist: $CsvPath" -ForegroundColor Red
    exit 1
}

Write-Host "Inspecting file: $CsvPath" -ForegroundColor Yellow

$enc = [System.Text.Encoding]::GetEncoding(1250)
$lines = [System.IO.File]::ReadAllLines($CsvPath, $enc)

$errors = 0
$warnings = 0

# 1. Check total line count (8193)
if ($lines.Count -eq 8193) {
    Write-Host "[OK] Line count: 8193 (1 header + 8192 address rows 0..8191)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Invalid line count: $($lines.Count) (expected exactly 8193)!" -ForegroundColor Red
    $errors++
}

# 2. Check header
$expectedHeader = "Address,MB,MI,MF,ML,MDW,SB,SI,SL,SDW,I,O,T,C,XB,XI,XL,XDW"
if ($lines[0].TrimEnd(',') -eq $expectedHeader) {
    Write-Host "[OK] Header matches the 18-column VisiLogic specification." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Invalid CSV header: '$($lines[0])' (expected '$expectedHeader')" -ForegroundColor Red
    $errors++
}

$cols = $expectedHeader.Split(',')
$userColIndices = @(1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15, 16, 17)
$seenNames = @{}
foreach ($idx in $userColIndices) {
    $seenNames[$cols[$idx]] = @{}
}

$badCommaRows = 0
$tooLongCount = 0
$duplicateCount = 0
$definedUserTags = 0

$grid = @{}
foreach ($c in $cols) {
    if ($c -ne "Address") { $grid[$c] = New-Object string[] 8192 }
}

for ($i = 1; $i -lt [Math]::Min($lines.Count, 8193); $i++) {
    $line = $lines[$i]
    $parts = $line.Split(',')

    # VisiLogic data rows have 18 commas -> 19 elements when split (last element empty)
    if ($parts.Count -lt 18 -or $parts.Count -gt 19) {
        $badCommaRows++
        continue
    }

    $addr = $i - 1
    foreach ($cIdx in $userColIndices) {
        if ($cIdx -ge $parts.Count) { continue }
        $colName = $cols[$cIdx]
        $val = $parts[$cIdx].Trim()
        $grid[$colName][$addr] = $val

        if (-not [string]::IsNullOrEmpty($val)) {
            $definedUserTags++
            if ($val.Length -gt 50) {
                $tooLongCount++
                Write-Host "  [WARNING] Description > 50 chars at $colName $addr ($($val.Length) chars): '$val'" -ForegroundColor Yellow
                $warnings++
            }
            if ($seenNames[$colName].ContainsKey($val)) {
                $duplicateCount++
            } else {
                $seenNames[$colName][$val] = $addr
            }
        }
    }
}

if ($badCommaRows -eq 0) {
    Write-Host "[OK] All data rows have valid column delimiter alignment." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Found $badCommaRows row(s) with corrupted comma counts!" -ForegroundColor Red
    $errors++
}

if ($tooLongCount -eq 0) {
    Write-Host "[OK] All user descriptions comply with the 50-character limit." -ForegroundColor Green
}

if ($duplicateCount -eq 0) {
    Write-Host "[OK] Zero duplicate symbol names in user memory columns ($definedUserTags tags defined)." -ForegroundColor Green
} else {
    Write-Host "[WARNING] Found $duplicateCount duplicate symbol name(s) across user memory columns." -ForegroundColor Yellow
    $warnings++
}

# Optional VLX coverage audit
if (-not [string]::IsNullOrWhiteSpace($VlxDir) -and (Test-Path $VlxDir) -and ([IntPtr]::Size -eq 4)) {
    $typeMap = @{
        1 = "MB"; 3 = "MI"; 5 = "ML"; 7 = "MF";
        9 = "I"; 10 = "O"; 11 = "T"; 12 = "C"; 16 = "MDW"
    }
    $vlxFiles = Get-ChildItem -Path $VlxDir -Filter "*.vlx" -File -Recurse
    $missingTags = 0

    foreach ($vf in $vlxFiles) {
        $cs = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($vf.FullName);Jet OLEDB:Database Password=UniOpenSesame;"
        $conn = New-Object System.Data.OleDb.OleDbConnection($cs)
        try {
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT DISTINCT Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs FROM expimp_LdrElmsOprs"
            $r = $cmd.ExecuteReader()
            while ($r.Read()) {
                if ($r[0] -is [System.DBNull] -or $r[1] -is [System.DBNull]) { continue }
                $tId = [int]$r[0]
                $a = [int]$r[1]
                if ($typeMap.ContainsKey($tId) -and $a -ge 0 -and $a -lt 8192) {
                    $cName = $typeMap[$tId]
                    if ([string]::IsNullOrWhiteSpace($grid[$cName][$a])) {
                        Write-Host "  [WARNING] Subroutine '$($vf.Name)' references untagged operand: $cName $a" -ForegroundColor Yellow
                        $missingTags++
                        $warnings++
                    }
                }
            }
            $r.Close()
        } finally {
            $conn.Close()
        }
    }

    if ($missingTags -eq 0) {
        Write-Host "[OK] 100% of operands referenced in $($vlxFiles.Count) *.vlx file(s) have descriptive tags!" -ForegroundColor Green
    }
}

Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Gray
if ($errors -eq 0) {
    Write-Host "[SUCCESS] CSV file is 100% valid and ready for VisiLogic import ($warnings warning(s))!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILED] CSV verification found $errors error(s) and $warnings warning(s)!" -ForegroundColor Red
    exit 1
}
