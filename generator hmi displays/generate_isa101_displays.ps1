<#
.SYNOPSIS
    Generator ekranów HMI zgodnych ze standardem ANSI/ISA-101.01 (High Performance HMI)
    dla sterownika Unitronics Vision V350 (Komora Suszarnicza nr 9).
.DESCRIPTION
    Skrypt implementuje zasady filozofii High Performance HMI / ISA-101:
    - 4-poziomowa hierarchia ekranów (Level 1: Overview, Level 2: Process Control, Level 3: Tuning & Manual, Level 4: Alarms)
    - Stonowana paleta barw (Muted Gray Background, brak zbędnych kolorów przy normalnej pracy)
    - Kolory jaskrawe zarezerwowane wyłącznie dla anomalii i stanów alarmowych (Red - Critical, Yellow - Warning)
    - Prezentacja kontekstowa wielkości analogowych (PV obok SP, jednostki miar, wskaźniki słupkowe)
    - Spójna, ergonomiczna nawigacja jedno-kliknięciowa (One-Click Navigation) na dole każdego ekranu (320x240 px)
.OUTPUTS
    KOMORA9_HMI_ISA101.vld w katalogu generatora oraz w katalogu głównym projektu.
#>

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$builderModule = Join-Path $scriptDir "HmiDisplayBuilder.ps1"

if (-not (Test-Path $builderModule)) {
    throw "Nie znaleziono silnika HmiDisplayBuilder.ps1: $builderModule"
}

. $builderModule

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  GENEROWANIE EKRANOW HMI HIGH PERFORMANCE (ANSI/ISA-101)" -ForegroundColor Cyan
Write-Host "  Projekt: Komora Suszarnicza nr 9 | Unitronics Vision V350" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$builder = [HmiDisplayBuilder]::new()

# Stałe kolorystyczne ISA-101
$bgPage        = [HmiColor]::DefaultPageBackground # 74 (Muted Neutral Gray)
$cHeaderBg     = [HmiColor]::DarkGray               # 68 (Stonowany grafit nagłówka)
$cHeaderText   = [HmiColor]::White                  # 5  (Biały czytelny tekst nagłówka)
$cCardBg       = [HmiColor]::White                  # 5  (Czyste białe tło sekcji roboczych)
$cCardBorder   = [HmiColor]::DarkGray               # 68 (Subtelny obrys)
$cTextDark     = [HmiColor]::Black                  # 0  (Podstawowy tekst)
$cTextMuted    = [HmiColor]::DarkGray               # 68 (Opisy jednostek, etykiety pomocnicze)
$cNumBg        = [HmiColor]::LightGray              # 103(Tło pól zmiennych numerycznych)
$cNumText      = [HmiColor]::Navy                   # 1  (Ciemnogranatowy odczyt wartości)
$cBtnNavBg     = [HmiColor]::ButtonGray             # 104(Szary przemysłowy przycisk)
$cBtnNavText   = [HmiColor]::Black                  # 0  (Tekst przycisku)
$cAlarmCritBg  = [HmiColor]::Red                    # 2  (Czerwony alarm krytyczny)
$cAlarmWarnBg  = [HmiColor]::Yellow                 # 14 (Żółty ostrzeżenie)

# ==============================================================================
# EKRAN 1: ! Start-Up Display (Level 0: Identyfikacja i Dostęp do Systemu)
# ==============================================================================
Write-Host "Tworzenie ekranu: ! Start-Up Display (Level 0)..." -ForegroundColor White
$d0 = $builder.AddDisplay("! Start-Up Display", $true)
$d0.ColorBack = $bgPage

