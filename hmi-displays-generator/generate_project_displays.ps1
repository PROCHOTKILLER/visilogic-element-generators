<#
.SYNOPSIS
    Generator kompletnego zestawu ekranów HMI (.vld) dla projektu Komora Suszarnicza nr 9.
.DESCRIPTION
    Skrypt generuje 6 profesjonalnych ekranów HMI w formacie VisiLogic .vld (Unitronics Vision V350-35-RA22):
    1. ! Start-Up Display  - Ekran powitalny i wejście do systemu
    2. 01_EKRAN_GLOWNY     - Główna synoptyka procesu (temperatury T1, T2, T_Śr, wilgotność, faza, czas, START/STOP/PAUZA)
    3. 02_RECEPTURY        - Zadawanie nastaw SP (temperatura, wilgotność, czas) i sterowanie fazami
    4. 03_STEROWANIE_RECZNE- Manualne załączanie napędów: Wentylatory, Palnik, Zraszanie, Klapy, Pompa
    5. 04_ALARMY_STATUS    - Rejestr awarii i diagnostyka z przyciskiem kasowania alarmów
    6. 05_REGULACJA_PID    - Wskaźniki PV/SP/CV, słupkowy bargraph mocy oraz nastawy pętli PID (Kp, Ti, Td)
.OUTPUTS
    KOMORA9_HMI_DISPLAYS.vld w katalogu generatora oraz w katalogu głównym projektu.
#>

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$builderModule = Join-Path $scriptDir "HmiDisplayBuilder.ps1"

if (-not (Test-Path $builderModule)) {
    throw "Nie znaleziono silnika HmiDisplayBuilder.ps1 pod adresem: $builderModule"
}

. $builderModule

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  GENEROWANIE EKRANOW HMI DLA PROJEKTU KOMORA SUSZARNICZA 9" -ForegroundColor Cyan
Write-Host "  Sterownik: Unitronics Vision V350-35-RA22 (320x240)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$builder = [HmiDisplayBuilder]::new()

