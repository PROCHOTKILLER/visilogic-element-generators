<#
.SYNOPSIS
    verify_data_tables.ps1 - Structural and Binary Payload Auditor for VisiLogic Data Tables (.xml).
.DESCRIPTION
    Verifies XML schema structure, column definitions, row counts, and exact byte length alignment
    of the Base64-encoded CellsData binary matrix against the sum of column byte widths.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$XmlPath = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($XmlPath)) {
    $XmlPath = Join-Path $scriptDir "DEMO_DATA_TABLES.xml"
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   VISILOGIC DATA TABLES XML INTEGRITY AUDITOR                        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $XmlPath)) {
    Write-Host "[ERROR] Target XML file does not exist: $XmlPath" -ForegroundColor Red
    exit 1
}

Write-Host "Inspecting file: $XmlPath" -ForegroundColor Yellow

[xml]$doc = Get-Content -Path $XmlPath -Raw -Encoding UTF8
$root = $doc.DataTables
if ($null -eq $root) {
    Write-Host "[ERROR] Missing root <DataTables> node!" -ForegroundColor Red
    exit 1
}

$tables = @($root.DataTable)
if ($tables.Count -eq 0) {
    Write-Host "[ERROR] File contains no <DataTable> definitions!" -ForegroundColor Red
    exit 1
}

$errors = 0
$warnings = 0

function Get-ColumnWidth([int]$dt, [int]$sz) {
    switch ($dt) {
        1 { return 1 * $sz }
        2 { return 2 * $sz }
        3 { return 2 * $sz }
        4 { return 4 * $sz }
        5 { return 4 * $sz }
        6 { return 4 * $sz }
        7 { return 2 * $sz }
        8 { return 1 * $sz }
        9 { return 4 * $sz }
    }
    return -1
}

foreach ($tbl in $tables) {
    $tName = [string]$tbl.Name
    $numRows = [int]$tbl.NumOfRows
    $cols = @($tbl.Columns.Column)

    Write-Host "`n--- Table: '$tName' (Rows: $numRows, Columns: $($cols.Count)) ---" -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($tName)) {
        Write-Host "  [ERROR] Table name is empty!" -ForegroundColor Red
        $errors++
    }

    if ($numRows -le 0) {
        Write-Host "  [ERROR] Invalid row count ($numRows)!" -ForegroundColor Red
        $errors++
    }

    if ($cols.Count -eq 0) {
        Write-Host "  [ERROR] Table has no columns!" -ForegroundColor Red
        $errors++
        continue
    }

    $rowByteWidth = 0
    $colNames = @{}

    foreach ($c in $cols) {
        $cDesc = [string]$c.Description
        $cType = [int]$c.DataType
        $cSize = [int]$c.Size

        if ([string]::IsNullOrWhiteSpace($cDesc)) {
            Write-Host "  [ERROR] Column has an empty <Description> tag!" -ForegroundColor Red
            $errors++
        } elseif ($colNames.ContainsKey($cDesc)) {
            Write-Host "  [WARNING] Duplicate column name '$cDesc' in table '$tName'." -ForegroundColor Yellow
            $warnings++
        } else {
            $colNames[$cDesc] = $true
        }

        $w = Get-ColumnWidth -dt $cType -sz $cSize
        if ($w -le 0) {
            Write-Host "  [ERROR] Column '$cDesc' has unsupported DataType=$cType or Size=$cSize!" -ForegroundColor Red
            $errors++
        } else {
            $rowByteWidth += $w
        }
    }

    $expectedTotalBytes = $numRows * $rowByteWidth
    Write-Host "  [OK] Row binary width: $rowByteWidth bytes | Expected total payload: $expectedTotalBytes bytes" -ForegroundColor Gray

    $b64 = [string]$tbl.CellsData
    if ([string]::IsNullOrWhiteSpace($b64)) {
        Write-Host "  [ERROR] <CellsData> Base64 payload is empty!" -ForegroundColor Red
        $errors++
    } else {
        try {
            $rawBytes = [Convert]::FromBase64String($b64.Trim())
            if ($rawBytes.Length -eq $expectedTotalBytes) {
                Write-Host "  [OK] CellsData Base64 length matches exactly ($($rawBytes.Length) bytes)." -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] CellsData byte length mismatch! Decoded: $($rawBytes.Length) B, Expected: $expectedTotalBytes B." -ForegroundColor Red
                $errors++
            }
        } catch {
            Write-Host "  [ERROR] Invalid Base64 string in <CellsData>: $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }

    if ($null -ne $tbl.Rows -and $null -ne $tbl.Rows.Row) {
        $xmlRows = @($tbl.Rows.Row)
        if ($xmlRows.Count -ne $numRows) {
            Write-Host "  [WARNING] <Rows> count ($($xmlRows.Count)) differs from <NumOfRows> ($numRows)." -ForegroundColor Yellow
            $warnings++
        } else {
            Write-Host "  [OK] <Rows> XML element count matches NumOfRows ($numRows)." -ForegroundColor Green
        }
    }
}

Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Gray
if ($errors -eq 0) {
    Write-Host "[SUCCESS] All Data Tables in '$XmlPath' passed verification ($warnings warnings)." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILED] Verification found $errors error(s) and $warnings warning(s)." -ForegroundColor Red
    exit 1
}