# Górna belka identyfikacyjna
$d0.AddRectangle(2, 2, 316, 26, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d0.AddLabel(5, 4, 310, 22, "KOMORA 9 | SYSTEM SUSZARNI", $cHeaderText, $cHeaderBg, 0) | Out-Null

# Karta centralna ISA-101
$d0.AddRectangle(6, 34, 308, 126, $cCardBorder, $cCardBg) | Out-Null
$d0.AddLabel(12, 40, 296, 22, "INTERFEJS OPERATORSKI HIGH PERFORMANCE", [HmiColor]::Navy, $cCardBg, 0) | Out-Null
$d0.AddLabel(12, 64, 296, 18, "Zgodnosc ze standardem: ANSI/ISA-101.01", $cTextDark, $cCardBg, 0) | Out-Null
$d0.AddLabel(12, 84, 296, 18, "Sterownik: Vision V350-35-RA22 (320x240)", $cTextMuted, $cCardBg, 0) | Out-Null
$d0.AddLabel(12, 104, 296, 18, "Hierarchia: 4 Poziomy Nadzoru (L1 - L4)", $cTextMuted, $cCardBg, 0) | Out-Null
$d0.AddLabel(12, 128, 296, 20, "Stan instalacji: GOTOWA DO PRACY", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

# Główny przycisk nawigacji do Level 1 (Overview)
$d0.AddButton(15, 170, 290, 58, "[ WEJSCIE DO SYSTEMU - LEVEL 1 ]", 10, $cHeaderText, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 2: L1_PANORAMA (Level 1: Overview - Całościowa Panorama Procesu)
# ==============================================================================
Write-Host "Tworzenie ekranu: L1_PANORAMA (Level 1: Overview)..." -ForegroundColor White
$d1 = $builder.AddDisplay("L1_PANORAMA", $false)
$d1.ColorBack = $bgPage

# Header L1 z obszarem stanu
$d1.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d1.AddLabel(5, 4, 200, 20, "L1: PANORAMA KOMORY 9", $cHeaderText, $cHeaderBg, 0) | Out-Null
$d1.AddLabel(210, 4, 105, 20, "STATUS: OK", [HmiColor]::White, $cHeaderBg, 0) | Out-Null

# Sekcja 1 (Lewa): KPI Procesu Suszenia (Kluczowe wskaźniki stanu)
$d1.AddRectangle(4, 28, 154, 154, $cCardBorder, $cCardBg) | Out-Null
$d1.AddLabel(6, 31, 148, 18, "PARAMETRY PROCESU", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d1.AddLabel(6, 52, 72, 20, "Faza cyklu:", $cTextDark, $cCardBg, 0) | Out-Null
$d1.AddNumericVariable(80, 52, 74, 20, 108, $false, "Faza", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d1.AddLabel(6, 75, 72, 20, "Czas [min]:", $cTextDark, $cCardBg, 0) | Out-Null
$d1.AddNumericVariable(80, 75, 74, 20, 107, $false, "Czas", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d1.AddLabel(6, 98, 72, 20, "T_Sr [C]:", $cTextDark, $cCardBg, 0) | Out-Null
$d1.AddNumericVariable(80, 98, 74, 20, 102, $false, "T_Sr", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d1.AddLabel(6, 121, 72, 20, "Wilg. [%]:", $cTextDark, $cCardBg, 0) | Out-Null
$d1.AddNumericVariable(80, 121, 74, 20, 104, $false, "RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Słupkowy wskaźnik temperatury z kontekstem (Bargraph)
$d1.AddBargraph(8, 146, 144, 30, 102, "BAR_T", $builder.BargraphPropertyBag) | Out-Null

# Sekcja 2 (Prawa): Stan Agregatów i Szybkie Sterowanie L1
$d1.AddRectangle(162, 28, 154, 154, $cCardBorder, $cCardBg) | Out-Null
$d1.AddLabel(166, 31, 146, 18, "KONTROLA CYKLU", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

# Przyciski sterowania procesem (stonowane wg ISA-101, wysokie, ergonomiczne)
$d1.AddButton(166, 52, 146, 36, "[ START CYKLU ]", 22, [HmiColor]::White, [HmiColor]::Navy) | Out-Null
$d1.AddButton(166, 91, 146, 36, "[ PAUZA CYKLU ]", 21, [HmiColor]::Black, $cBtnNavBg) | Out-Null
$d1.AddButton(166, 130, 146, 46, "[ STOP / STOP AV ]", 20, [HmiColor]::White, [HmiColor]::Red) | Out-Null

# Dolny Pasek Nawigacyjny ISA-101 (One-Click Navigation)
$d1.AddButton(4, 186, 75, 50, "L2 PROCES", 11, $cBtnNavText, $cBtnNavBg) | Out-Null
$d1.AddButton(83, 186, 75, 50, "L3 RECEPT", 12, $cBtnNavText, $cBtnNavBg) | Out-Null
$d1.AddButton(162, 186, 75, 50, "L3 RECZNE", 13, $cBtnNavText, $cBtnNavBg) | Out-Null
$d1.AddButton(241, 186, 75, 50, "L4 ALARMY", 14, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

# ==============================================================================
# EKRAN 3: L2_KONTROLA_PROCESU (Level 2: Unit Control - Synoptyka Operacyjna)
# ==============================================================================
Write-Host "Tworzenie ekranu: L2_KONTROLA_PROCESU (Level 2: Unit Control)..." -ForegroundColor White
$d2 = $builder.AddDisplay("L2_KONTROLA_PROCESU", $false)
$d2.ColorBack = $bgPage

# Header L2
$d2.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d2.AddLabel(5, 4, 210, 20, "L2: KONTROLA OPERACYJNA", $cHeaderText, $cHeaderBg, 0) | Out-Null
$d2.AddLabel(220, 4, 95, 20, "FAZA MI108", [HmiColor]::White, $cHeaderBg, 0) | Out-Null

# Lewy Panel: Termometria Wielopunktowa i Wilgotność z kontekstem
$d2.AddRectangle(4, 28, 158, 154, $cCardBorder, $cCardBg) | Out-Null
$d2.AddLabel(6, 30, 150, 16, "POMIARY PROCESOWE (PV)", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d2.AddLabel(6, 48, 76, 20, "T1 Gora [C]:", $cTextDark, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(84, 48, 74, 20, 100, $false, "T1", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(6, 71, 76, 20, "T2 Dol [C]:", $cTextDark, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(84, 71, 74, 20, 101, $false, "T2", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(6, 94, 76, 20, "T Srednia:", $cTextDark, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(84, 94, 74, 20, 102, $false, "T_Sr", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(6, 117, 76, 20, "Wilg. [%]:", $cTextDark, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(84, 117, 74, 20, 104, $false, "RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(6, 140, 76, 20, "Zewnetrzna:", $cTextMuted, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(84, 140, 74, 20, 103, $false, "T_Zew", $builder.NumericPropertyBag, $cTextMuted, $cNumBg) | Out-Null

# Prawy Panel: Porównanie PV vs SP i Operacje Fazowe
$d2.AddRectangle(166, 28, 150, 154, $cCardBorder, $cCardBg) | Out-Null
$d2.AddLabel(168, 30, 144, 16, "CEL (SP) I OPERACJE", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d2.AddLabel(168, 48, 68, 20, "SP T [C]:", $cTextDark, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(240, 48, 72, 20, 105, $false, "SP_T", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(168, 71, 68, 20, "SP RH [%]:", $cTextDark, $cCardBg, 0) | Out-Null
$d2.AddNumericVariable(240, 71, 72, 20, 106, $false, "SP_RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddButton(168, 96, 144, 38, "NASTEPNY KROK", 24, $cHeaderText, [HmiColor]::Navy) | Out-Null
$d2.AddButton(168, 138, 144, 38, "KASUJ ALARM", 23, $cBtnNavText, $cBtnNavBg) | Out-Null

# Dolny Pasek Nawigacyjny ISA-101
$d2.AddButton(4, 186, 75, 50, "< L1 OVERV", 10, $cBtnNavText, $cBtnNavBg) | Out-Null
$d2.AddButton(83, 186, 75, 50, "L3 RECEPT", 12, $cBtnNavText, $cBtnNavBg) | Out-Null
$d2.AddButton(162, 186, 75, 50, "L3 RECZNE", 13, $cBtnNavText, $cBtnNavBg) | Out-Null
$d2.AddButton(241, 186, 75, 50, "L4 ALARMY", 14, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

# ==============================================================================
# EKRAN 4: L3_RECEPTURY (Level 3: Receptury i Nastawy Zmienne z Klawiaturą)
# ==============================================================================
Write-Host "Tworzenie ekranu: L3_RECEPTURY (Level 3: Tuning & Recipes)..." -ForegroundColor White
$d3 = $builder.AddDisplay("L3_RECEPTURY", $false)
$d3.ColorBack = $bgPage

# Header L3
$d3.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d3.AddLabel(5, 4, 310, 20, "L3: PARAMETRY FAZ I RECEPTUR", $cHeaderText, $cHeaderBg, 0) | Out-Null

# Panel edycji dotykowej (Keypad = 1)
$d3.AddRectangle(4, 28, 160, 154, $cCardBorder, $cCardBg) | Out-Null
$d3.AddLabel(6, 31, 150, 16, "EDYCJA NASTAW ZADANYCH", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d3.AddLabel(6, 50, 78, 22, "SP Temp [C]:", $cTextDark, $cCardBg, 0) | Out-Null
$d3.AddNumericVariable(86, 50, 74, 22, 105, $true, "SP_T", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3.AddLabel(6, 76, 78, 22, "SP Wilg [%]:", $cTextDark, $cCardBg, 0) | Out-Null
$d3.AddNumericVariable(86, 76, 74, 22, 106, $true, "SP_RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3.AddLabel(6, 102, 78, 22, "Czas [min]:", $cTextDark, $cCardBg, 0) | Out-Null
$d3.AddNumericVariable(86, 102, 74, 22, 110, $true, "SP_Min", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3.AddLabel(6, 128, 78, 22, "Hister. [C]:", $cTextDark, $cCardBg, 0) | Out-Null
$d3.AddNumericVariable(86, 128, 74, 22, 111, $true, "Hister", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3.AddLabel(6, 154, 150, 18, "Dotknij wartosc aby edytowac", $cTextMuted, $cCardBg, 0) | Out-Null

# Panel zarządzania bankiem receptur
$d3.AddRectangle(168, 28, 148, 154, $cCardBorder, $cCardBg) | Out-Null
$d3.AddLabel(170, 31, 142, 16, "OPERACJE TABEL", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d3.AddButton(170, 52, 142, 38, "NASTEPNA FAZA", 24, $cHeaderText, [HmiColor]::Navy) | Out-Null
$d3.AddButton(170, 94, 142, 38, "RECEPTURA +", 25, $cBtnNavText, $cBtnNavBg) | Out-Null
$d3.AddButton(170, 136, 142, 38, "ZAPISZ DO DT", 26, $cBtnNavText, $cBtnNavBg) | Out-Null

# Dolny Pasek Nawigacyjny ISA-101
$d3.AddButton(4, 186, 75, 50, "< L1 OVERV", 10, $cBtnNavText, $cBtnNavBg) | Out-Null
$d3.AddButton(83, 186, 75, 50, "L2 PROCES", 11, $cBtnNavText, $cBtnNavBg) | Out-Null
$d3.AddButton(162, 186, 75, 50, "L3 RECZNE", 13, $cBtnNavText, $cBtnNavBg) | Out-Null
$d3.AddButton(241, 186, 75, 50, "L4 ALARMY", 14, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

# ==============================================================================
# EKRAN 5: L3_STEROWANIE_RECZNE (Level 3: Manual Control & Tests)
# ==============================================================================
Write-Host "Tworzenie ekranu: L3_STEROWANIE_RECZNE (Level 3: Equipment Control)..." -ForegroundColor White
$d4 = $builder.AddDisplay("L3_STEROWANIE_RECZNE", $false)
$d4.ColorBack = $bgPage

# Header L3
$d4.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d4.AddLabel(5, 4, 310, 20, "L3: STEROWANIE RECZNE AGREGATAMI", $cHeaderText, $cHeaderBg, 0) | Out-Null

# 6 Przycisków testowych napędów (ergonomiczny układ siatki 2x3, min. 44 px wysokości)
$d4.AddButton(6, 30, 150, 46, "WENTYLATOR 1 (O 0)", 30, $cBtnNavText, $cBtnNavBg) | Out-Null
$d4.AddButton(164, 30, 150, 46, "WENTYLATOR 2 (O 1)", 31, $cBtnNavText, $cBtnNavBg) | Out-Null

$d4.AddButton(6, 80, 150, 46, "PALNIK GRZANIE (O 2)", 32, $cBtnNavText, $cBtnNavBg) | Out-Null
$d4.AddButton(164, 80, 150, 46, "ZRASZANIE (O 3)", 33, $cBtnNavText, $cBtnNavBg) | Out-Null

$d4.AddButton(6, 130, 150, 46, "KLAPY POWIETRZA (O 4)", 34, $cBtnNavText, $cBtnNavBg) | Out-Null
$d4.AddButton(164, 130, 150, 46, "POMPA OBIEGU (O 5)", 35, $cBtnNavText, $cBtnNavBg) | Out-Null

# Dolny Pasek Nawigacyjny ISA-101
$d4.AddButton(4, 186, 75, 50, "< L1 OVERV", 10, $cBtnNavText, $cBtnNavBg) | Out-Null
$d4.AddButton(83, 186, 75, 50, "L2 PROCES", 11, $cBtnNavText, $cBtnNavBg) | Out-Null
$d4.AddButton(162, 186, 75, 50, "L3 RECEPT", 12, $cBtnNavText, $cBtnNavBg) | Out-Null
$d4.AddButton(241, 186, 75, 50, "L4 ALARMY", 14, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

# ==============================================================================
# EKRAN 6: L3_REGULACJA_PID (Level 3: Tuning Pętli PID Palnika)
# ==============================================================================
Write-Host "Tworzenie ekranu: L3_REGULACJA_PID (Level 3: PID Loop Tuning)..." -ForegroundColor White
$d5 = $builder.AddDisplay("L3_REGULACJA_PID", $false)
$d5.ColorBack = $bgPage

# Header L3
$d5.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d5.AddLabel(5, 4, 310, 20, "L3: PETLA REGULACJI PID PALNIKA", $cHeaderText, $cHeaderBg, 0) | Out-Null

# Lewa strona: Dynamika pętli (PV vs SP, Wyjście CV, Słupek)
$d5.AddRectangle(4, 28, 154, 154, $cCardBorder, $cCardBg) | Out-Null
$d5.AddLabel(6, 31, 146, 16, "DYNAMIKA PETLI PID", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d5.AddLabel(6, 50, 68, 20, "PV Temp:", $cTextDark, $cCardBg, 0) | Out-Null
$d5.AddNumericVariable(76, 50, 78, 20, 102, $false, "PV", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5.AddLabel(6, 74, 68, 20, "SP Temp:", $cTextDark, $cCardBg, 0) | Out-Null
$d5.AddNumericVariable(76, 74, 78, 20, 105, $false, "SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5.AddLabel(6, 98, 68, 20, "CV Palnik:", $cTextDark, $cCardBg, 0) | Out-Null
$d5.AddNumericVariable(76, 98, 78, 20, 109, $false, "CV", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Wskaźnik słupkowy wyjścia mocy CV
$d5.AddLabel(6, 122, 146, 16, "Wysterowanie CV (0-100%):", $cTextMuted, $cCardBg, 0) | Out-Null
$d5.AddBargraph(8, 140, 144, 34, 109, "BAR_CV", $builder.BargraphPropertyBag) | Out-Null

# Prawa strona: Nastawy nastawnika (Kp, Ti, Td) z edycją dotykową
$d5.AddRectangle(162, 28, 154, 154, $cCardBorder, $cCardBg) | Out-Null
$d5.AddLabel(166, 31, 146, 16, "STROJENIE PARAMETROW", [HmiColor]::Navy, $cCardBg, 0) | Out-Null

$d5.AddLabel(166, 55, 66, 22, "Kp:", $cTextDark, $cCardBg, 0) | Out-Null
$d5.AddNumericVariable(234, 55, 76, 22, 120, $true, "Kp", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5.AddLabel(166, 88, 66, 22, "Ti [s]:", $cTextDark, $cCardBg, 0) | Out-Null
$d5.AddNumericVariable(234, 88, 76, 22, 121, $true, "Ti", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5.AddLabel(166, 121, 66, 22, "Td [s]:", $cTextDark, $cCardBg, 0) | Out-Null
$d5.AddNumericVariable(234, 121, 76, 22, 122, $true, "Td", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5.AddLabel(166, 152, 146, 18, "Dotknij aby zmienic", $cTextMuted, $cCardBg, 0) | Out-Null

# Dolny Pasek Nawigacyjny ISA-101
$d5.AddButton(4, 186, 75, 50, "< L1 OVERV", 10, $cBtnNavText, $cBtnNavBg) | Out-Null
$d5.AddButton(83, 186, 75, 50, "L2 PROCES", 11, $cBtnNavText, $cBtnNavBg) | Out-Null
$d5.AddButton(162, 186, 75, 50, "L3 RECZNE", 13, $cBtnNavText, $cBtnNavBg) | Out-Null
$d5.AddButton(241, 186, 75, 50, "L4 ALARMY", 14, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

# ==============================================================================
# EKRAN 7: L4_ALARMY_STATUS (Level 4: Alarm Management wg ISA-18.2 / ISA-101)
# ==============================================================================
Write-Host "Tworzenie ekranu: L4_ALARMY_STATUS (Level 4: Alarms & Diagnostics)..." -ForegroundColor White
$d6 = $builder.AddDisplay("L4_ALARMY_STATUS", $false)
$d6.ColorBack = $bgPage

# Header L4 Alarmowy
$d6.AddRectangle(2, 2, 316, 24, [HmiColor]::Black, $cHeaderBg) | Out-Null
$d6.AddLabel(5, 4, 310, 20, "L4: REJESTR ALARMOW I DIAGNOSTYKA", $cHeaderText, $cHeaderBg, 0) | Out-Null

# Karta listy alarmów z podziałem priorytetów ISA-18.2
$d6.AddRectangle(4, 28, 312, 106, $cCardBorder, $cCardBg) | Out-Null
$d6.AddLabel(8, 30, 300, 16, "PRIORYTET 1 (KRYTYCZNE):", [HmiColor]::Red, $cCardBg, 0) | Out-Null
$d6.AddLabel(8, 46, 300, 16, "[!] AL 04: Przegrzanie komory STB > 95C (MB 43)", $cTextDark, $cCardBg, 0) | Out-Null
$d6.AddLabel(8, 62, 300, 16, "[!] AL 03: Awaria palnika / Zanik plomienia (MB 42)", $cTextDark, $cCardBg, 0) | Out-Null
$d6.AddLabel(8, 78, 300, 16, "[!] AL 01/02: Awaria falownikow W1 / W2 (MB 40/41)", $cTextDark, $cCardBg, 0) | Out-Null

$d6.AddLabel(8, 98, 300, 16, "PRIORYTET 2: AL 05 Czujniki PT100 | AL 06 Woda zraszania", $cTextMuted, $cCardBg, 0) | Out-Null

# Przycisk Potwierdzenia i Kasowania Alarmów (Centralny Ack)
$d6.AddButton(4, 138, 312, 44, "[ POTWIERDZ I KASUJ ALARMY (ACK) ]", 23, [HmiColor]::White, [HmiColor]::Red) | Out-Null

# Dolny Pasek Nawigacyjny ISA-101
$d6.AddButton(4, 186, 75, 50, "< L1 OVERV", 10, $cBtnNavText, $cBtnNavBg) | Out-Null
$d6.AddButton(83, 186, 75, 50, "L2 PROCES", 11, $cBtnNavText, $cBtnNavBg) | Out-Null
$d6.AddButton(162, 186, 75, 50, "L3 RECEPT", 12, $cBtnNavText, $cBtnNavBg) | Out-Null
$d6.AddButton(241, 186, 75, 50, "L3 RECZNE", 13, $cBtnNavText, $cBtnNavBg) | Out-Null

# ==============================================================================
# Zapis pliku wynikowego
# ==============================================================================
Write-Host "`nZapisywanie archiwum .vld..." -ForegroundColor Cyan
$outVldLocal = Join-Path $scriptDir "KOMORA9_HMI_ISA101.vld"
$builder.SaveVld($outVldLocal)

$projectRoot = (Get-Item $scriptDir).Parent.Parent.FullName
$outVldRoot = Join-Path $projectRoot "KOMORA9_HMI_ISA101.vld"
Copy-Item $outVldLocal $outVldRoot -Force

Write-Host "`nSukces! Zestaw ekranow High Performance ISA-101 wygenerowany:" -ForegroundColor Green
Write-Host "  1. $outVldLocal"
Write-Host "  2. $outVldRoot"
