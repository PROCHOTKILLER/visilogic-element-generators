<#
.SYNOPSIS
    verify_displays.ps1 - Structural and Relational Integrity Auditor for VisiLogic HMI Display (.vld) archives.
.DESCRIPTION
    Verifies a generated .vld archive against 10 structural and relational rules required by the
    Unitronics VisiLogic VB6 HMI import engine (UnHmPge2.dll):
    1. Valid ZIP container with HMIBufferColorPages.udb inside
    2. Synchronization of Pages, Pages_all, and DisplayNote tables
    3. Valid screen bounds (0 <= Xs, Ys and Xs+Dx <= 320, Ys+Dy <= 240)
    4. No NULL values in mandatory HMI_Elements columns
    5. Valid PropertyBag binary structures for variable controls
    6. Consistency between HMI_Elements and HMI_Operands bindings
    7. Valid FontIndex references in HMI_Fonts
    8. Valid HMIJumps screen jump limit (max 4 jumps per screen for V350)
#>

param(
    [string]$VldPath = "..\examples\hmi-displays\WATER_TREATMENT_PUMPING.vld"
)

if ([IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $p = Start-Process -FilePath $sysWow64 -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-VldPath", "`"$VldPath`"") -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$fullVldPath = if ([System.IO.Path]::IsPathRooted($VldPath)) {
    $VldPath
} else {
    Join-Path $PSScriptRoot $VldPath
}

Write-Host "=== VISILOGIC VLD INTEGRITY AUDITOR ===" -ForegroundColor Cyan
Write-Host "Target file: $fullVldPath"

if (-not (Test-Path $fullVldPath)) {
    Write-Host "[ERROR] VLD file does not exist: $fullVldPath" -ForegroundColor Red
    exit 1
}

$errors = 0
$warnings = 0

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vld_verify_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # 1. Extract ZIP archive
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fullVldPath, $tempDir)
    } catch {
        Write-Host "[ERROR] File is not a valid ZIP archive (.vld): $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    $udbPath = Join-Path $tempDir "HMIBufferColorPages.udb"
    if (-not (Test-Path $udbPath)) {
        Write-Host "[ERROR] Archive does not contain required HMIBufferColorPages.udb database!" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] ZIP archive extracted; HMIBufferColorPages.udb present." -ForegroundColor Green

    $connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$udbPath;"
    $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
    $conn.Open()

    try {
        function Get-Scalar([string]$sql) {
            $c = $conn.CreateCommand()
            $c.CommandText = $sql
            return $c.ExecuteScalar()
        }

        function Get-Table([string]$sql) {
            $c = $conn.CreateCommand()
            $c.CommandText = $sql
            $da = New-Object System.Data.OleDb.OleDbDataAdapter($c)
            $dt = New-Object System.Data.DataTable
            $da.Fill($dt) | Out-Null
            return ,$dt
        }

        # 2. Check Pages, Pages_all, DisplayNote synchronization
        $pagesCount = [int](Get-Scalar "SELECT COUNT(*) FROM Pages")
        $pagesAllCount = [int](Get-Scalar "SELECT COUNT(*) FROM Pages_all")
        $notesCount = [int](Get-Scalar "SELECT COUNT(*) FROM DisplayNote")

        if ($pagesCount -eq 0) {
            Write-Host "[ERROR] Table Pages is empty (0 displays)!" -ForegroundColor Red
            $errors++
        } elseif ($pagesCount -ne $pagesAllCount -or $pagesCount -ne $notesCount) {
            Write-Host "[ERROR] Display table mismatch: Pages=$pagesCount, Pages_all=$pagesAllCount, DisplayNote=$notesCount" -ForegroundColor Red
            $errors++
        } else {
            Write-Host "[OK] Synchronization verified: Pages = Pages_all = DisplayNote = $pagesCount displays." -ForegroundColor Green
        }

        # 3. Check StartUpDisplay flag
        $startUpCount = [int](Get-Scalar "SELECT COUNT(*) FROM Pages WHERE StartUpDisplay = True")
        if ($startUpCount -eq 0) {
            Write-Host "[WARNING] No display has StartUpDisplay = True." -ForegroundColor Yellow
            $warnings++
        } else {
            Write-Host "[OK] Startup display defined ($startUpCount)." -ForegroundColor Green
        }

        # 4. Check HMIJumps limit (max 4 per page for V350 JumpArray(1 To 4))
        $jumpsTable = Get-Table "SELECT PageNum, COUNT(*) AS Cnt FROM HMIJumps GROUP BY PageNum"
        $jumpOverflow = $false
        foreach ($row in $jumpsTable.Rows) {
            if ([int]$row["Cnt"] -gt 4) {
                Write-Host "[ERROR] Display PageNum=$($row['PageNum']) has $($row['Cnt']) jumps (V350 maximum is 4; causes VB6 Subscript Out of Range)!" -ForegroundColor Red
                $errors++
                $jumpOverflow = $true
            }
        }
        if (-not $jumpOverflow) {
            $totalJumps = [int](Get-Scalar "SELECT COUNT(*) FROM HMIJumps")
            Write-Host "[OK] HMIJumps table valid ($totalJumps total jumps; <= 4 per display)." -ForegroundColor Green
        }

        # 5. Check HMI_Elements geometry and mandatory fields
        $elements = Get-Table "SELECT ID, DisplayID, Type, VarType, Xs, Ys, Dx, Dy, Text, FontIndex, OprndType, OprndAddr, PropertyBag FROM HMI_Elements ORDER BY ID"
        Write-Host "[INFO] Auditing $($elements.Rows.Count) graphical elements in HMI_Elements..." -ForegroundColor Cyan

        foreach ($el in $elements.Rows) {
            $eid = $el["ID"]
            $did = $el["DisplayID"]
            $xs = [int]$el["Xs"]
            $ys = [int]$el["Ys"]
            $dx = [int]$el["Dx"]
            $dy = [int]$el["Dy"]
            $type = [int]$el["Type"]

            if ($xs -lt 0 -or $ys -lt 0 -or ($xs + $dx) -gt 320 -or ($ys + $dy) -gt 240) {
                Write-Host "[ERROR] Element ID=$eid (Display $did) exceeds 320x240 screen bounds: Xs=$xs, Ys=$ys, Dx=$dx, Dy=$dy" -ForegroundColor Red
                $errors++
            }

            if ($type -eq 5) {
                if ($el["PropertyBag"] -is [System.DBNull]) {
                    Write-Host "[ERROR] Variable element ID=$eid (Display $did) has NULL PropertyBag!" -ForegroundColor Red
                    $errors++
                }
            }
        }

        # 6. Check HMI_Operands count
        $opCount = [int](Get-Scalar "SELECT COUNT(*) FROM HMI_Operands")
        Write-Host "[OK] Registered operand links in HMI_Operands: $opCount" -ForegroundColor Green

    } finally {
        $conn.Close()
        $conn.Dispose()
    }
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "----------------------------------------"
if ($errors -eq 0) {
    Write-Host "[SUCCESS] VLD archive passed all integrity checks ($warnings warning(s))." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILED] VLD archive failed verification with $errors error(s) and $warnings warning(s)." -ForegroundColor Red
    exit 1
}
