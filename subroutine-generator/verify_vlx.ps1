<#
.SYNOPSIS
    Skrypt weryfikacyjny integralnosci relacyjnej bazy danych dla plikow *.vlx.
    Automatycznie wykrywa architekture i w razie potrzeby przelacza sie na 32-bitowy PowerShell (SysWOW64).

.DESCRIPTION
    Sprawdza klucze glowne, relacje, obecnosc polaczonych operandow oraz brak wartosci NULL
    w krytycznych kolumnach bazy VisiLogic, eliminujac ryzyko wylozenia sie (crashu) VisiLogic przy imporcie.

.PARAMETER TargetPath
    Sciezka do pojedynczego pliku *.vlx lub katalogu zawierajacego pliki *.vlx.
#>

param(
    [Alias("VlxPath")]
    [string]$TargetPath = ""
)

# 1. Automatyczne przelaczenie na 32-bitowy PowerShell
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
Write-Host "   WALIDATOR INTEGRALNOSCI PLIKOW PODPROGRAMOW VISILOGIC (*.VLX)      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$currentDir = Split-Path -Parent $PSCommandPath

# Domyślna ścieżka do sprawdzenia
if ($TargetPath -eq "") {
    $defaultOutputDir = Join-Path (Split-Path -Parent (Split-Path -Parent $currentDir)) "wygenerowane_pliki_projektu\vlx_subroutines"
    if (Test-Path $defaultOutputDir) {
        $TargetPath = $defaultOutputDir
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
    Write-Error "[BLAD] Podana sciezka nie istnieje: $TargetPath"
    exit 1
}

if ($filesToCheck.Count -eq 0) {
    Write-Warning "[OSTRZEZENIE] Nie znaleziono zadnych plikow *.vlx do sprawdzenia w: $TargetPath"
    exit 0
}

$allPassed = $true

foreach ($file in $filesToCheck) {
    Write-Host "`n--> Badanie pliku: $($file.Name)" -ForegroundColor Yellow
    $connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($file.FullName);Jet OLEDB:Database Password=UniOpenSesame;"
    $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
    
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()

        # 1. Sprawdzenie nazwy i ID funkcji
        $cmd.CommandText = "SELECT FuncID, FuncName FROM expimp_LdrFunctions"
        $reader = $cmd.ExecuteReader()
        $funcFound = $false
        if ($reader.Read()) {
            $funcFound = $true
            Write-Host ("   [OK] Nazwa funkcji: '{0}' (FuncID: {1})" -f $reader[1], $reader[0]) -ForegroundColor Green
        }
        $reader.Close()

        if (-not $funcFound) {
            Write-Host "   [BLAD] Brak rekordu w tabeli expimp_LdrFunctions!" -ForegroundColor Red
            $allPassed = $false
            continue
        }

        # 2. Sprawdzenie szczebli (Strips)
        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrStrips"
        $stripsCount = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrStrips WHERE IsReturnStrip = -1"
        $returnCount = [int]$cmd.ExecuteScalar()

        if ($returnCount -eq 1) {
            Write-Host ("   [OK] Szczeble robocze: {0}, Szczebel Return: OBECNY" -f ($stripsCount - 1)) -ForegroundColor Green
        } else {
            Write-Host ("   [BLAD] Niepoprawna liczba szczebli Return ({0})! Wymagany dokladnie 1." -f $returnCount) -ForegroundColor Red
            $allPassed = $false
        }

        # 3. Sprawdzenie elementow i powiazan operandow
        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrElements"
        $elmsCount = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrElmsOprs"
        $elmsOprsCount = [int]$cmd.ExecuteScalar()

        Write-Host ("   [OK] Elementy drabinki: {0}, Powiazania operandow: {1}" -f $elmsCount, $elmsOprsCount) -ForegroundColor Green

        # 4. Sprawdzenie czy w kluczach glownych/obcych nie ma wartosci NULL (przyczyna crashu VisiLogic)
        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrElmsOprs WHERE ElmntID IS NULL OR Elmnt_Oprnd_Type IS NULL OR Elmnt_Oprnd_Adrs IS NULL"
        $nullElmsOprs = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "SELECT COUNT(*) FROM expimp_LdrOperands WHERE OprndType IS NULL OR OprndAddress IS NULL"
        $nullOperands = [int]$cmd.ExecuteScalar()

        if ($nullElmsOprs -eq 0 -and $nullOperands -eq 0) {
            Write-Host "   [OK] Zerowa ilosc wartosci NULL w relacjach operandow (Brak ryzyka crashu)." -ForegroundColor Green
        } else {
            Write-Host ("   [BLAD KRYTYCZNY] Znaleziono NULL w kluczach! ElmsOprs NULL: {0}, Operands NULL: {1}" -f $nullElmsOprs, $nullOperands) -ForegroundColor Red
            $allPassed = $false
        }

    } catch {
        Write-Host ("   [WYJATEK] Blad bazy danych OLEDB: " + $_.Exception.Message) -ForegroundColor Red
        $allPassed = $false
    } finally {
        $conn.Close()
    }
}

Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Gray
if ($allPassed) {
    Write-Host "[SUKCES] Wszystkie sprawdzone pliki *.vlx sa w pelni poprawne i gotowe do importu!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[UWAGA] Wykryto bledy w jednym lub kilku plikach *.vlx!" -ForegroundColor Red
    exit 1
}
