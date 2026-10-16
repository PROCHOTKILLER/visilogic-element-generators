<#
.SYNOPSIS
    Glowny interfejs CLI generatora plikow operands.csv dla Unitronics VisiLogic (AIO).
.DESCRIPTION
    Umozliwia elastyczne generowanie, scalanie, wzbogacanie o mape I/O oraz automatyczne
    dopasowywanie nazw dla operandow wykrytych w logice drabinkowej (*.vlx).
.PARAMETER OutputPath
    Sciezka do wygenerowanego pliku *.csv (domyslnie: operands.csv).
.PARAMETER TemplatePath
    Sciezka do czystego szablonu bazy operandow (domyslnie: templates\template_operands.csv).
.PARAMETER InputCsv
    Opcjonalny istniejacy plik *.csv, z ktorego nalezy zaimportowac/scalic opisy.
.PARAMETER IoCsv
    Opcjonalny plik mapy I/O (np. MAPA_IO_PELNA.csv).
.PARAMETER VlxDir
    Opcjonalny katalog plikow *.vlx do przeskanowania i weryfikacji pokrycia.
.PARAMETER AutoNameMissing
    Przelacznik: czy automatycznie nadac nazwy operandom uzytym w drabinkach *.vlx, ktore nie maja opisu.
.PARAMETER Encoding
    Kodowanie wyjsciowe (domyslnie: Windows-1250).
#>

[CmdletBinding()]
param(
    [Alias("Out")]
    [string]$OutputPath = "operands.csv",

    [string]$TemplatePath = "",

    [string]$InputCsv = "",

    [string]$IoCsv = "",

    [string]$VlxDir = "",

    [switch]$AutoNameMissing,

    [string]$Encoding = "Windows-1250"
)

