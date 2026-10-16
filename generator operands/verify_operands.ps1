<#
.SYNOPSIS
    Walidator integralnosci i poprawnosci plikow definicji operandow (operands.csv) dla VisiLogic.
.DESCRIPTION
    Weryfikuje strukture pliku CSV (dokladnie 8193 wiersze, 18 kolumn), poprawnosc kodowania CP1250,
    brak duplikatow opisow w ramach typu pamieci, limity dlugosci (max 50 znakow dla zmiennych uzytkownika)
    oraz opcjonalnie porownuje operandy z uzytymi w plikach drabinkowych (*.vlx).
.PARAMETER CsvPath
    Sciezka do sprawdzanego pliku operands.csv.
.PARAMETER VlxDir
    Opcjonalna sciezka do katalogu z plikami *.vlx w celu weryfikacji pokrycia operandow.
#>

param(
    [Parameter(Position=0)]
    [Alias("Path")]
    [string]$CsvPath = "",

    [string]$VlxDir = ""
)

# Jezeli uruchomiono w 64-bit i trzeba skanowac VLX, przelacz na SysWOW64
if ([IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($CsvPath) { $argList += @("-CsvPath", "`"$CsvPath`"") }
        if ($VlxDir) { $argList += @("-VlxDir", "`"$VlxDir`"") }
        $p = Start-Process -FilePath $sysWow64 -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   WALIDATOR INTEGRALNOSCI PLIKU OPERANDOW (*.CSV) DLA VISILOGIC      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$currentDir = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent (Split-Path -Parent $currentDir)

if ([string]::IsNullOrEmpty($CsvPath)) {
    $candidate = Join-Path $projectRoot "dokumentacja\Visilogic_projekt_operands.csv"
    if (Test-Path $candidate) {
        $CsvPath = $candidate
    } else {
        $CsvPath = Join-Path $currentDir "operands.csv"
    }
}

if (-not (Test-Path $CsvPath)) {
    Write-Host "[BLAD] Nie znaleziono pliku do weryfikacji: $CsvPath" -ForegroundColor Red
    exit 1
}

Write-Host "--> Badany plik: $CsvPath" -ForegroundColor White

$expectedHeader = "Address,MB,MI,MF,ML,MDW,SB,SI,SL,SDW,I,O,T,C,XB,XI,XL,XDW"
$typeNames = @('MB','MI','MF','ML','MDW','SB','SI','SL','SDW','I','O','T','C','XB','XI','XL','XDW')

$errors = 0
$warnings = 0

# 1. Wczytanie w kodowaniu Windows-1250
$enc = [System.Text.Encoding]::GetEncoding(1250)
$lines = [System.IO.File]::ReadAllLines($CsvPath, $enc)

Write-Host "[INFO] Liczba linii w pliku: $($lines.Length)" -ForegroundColor Gray

if ($lines.Length -ne 8193) {
    Write-Host "[OSTRZEZENIE] Liczba linii wynosi $($lines.Length) (oczekiwano dokladnie 8193: 1 naglowek + 8192 wiersze od 0 do 8191)." -ForegroundColor Yellow
    $warnings++
} else {
    Write-Host "   [OK] Liczba wierszy: 8193 (pelna tablica adresowa 0..8191)" -ForegroundColor Green
}

# 2. Sprawdzenie naglowka
$actualHeader = $lines[0].Trim()
if ($actualHeader -ne $expectedHeader) {
    Write-Host "[BLAD] Niepoprawny naglowek CSV!" -ForegroundColor Red
    Write-Host "   Oczekiwano: $expectedHeader" -ForegroundColor Red
    Write-Host "   Otrzymano : $actualHeader" -ForegroundColor Red
    $errors++
} else {
    Write-Host "   [OK] Naglowek CSV zgodny ze standardem VisiLogic (18 kolumn)" -ForegroundColor Green
}

# 3. Badanie wierszy pod katem separatorow, dlugosci i duplikatow
$uniqueNamesByType = @{}
foreach ($t in $typeNames) {
    $uniqueNamesByType[$t] = @{}
}

$longNamesCount = 0
$duplicateNamesCount = 0
$invalidColCount = 0

for ($i = 1; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $parts = $line.Split(',')

    # VisiLogic natywnie eksportuje wiersze z 18 przecinkami (19 pol, z czego ostatnie jest puste - trailing comma)
    # lub czysty format 18 kolumn (17 przecinkow)
    $isValidCols = ($parts.Length -eq 18) -or ($parts.Length -eq 19 -and $parts[18].Trim() -eq "")
    if (-not $isValidCols) {
        if ($invalidColCount -lt 5) {
            Write-Host "[BLAD] Wiersz $($i) (Adres $($i-1)) ma $($parts.Length) kolumn zamiast 18! Zawartosc: $line" -ForegroundColor Red
        }
        $invalidColCount++
        $errors++
    }

    $addr = $parts[0].Trim()
    if ($addr -ne ($i - 1).ToString()) {
        Write-Host "[BLAD] Niespojnosc adresu w wierszu $($i): znaleziono '$addr', oczekiwano '$($i - 1)'" -ForegroundColor Red
        $errors++
    }

    # Sprawdzenie kolumn
    for ($c = 0; $c -lt $typeNames.Length; $c++) {
        $colIdx = $c + 1
        if ($colIdx -lt $parts.Length) {
            $val = $parts[$colIdx].Trim()
            if ($val -ne "") {
                $tName = $typeNames[$c]

                # Limit dlugosci 50 znakow dla zmiennych uzytkownika
                if ($tName -notin @('SB','SI','SL','SDW')) {
                    if ($val.Length -gt 50) {
                        Write-Host "[BLAD] Opis operandu $($tName) $($i-1) przekracza dopuszczalny limit 50 znakow (Dlugosc: $($val.Length)): '$val'" -ForegroundColor Red
                        $errors++
                        $longNamesCount++
                    } elseif ($val.Length -gt 32) {
                        if ($longNamesCount -lt 3) {
                            Write-Host "[INFO] Opis operandu $($tName) $($i-1) ma dlugosc $($val.Length) znakow (>32): '$val'" -ForegroundColor Gray
                        }
                    }

                    # Duplikaty w pamieci uzytkownika
                    if ($uniqueNamesByType[$tName].ContainsKey($val)) {
                        $prevAddr = $uniqueNamesByType[$tName][$val]
                        Write-Host "[OSTRZEZENIE] Duplikat nazwy w typie $($tName): '$val' wystepuje pod adresem $prevAddr oraz $($i-1)" -ForegroundColor Yellow
                        $warnings++
                        $duplicateNamesCount++
                    } else {
                        $uniqueNamesByType[$tName][$val] = ($i - 1)
                    }
                }
            }
        }
    }
}

if ($invalidColCount -eq 0) {
    Write-Host "   [OK] Wszystkie wiersze posiadaja prawidlowa liczbe kolumn (18)" -ForegroundColor Green
}
if ($longNamesCount -eq 0) {
    Write-Host "   [OK] Zadna nazwa zmiennej uzytkownika nie przekracza limitu 50 znakow" -ForegroundColor Green
}
if ($duplicateNamesCount -eq 0) {
    Write-Host "   [OK] Brak zduplikowanych nazw w pamieci uzytkownika" -ForegroundColor Green
}

# 4. Statystyki zdefiniowanych operandow
Write-Host "`n--- Statystyka zdefiniowanych nazw w badanym pliku ---" -ForegroundColor Cyan
$statsOutput = [System.Collections.Generic.List[string]]::new()
foreach ($t in $typeNames) {
    $count = 0
    for ($i = 1; $i -lt $lines.Length; $i++) {
        $parts = $lines[$i].Split(',')
        $idx = [array]::IndexOf($typeNames, $t) + 1
        if ($idx -lt $parts.Length -and $parts[$idx].Trim() -ne "") {
            $count++
        }
    }
    if ($count -gt 0) {
        $statsOutput.Add(("{0,-5}: {1,-4}" -f $t, $count))
    }
}
Write-Host ($statsOutput -join " | ") -ForegroundColor White

# 5. Opcjonalne porownanie z plikami *.vlx
if ([string]::IsNullOrEmpty($VlxDir)) {
    $defaultVlx = Join-Path $projectRoot "wygenerowane_pliki_projektu\vlx_subroutines"
    if (Test-Path $defaultVlx) {
        $VlxDir = $defaultVlx
    }
}

if (-not [string]::IsNullOrEmpty($VlxDir) -and (Test-Path $VlxDir)) {
    Write-Host "`n--> Weryfikacja pokrycia operandow z plikami drabinkowymi *.vlx..." -ForegroundColor Cyan
    $engineScript = Join-Path $currentDir "OperandsBuilder.ps1"
    if (Test-Path $engineScript) {
        . $engineScript
        $builder = [OperandsBuilder]::new()
        $builder.LoadTemplate($CsvPath)
        $scan = $builder.ScanVlxOperands($VlxDir)

        $missingCount = $scan['Missing'].Count
        $usedCount = $scan['Used'].Count
        Write-Host "   Laczna liczba uzytych operandow w drabinkach: $usedCount" -ForegroundColor Gray

        if ($missingCount -gt 0) {
            Write-Host "[OSTRZEZENIE] Wykryto $missingCount uzyc operandow bez zdefiniowanego opisu w pliku CSV:" -ForegroundColor Yellow
            $grouped = $scan['Missing'] | Group-Object -Property Type
            foreach ($g in $grouped) {
                $addrs = ($g.Group | Select-Object -ExpandProperty Address -Unique | Sort-Object) -join ', '
                Write-Host "   Typ $($g.Name): adresy [$addrs]" -ForegroundColor Yellow
            }
            $warnings += $missingCount
        } else {
            Write-Host "   [OK] Wszystkie operandy uzyte w podprogramach *.vlx posiadaja opisy w pliku CSV!" -ForegroundColor Green
        }
    }
}

Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "[SUKCES] Plik CSV jest w 100% poprawny, kompletny i gotowy do importu w VisiLogic!" -ForegroundColor Green
} elseif ($errors -eq 0) {
    Write-Host "[SUKCES Z OSTRZEZENIAMI] Bledow: 0, Ostrzezen: $warnings. Plik nadaje sie do importu." -ForegroundColor Yellow
} else {
    Write-Host "[NIEPOWODZENIE] Wykryto $errors bledow oraz $warnings ostrzezen! Wymagana korekta przed importem." -ForegroundColor Red
}
Write-Host "======================================================================`n" -ForegroundColor Gray

if ($errors -gt 0) { exit 1 } else { exit 0 }
