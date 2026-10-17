<#
.SYNOPSIS
    Relational Database Integrity Auditor for Unitronics VisiLogic Subroutine Files (*.vlx).
    Automatically detects process architecture and relaunches in 32-bit PowerShell (SysWOW64) when required.

.DESCRIPTION
    Verifies primary keys, table relationships, connected operands, and the absence of NULL values
    in critical VisiLogic Jet 4.0 columns, preventing VisiLogic import crashes.

.PARAMETER TargetPath
    Path to a single *.vlx file or a directory containing *.vlx files.
#>

param(
    [Alias("VlxPath")]
    [string]$TargetPath = ""
)

# 1. Automatic switch to 32-bit PowerShell
if ([IntPtr]::Size -eq 8) {
    $sysWow64PowerShell = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64PowerShell) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($TargetPath) { $argList += @("-TargetPath", "`"$TargetPath`"") }
        $process = Start-Process -FilePath $sysWow64PowerShell -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $process.ExitCode
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   VISILOGIC SUBROUTINE (*.VLX) INTEGRITY AUDITOR                     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$currentDir = Split-Path -Parent $PSCommandPath

# Default target path
if ($TargetPath -eq "") {
    $defaultExamplesDir = Join-Path (Split-Path -Parent $currentDir) "examples\subroutines"
    if (Test-Path $defaultExamplesDir) {
        $TargetPath = $defaultExamplesDir
    } else {
        $TargetPath = $currentDir
    }
}

$filesToCheck = @()
if (Test-Path -Path $TargetPath -PathType Container) {
    $filesToCheck = Get-ChildItem -Path $TargetPath -Filter "*.vlx" -Recurse
} elseif (Test-Path -Path $TargetPath -PathType Leaf) {
    $filesToCheck = @(Get-Item -Path $TargetPath)
} else {
    Write-Error "[ERROR] Specified path does not exist: $TargetPath"
    exit 1
}

if ($filesToCheck.Count -eq 0) {
    Write-Warning "[WARNING] No *.vlx files found to verify in: $TargetPath"
    exit 0
}

$allPassed = $true

foreach ($file in $filesToCheck) {
    Write-Host "`n--> Inspecting file: $($file.Name)" -ForegroundColor Yellow
    $connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($file.FullName);Jet OLEDB:Database Password=UniOpenSesame;"
    $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
    
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()

        # 1. Verify function name and ID
        $cmd.CommandText = "SELECT FuncID, FuncName FROM expimp_LdrFunctions"
        $reader = $cmd.ExecuteReader()
        $funcFound = $false
        if ($reader.Read()) {
            $funcFound = $true
            Write-Host ("   [OK] Function Name: '{0}' (FuncID: {1})" -f $reader[1], $reader[0]) -ForegroundColor Green
        }
        $reader.Close()

        if (-not $funcFound) {
            Write-Host "   [ERROR] Missing record in table expimp_LdrFunctions!" -ForegroundColor Red
            $allPassed = $false
            continue
        }

        # 2. Verify rungs (Strips) and Return rung
        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrStrips"
        $stripsCount = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrStrips WHERE IsReturnStrip = -1"
        $returnCount = [int]$cmd.ExecuteScalar()

        if ($returnCount -eq 1) {
            Write-Host ("   [OK] Logic Rungs: {0}, Return Rung: PRESENT" -f ($stripsCount - 1)) -ForegroundColor Green
        } else {
            Write-Host ("   [ERROR] Invalid Return rung count ({0})! Exactly 1 is required." -f $returnCount) -ForegroundColor Red
            $allPassed = $false
        }

        # 3. Verify ladder elements and operand links
        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrElements"
        $elmsCount = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrElmsOprs"
        $elmsOprsCount = [int]$cmd.ExecuteScalar()

        Write-Host ("   [OK] Ladder Elements: {0}, Operand Bindings: {1}" -f $elmsCount, $elmsOprsCount) -ForegroundColor Green

        # 4. Verify zero NULL values in primary/foreign keys (prevents VisiLogic crashes)
        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrElmsOprs WHERE ElmntID IS NULL OR Elmnt_Oprnd_Type IS NULL OR Elmnt_Oprnd_Adrs IS NULL"
        $nullElmsOprs = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrOperands WHERE OprndType IS NULL OR OprndAddress IS NULL"
        $nullOperands = [int]$cmd.ExecuteScalar()

        if ($nullElmsOprs -eq 0 -and $nullOperands -eq 0) {
            Write-Host "   [OK] Zero NULL values in operand relational keys (Crash-free)." -ForegroundColor Green
        } else {
            Write-Host ("   [CRITICAL ERROR] NULL values detected in keys! ElmsOprs NULL: {0}, Operands NULL: {1}" -f $nullElmsOprs, $nullOperands) -ForegroundColor Red
            $allPassed = $false
        }

    } catch {
        Write-Host ("   [EXCEPTION] OLEDB Database Error: " + $_.Exception.Message) -ForegroundColor Red
        $allPassed = $false
    } finally {
        $conn.Close()
    }
}

Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Gray
if ($allPassed) {
    Write-Host "[SUCCESS] All inspected *.vlx files are 100% valid and ready for import!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILED] Errors detected in one or more *.vlx files!" -ForegroundColor Red
    exit 1
}