# Jezeli podano VlxDir i uruchomiono w 64-bit, przelacz na SysWOW64 (wymagane dla Jet OLEDB)
if ($VlxDir -and [IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($OutputPath) { $argList += @("-OutputPath", "`"$OutputPath`"") }
        if ($TemplatePath) { $argList += @("-TemplatePath", "`"$TemplatePath`"") }
        if ($InputCsv) { $argList += @("-InputCsv", "`"$InputCsv`"") }
        if ($IoCsv) { $argList += @("-IoCsv", "`"$IoCsv`"") }
        if ($VlxDir) { $argList += @("-VlxDir", "`"$VlxDir`"") }
        if ($AutoNameMissing) { $argList += @("-AutoNameMissing") }
        if ($Encoding) { $argList += @("-Encoding", "`"$Encoding`"") }
        $p = Start-Process -FilePath $sysWow64 -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$currentDir = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent (Split-Path -Parent $currentDir)

# Ustal domyslny szablon
if ([string]::IsNullOrEmpty($TemplatePath)) {
    $defaultTpl = Join-Path $currentDir "templates\template_operands.csv"
    if (Test-Path $defaultTpl) {
        $TemplatePath = $defaultTpl
    } else {
        $legacyTpl = Join-Path $projectRoot "dokumentacja\Visilogic_projekt_operands.csv"
        $TemplatePath = $legacyTpl
    }
}

# Dolaczenie silnika OperandsBuilder
$enginePath = Join-Path $currentDir "OperandsBuilder.ps1"
if (-not (Test-Path $enginePath)) {
    Write-Error "Nie znaleziono silnika: $enginePath"
    exit 1
}
. $enginePath

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     GENERATOR OPERANDS.CSV DLA UNITRONICS VISILOGIC (AIO)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$builder = [OperandsBuilder]::new()

# 1. Wczytanie szablonu bazowego
Write-Host "[1/5] Ladowanie szablonu bazowego: $TemplatePath" -ForegroundColor White
$builder.LoadTemplate($TemplatePath)

# 2. Scalanie z istniejacym plikiem CSV (jesli podano)
if (-not [string]::IsNullOrEmpty($InputCsv)) {
    if (Test-Path $InputCsv) {
        Write-Host "[2/5] Scalanie opisow z pliku: $InputCsv" -ForegroundColor White
        $builder.MergeExistingCsv($InputCsv)
    } else {
        Write-Warning "Plik wejsciowy CSV nie istnieje: $InputCsv"
    }
} else {
    Write-Host "[2/5] Brak dodatkowego pliku wejsciowego CSV (pomijanie)." -ForegroundColor Gray
}

# 3. Import z tabeli I/O (np. MAPA_IO_PELNA.csv)
if (-not [string]::IsNullOrEmpty($IoCsv)) {
    if (Test-Path $IoCsv) {
        Write-Host "[3/5] Importowanie sygnalow z mapy I/O: $IoCsv" -ForegroundColor White
        $importedCount = $builder.ImportIoList($IoCsv)
        Write-Host "      Zaimportowano $importedCount sygnalow z mapy I/O." -ForegroundColor Green
    } else {
        Write-Warning "Plik mapy I/O nie istnieje: $IoCsv"
    }
} else {
    Write-Host "[3/5] Brak sciezki do mapy I/O (pomijanie)." -ForegroundColor Gray
}

# 4. Skanowanie plikow VLX i ewentualne uzupelnianie brakujacych operandow
if (-not [string]::IsNullOrEmpty($VlxDir) -and (Test-Path $VlxDir)) {
    Write-Host "[4/5] Skanowanie podprogramow *.vlx w katalogu: $VlxDir" -ForegroundColor White
    $scan = $builder.ScanVlxOperands($VlxDir)
    $missingCount = $scan['Missing'].Count
    $usedCount = $scan['Used'].Count
    Write-Host "      Liczba uzytych operandow w drabinkach: $usedCount" -ForegroundColor White

    if ($missingCount -gt 0) {
        Write-Host "      Znaleziono $missingCount operandow uzytych w kodzie bez opisu w CSV." -ForegroundColor Yellow
        if ($AutoNameMissing) {
            Write-Host "      [AUTO] Generowanie automatycznych nazw dla brakujacych operandow..." -ForegroundColor Cyan
            foreach ($item in $scan['Missing']) {
                $cur = $builder.GetOperand($item.Type, $item.Address)
                if ([string]::IsNullOrEmpty($cur)) {
                    $autoName = "Var_$($item.Type)_$($item.Address)"
                    $builder.SetOperand($item.Type, $item.Address, $autoName)
                }
            }
            Write-Host "      [OK] Nadano etykiety dla wszystkich brakujacych zmiennych." -ForegroundColor Green
        } else {
            Write-Host "      [WSKAZOWKA] Uzyj przelacznika -AutoNameMissing, aby automatycznie uzupelnic ich nazwy." -ForegroundColor Gray
        }
    } else {
        Write-Host "      [OK] Wszystkie operandy z drabinki posiadaja zdefiniowane nazwy." -ForegroundColor Green
    }
} else {
    Write-Host "[4/5] Skanowanie podprogramow *.vlx pominiete (brak katalogu)." -ForegroundColor Gray
}

# 5. Zapis do pliku wynikowego
Write-Host "[5/5] Zapisywanie pliku wynikowego: $OutputPath (Kodowanie: $Encoding)..." -ForegroundColor White
$builder.SaveToCsv($OutputPath, $Encoding)
Write-Host "      [OK] Plik zostal pomyslnie zapisany!" -ForegroundColor Green

# Podsumowanie statystyk
Write-Host "`n--- Podsumowanie wygenerowanych operandow ---" -ForegroundColor Cyan
$stats = $builder.GetStats()
$statsItems = [System.Collections.Generic.List[string]]::new()
foreach ($k in $builder.TypeNames) {
    if ($stats[$k] -gt 0) {
        $statsItems.Add(("{0}: {1}" -f $k, $stats[$k]))
    }
}
Write-Host ($statsItems -join " | ") -ForegroundColor White

# Automatyczna walidacja wygenerowanego pliku
$verifierPath = Join-Path $currentDir "verify_operands.ps1"
if (Test-Path $verifierPath) {
    Write-Host "`n--> Uruchamianie automatycznej walidacji wygenerowanego pliku..." -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verifierPath -CsvPath $OutputPath
}

Write-Host "======================================================================`n" -ForegroundColor Gray
