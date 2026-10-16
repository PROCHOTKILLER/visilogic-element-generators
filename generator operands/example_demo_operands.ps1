<#
.SYNOPSIS
    Przykladowy skrypt demonstracyjny definiowania operandow za pomoca silnika OperandsBuilder.
.DESCRIPTION
    Pokazuje, w jaki sposob inzynier lub agent AI moze w kilku linijkach zdefiniowac
    kompletny zestaw zmiennych PLC i wygenerowac gotowy do importu plik operands.csv.
#>

$currentDir = Split-Path -Parent $PSCommandPath
. (Join-Path $currentDir "OperandsBuilder.ps1")

$outputPath = Join-Path $currentDir "DEMO_OPERANDS.csv"
$templatePath = Join-Path $currentDir "templates\template_operands.csv"

Write-Host "Generowanie przykladowego pliku operandow: $outputPath" -ForegroundColor Cyan

$builder = [OperandsBuilder]::new()
$builder.LoadTemplate($templatePath)

# 1. Definiowanie bitow pamieci (MB)
$builder.SetOperand('MB', 0, "System_Gotowy")
$builder.SetOperand('MB', 1, "Cykl_Aktywny")
$builder.SetOperand('MB', 2, "Cykl_Wstrzymany")
$builder.SetOperand('MB', 3, "Koniec_Suszenia")
$builder.SetOperand('MB', 10, "Zezwolenie_Grzania")
$builder.SetOperand('MB', 20, "HMI_Start_Przycisk")
$builder.SetOperand('MB', 21, "HMI_Stop_Przycisk")

# 2. Definiowanie rejestrow 16-bitowych (MI)
$builder.SetOperand('MI', 0, "Aktualna_Temperatura_01C")
$builder.SetOperand('MI', 1, "Aktualna_Wilgotnosc_01RH")
$builder.SetOperand('MI', 2, "Zadana_Temperatura_01C")
$builder.SetOperand('MI', 3, "Zadana_Wilgotnosc_01RH")
$builder.SetOperand('MI', 10, "Krok_Sekwencji_Nr")
$builder.SetOperand('MI', 11, "Predkosc_Falownika_Hz")

# 3. Definiowanie rejestrow 32-bitowych (ML) i podwojnych slow (MDW)
$builder.SetOperand('ML', 0, "Czas_Calkowity_Cyklu_s")
$builder.SetOperand('ML', 1, "Czas_Pozostaly_Kroku_s")
$builder.SetOperand('MDW', 0, "Licznik_Energii_Wh")

# 4. Definiowanie wejsc fizycznych (I) i wyjsc fizycznych (O)
$builder.SetOperand('I', 0, "Wylacznik_Went_1_NC")
$builder.SetOperand('I', 1, "Wylacznik_Went_2_NC")
$builder.SetOperand('I', 6, "Przekaznik_Bezpieczenstwa_NO")
$builder.SetOperand('I', 7, "Termostat_STB_NC")
$builder.SetOperand('I', 8, "Przycisk_Pulpit_STOP")
$builder.SetOperand('I', 10, "Przycisk_Pulpit_START")

$builder.SetOperand('O', 0, "Lampka_Praca")
$builder.SetOperand('O', 1, "Lampka_Awaria")
$builder.SetOperand('O', 3, "Stycznik_Went_1_3")
$builder.SetOperand('O', 4, "Stycznik_Went_4_6")
$builder.SetOperand('O', 5, "Zezwolenie_Falowniki_RUN")

# 5. Definiowanie timerow (T)
$builder.SetOperand('T', 0, "TMR_Opznienie_Wentylatorow")
$builder.SetOperand('T', 1, "TMR_Cykl_PWM_Grzania")

# 6. Zapis do pliku
$builder.SaveToCsv($outputPath, "Windows-1250")

Write-Host "[OK] Zapisano plik: $outputPath" -ForegroundColor Green

# Walidacja
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $currentDir "verify_operands.ps1") -CsvPath $outputPath