# ==============================================================================
# EKRAN 1: ! Start-Up Display (Powitalny)
# ==============================================================================
Write-Host "Tworzenie ekranu 1: ! Start-Up Display..." -ForegroundColor White
$d1 = $builder.AddDisplay("! Start-Up Display", $true)
$d1.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek nagłówkowy
$d1.AddRectangle(2, 2, 316, 36, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d1.AddLabel(5, 7, 310, 26, "KOMORA SUSZARNICZA NR 9", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Karta informacyjna
$d1.AddRectangle(8, 46, 304, 110, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d1.AddLabel(15, 52, 290, 22, "SYSTEM STEROWANIA SUSZARNI", [HmiColor]::Navy, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 76, 290, 18, "Sterownik: Unitronics Vision V350", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 96, 290, 18, "Oprogramowanie: v2.4 (Modul AIO)", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 116, 290, 18, "Status: URZADZENIE GOTOWE", [HmiColor]::Green, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 134, 290, 18, "Dotknij ponizszy przycisk, aby rozpoczac", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null

# Główny przycisk wejścia do systemu (MB 10)
$d1.AddButton(15, 166, 290, 64, "[ WEJSCIE DO SYSTEMU ]", 10, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 2: 01_EKRAN_GLOWNY (Główna Synoptyka)
# ==============================================================================
Write-Host "Tworzenie ekranu 2: 01_EKRAN_GLOWNY..." -ForegroundColor White
$d2 = $builder.AddDisplay("01_EKRAN_GLOWNY", $false)
$d2.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek górny
$d2.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d2.AddLabel(5, 4, 310, 20, "KOMORA 9 - SYNOPTYKA PROCESU", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Kolumna Lewa: Odczyty procesowe (T1, T2, T_Śr, RH, Faza, Czas)
$d2.AddRectangle(4, 28, 154, 154, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d2.AddLabel(6, 30, 75, 22, "T1 Gora:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(82, 30, 72, 22, 100, $false, "T1", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d2.AddLabel(6, 55, 75, 22, "T2 Dol:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(82, 55, 72, 22, 101, $false, "T2", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d2.AddLabel(6, 80, 75, 22, "T Srednia:", [HmiColor]::Navy, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(82, 80, 72, 22, 102, $false, "T_Sr", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d2.AddLabel(6, 105, 75, 22, "Wilgotn.:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(82, 105, 72, 22, 104, $false, "RH", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d2.AddLabel(6, 130, 75, 22, "Faza:", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(82, 130, 72, 22, 108, $false, "Faza", $builder.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$d2.AddLabel(6, 155, 75, 22, "Czas [min]:", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(82, 155, 72, 22, 107, $false, "Czas", $builder.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

# Kolumna Prawa: Przyciski procesowe (START, STOP, PAUZA, KASUJ ALARM)
$d2.AddButton(162, 28, 154, 36, "[ START ]", 22, [HmiColor]::White, [HmiColor]::Green) | Out-Null
$d2.AddButton(162, 67, 154, 36, "[ STOP ]", 20, [HmiColor]::White, [HmiColor]::Red) | Out-Null
$d2.AddButton(162, 106, 154, 36, "[ PAUZA ]", 21, [HmiColor]::Black, [HmiColor]::Yellow) | Out-Null
$d2.AddButton(162, 145, 154, 37, "[ KASUJ ALARM ]", 23, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# Dolny pasek nawigacji do podstron
$d2.AddButton(4, 186, 75, 50, "RECEPT.", 11, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$d2.AddButton(83, 186, 75, 50, "RECZNE", 12, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$d2.AddButton(162, 186, 75, 50, "ALARMY", 13, [HmiColor]::White, [HmiColor]::Red) | Out-Null
$d2.AddButton(241, 186, 75, 50, "PID", 14, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 3: 02_RECEPTURY (Zadawanie nastaw SP)
# ==============================================================================
Write-Host "Tworzenie ekranu 3: 02_RECEPTURY..." -ForegroundColor White
$d3 = $builder.AddDisplay("02_RECEPTURY", $false)
$d3.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek górny
$d3.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d3.AddLabel(5, 4, 310, 20, "RECEPTURY I NASTAWY ZADANE", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Panel nastaw z edycją dotykową przez klawiaturę (Keypad = 1)
$d3.AddRectangle(4, 28, 160, 154, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d3.AddLabel(6, 32, 80, 22, "T Zadana SP:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d3.AddNumericVariable(88, 32, 72, 24, 105, $true, "SP_T", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d3.AddLabel(6, 68, 80, 22, "RH Zadana:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d3.AddNumericVariable(88, 68, 72, 24, 106, $true, "SP_RH", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d3.AddLabel(6, 104, 80, 22, "Czas Fazy:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d3.AddNumericVariable(88, 104, 72, 24, 110, $true, "SP_Czas", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d3.AddLabel(6, 140, 80, 22, "Histereza:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d3.AddNumericVariable(88, 140, 72, 24, 111, $true, "Hister", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

# Przyciski sterowania recepturami
$d3.AddButton(168, 28, 148, 46, "NASTEPNA FAZA", 24, [HmiColor]::White, [HmiColor]::Navy) | Out-Null
$d3.AddButton(168, 80, 148, 46, "RECEPTURA +", 25, [HmiColor]::Black, [HmiColor]::Yellow) | Out-Null
$d3.AddButton(168, 132, 148, 48, "ZAPISZ DO TABELI", 26, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

# Przycisk powrotu do ekranu głównego
$d3.AddButton(4, 186, 312, 50, "< POWROT DO SYNOPTYKI", 10, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 4: 03_STEROWANIE_RECZNE (Ręczne załączanie agregatów)
# ==============================================================================
Write-Host "Tworzenie ekranu 4: 03_STEROWANIE_RECZNE..." -ForegroundColor White
$d4 = $builder.AddDisplay("03_STEROWANIE_RECZNE", $false)
$d4.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek górny
$d4.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d4.AddLabel(5, 4, 310, 20, "STEROWANIE RECZNE AGREGATAMI", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Przyciski manualnego załączania napędów (MB 30..35)
$d4.AddButton(6, 30, 150, 46, "WENTYLATOR 1 (O 0)", 30, [HmiColor]::White, [HmiColor]::Navy) | Out-Null
$d4.AddButton(164, 30, 150, 46, "WENTYLATOR 2 (O 1)", 31, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

$d4.AddButton(6, 81, 150, 46, "PALNIK GRZANIE (O 2)", 32, [HmiColor]::White, [HmiColor]::Navy) | Out-Null
$d4.AddButton(164, 81, 150, 46, "ZRASZANIE (O 3)", 33, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

$d4.AddButton(6, 132, 150, 46, "KLAPY WYMIANY (O 4)", 34, [HmiColor]::White, [HmiColor]::Navy) | Out-Null
$d4.AddButton(164, 132, 150, 46, "POMPA OBIEG (O 5)", 35, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# Przycisk powrotu
$d4.AddButton(6, 185, 308, 50, "< POWROT DO SYNOPTYKI", 10, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 5: 04_ALARMY_STATUS (Diagnostyka i Rejestr Awarii)
# ==============================================================================
Write-Host "Tworzenie ekranu 5: 04_ALARMY_STATUS..." -ForegroundColor White
$d5 = $builder.AddDisplay("04_ALARMY_STATUS", $false)
$d5.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek górny ostrzegawczy (czerwony)
$d5.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, [HmiColor]::Red) | Out-Null
$d5.AddLabel(5, 4, 310, 20, "DIAGNOSTYKA I REJESTR ALARMOW", [HmiColor]::White, [HmiColor]::Red, 0) | Out-Null

# Lista kontrolek stanu awaryjnego
$d5.AddRectangle(4, 28, 312, 102, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d5.AddLabel(8, 32, 300, 16, "AL 01: Awaria falownika Wentylatora W1 (MB 40)", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d5.AddLabel(8, 48, 300, 16, "AL 02: Awaria falownika Wentylatora W2 (MB 41)", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d5.AddLabel(8, 64, 300, 16, "AL 03: Awaria palnika gazowego (MB 42)", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d5.AddLabel(8, 80, 300, 16, "AL 04: Przegrzanie komory STB > 95C (MB 43)", [HmiColor]::Red, [HmiColor]::White, 0) | Out-Null
$d5.AddLabel(8, 96, 300, 16, "AL 05: Awaria czujnikow PT100 (MB 44)", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d5.AddLabel(8, 112, 300, 16, "AL 06: Brak cisnienia wody zraszania (MB 45)", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null

# Przycisk kasowania alarmów
$d5.AddButton(4, 134, 312, 45, "[ KASOWANIE WSZYSTKICH ALARMOW ]", 23, [HmiColor]::White, [HmiColor]::Red) | Out-Null

# Przycisk powrotu
$d5.AddButton(4, 185, 312, 50, "< POWROT DO SYNOPTYKI", 10, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 6: 05_REGULACJA_PID (Parametry Pętli PID Palnika)
# ==============================================================================
Write-Host "Tworzenie ekranu 6: 05_REGULACJA_PID..." -ForegroundColor White
$d6 = $builder.AddDisplay("05_REGULACJA_PID", $false)
$d6.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek górny
$d6.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d6.AddLabel(5, 4, 310, 20, "REGULATOR PID TEMPERATURY (PALNIK)", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Lewa kolumna: PV, SP, CV, Bargraph
$d6.AddRectangle(4, 28, 154, 154, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d6.AddLabel(6, 32, 70, 22, "PV Temp:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d6.AddNumericVariable(78, 32, 76, 22, 102, $false, "PV", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d6.AddLabel(6, 60, 70, 22, "SP Temp:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d6.AddNumericVariable(78, 60, 76, 22, 105, $false, "SP", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d6.AddLabel(6, 88, 70, 22, "CV Wyjscie:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d6.AddNumericVariable(78, 88, 76, 22, 109, $false, "CV", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d6.AddLabel(6, 116, 146, 18, "Wysterowanie palnika:", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null
$d6.AddBargraph(10, 138, 140, 36, 109, "BAR_CV", $builder.BargraphPropertyBag) | Out-Null

# Prawa kolumna: Nastawy Kp, Ti, Td z keypadem
$d6.AddRectangle(162, 28, 154, 154, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d6.AddLabel(166, 32, 146, 20, "Parametry PID:", [HmiColor]::Navy, [HmiColor]::White, 0) | Out-Null

$d6.AddLabel(166, 58, 65, 22, "Kp:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d6.AddNumericVariable(234, 58, 76, 24, 120, $true, "Kp", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d6.AddLabel(166, 92, 65, 22, "Ti [s]:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d6.AddNumericVariable(234, 92, 76, 24, 121, $true, "Ti", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

$d6.AddLabel(166, 126, 65, 22, "Td [s]:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d6.AddNumericVariable(234, 126, 76, 24, 122, $true, "Td", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

# Przycisk powrotu
$d6.AddButton(4, 186, 312, 50, "< POWROT DO SYNOPTYKI", 10, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# Zapis pliku wynikowego
# ==============================================================================
Write-Host "`nZapisywanie archiwum .vld..." -ForegroundColor Cyan
$outVldLocal = Join-Path $scriptDir "KOMORA9_HMI_DISPLAYS.vld"
$builder.SaveVld($outVldLocal)

$projectRoot = (Get-Item $scriptDir).Parent.Parent.FullName
$outVldRoot = Join-Path $projectRoot "KOMORA9_HMI_DISPLAYS.vld"
Copy-Item $outVldLocal $outVldRoot -Force

Write-Host "`nSukces! Kompletny pakiet ekranow HMI wygenerowany:" -ForegroundColor Green
Write-Host "  1. $outVldLocal"
Write-Host "  2. $outVldRoot"
