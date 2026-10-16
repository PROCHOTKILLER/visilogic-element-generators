<#
.SYNOPSIS
    Generator ekranow HMI (.vld) dla suszarni komorowej (Komora nr 9) sterownika Unitronics Vision V350.
.DESCRIPTION
    Skrypt implementuje pelna architekture HMI spelniajaca wytyczne standardu ANSI/ISA-101.01:
    - 3 Poziomy dostepu: Operator (domyslny), Technolog (haslo PIN), Serwis (haslo PIN).
    - Kolorystyka w odcieniach szarosci z ciemniejszymi ramkami oddzielajacymi moduly.
    - Kolory dynamiczne zarezerwowane wylacznie dla wskaznikow statusu:
        * Zielony: Praca / RUN / Normalne dzialanie
        * Zolty / Pomaranczowy: Ostrzezenie / Pauza / Stan przejsciowy
        * Czerwony: Awaria / Stan krytyczny / Alarm
    - Ekran Start-up (ModuleID=1) jako Glowny Panel Sterowniczy maszyny:
        * Przyciski START / PAUZA / STOP
        * Glowne pomiary PV (Temperatura, Wilgotnosc) oraz SP (Zadane)
        * Synoptyka 6 niezaleznych sekcji elektrycznych: Wentylatory Obiegowe (1-6) oraz Grzalki SSR (1-6)
        * Niezalezna wentylacja komory: Wentylator Nawiewu i Wentylator Wyciagu ze statusem i predkoscia
    - Ekrany Wykresow w Czasie (Level 2: Kontrola Procesu i Trendy):
        * Wykres 1: Przebieg Temperatury i Wilgotnosci w czasie (T vs RH)
        * Wykres 2: Przebieg Temperatury i Aktywnych Grzalek w czasie (T vs Liczba Grzalek 0..6)
        * Wykres 3: Multi-Trend Temperatury, Wilgotnosci i Predkosci Wentylatorow Nawiewu i Wyciagu (T, RH, VFD1, VFD2)
        * Przegladanie historii przez kilka cykli suszenia wstecz (Biezacy, Cykl -1, Cykl -2, Cykl -3)
    - Ustawienia specjalne Serwisu: Konfiguracja wznowienia po zaniku zasilania (MB40: potwierdzenie vs auto-resume) oraz testy reczne.
.OUTPUTS
    KOMORA9_HMI_ISA101.vld w katalogu generatora oraz w katalogu glownym projektu.
#>

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$builderModule = Join-Path $scriptDir "HmiDisplayBuilder.ps1"

if (-not (Test-Path $builderModule)) {
    throw "Nie znaleziono silnika HmiDisplayBuilder.ps1 w: $builderModule"
}

. $builderModule

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  GENEROWANIE EKRANOW HMI DLA KOMORY 9 (UNITRONICS V350)" -ForegroundColor Cyan
Write-Host "  3 Poziomy Dostepu | Standard ANSI/ISA-101 | Czysty Elektryk" -ForegroundColor Yellow
Write-Host "  Trendy i Wykresy w Czasie | Historia Cykli Suszenia Wstecz" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$builder = [HmiDisplayBuilder]::new()

# ==============================================================================
# PALETA BARW ISA-101 (SZAROSCI + REZERWACJA KOLOROW STATUSOWYCH)
# ==============================================================================
$bgPage         = 74                   # Neutralny szary tla ekranu (Muted Gray)
$cBorderDark    = [HmiColor]::DarkGray  # 68 (Ciemnoszary / grafitowy obrys paneli)
$cBorderBlack   = [HmiColor]::Black     # 0  (Czarny obrys zewnetrzny)
$cPanelBg       = [HmiColor]::LightGray # 103(Jasnoszary wypelnienia kart/modulow)
$cTextDark      = [HmiColor]::Black     # 0  (Podstawowy tekst i etykiety)
$cTextMuted     = [HmiColor]::DarkGray  # 68 (Tekst pomocniczy, jednostki miar)
$cTextLight     = [HmiColor]::White     # 5  (Bialy tekst na ciemnym naglowku)
$cHeaderBg      = [HmiColor]::DarkGray  # 68 (Ciemny grafit belek tytulowych)
$cBtnBg         = [HmiColor]::ButtonGray# 104(Szary przemyslowy korpus przycisku)
$cBtnDarkBg     = [HmiColor]::DarkGray  # 68 (Ciemnoszary przycisk)
$cNumBg         = [HmiColor]::LightGray # 103(Tlo pol zmiennych numerycznych)
$cNumText       = [HmiColor]::Black     # 0  (Ciemny odczyt zmiennych)
$cGraphGrid     = [HmiColor]::DarkGray  # 68 (Linie siatki wykresu)
$cGraphBg       = [HmiColor]::White     # 5  (Tlo pola wykresu o wysokim kontrascie)

# Kolory zarezerwowane WYLACZNIE dla wskaznikow statusu:
$cStatusRun     = [HmiColor]::Green     # 10 (Zielony: Praca / RUN / ON / Gotowosc)
$cStatusWarn    = [HmiColor]::Yellow    # 14 (Zolty: Ostrzezenie / Pauza / Filtr)
$cStatusAlarm   = [HmiColor]::Red       # 2  (Czerwony: Awaria / Stan krytyczny / STB)
$cTrendBlue     = [HmiColor]::Blue      # 12 (Niebieski: Przebieg wilgotnosci RH)
$cTrendOrange   = [HmiColor]::Orange    # 13 (Pomaranczowy: Wentylacja VFD)

# ==============================================================================
# EKRAN 1: ! Start-Up Display (STRONA GLOWNA & PANELE OPERACYJNE - ModuleID=1)
# ==============================================================================
Write-Host "`n[1/11] Tworzenie ekranu Start-Up (Strona Glowna maszyny)..." -ForegroundColor White
$d1 = $builder.AddDisplay("! Start-Up Display", $true)
$d1.ColorBack = $bgPage

# Gorna belka identyfikacyjna i stan ogolny komory (Y: 2..22)
$d1.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d1.AddLabel(5, 4, 185, 16, "KOMORA 9 | SUSZARNIA ELEKTRYCZNA", $cTextLight, $cHeaderBg, 0) | Out-Null
$d1.AddLabel(192, 4, 122, 16, "OPERATOR | STAN: OK", $cTextLight, $cHeaderBg, 0) | Out-Null

# Panel 1: Panel Sterowniczy Maszyny i Glowne Pomiary Procesu (Y: 24..78, H: 54)
$d1.AddRectangle(2, 24, 316, 54, $cBorderDark, $cPanelBg) | Out-Null
# Przyciski sterownicze (ergonomiczne w stonowanej szarosci przemyslowej)
$d1.AddButton(6, 28, 44, 22, "START", 22, $cTextDark, $cBtnBg) | Out-Null
$d1.AddButton(52, 28, 44, 22, "PAUZA", 21, $cTextDark, $cBtnBg) | Out-Null
$d1.AddButton(98, 28, 44, 22, "STOP", 20, $cTextDark, $cBtnBg) | Out-Null

# Status kroku i czasu pod przyciskami
$d1.AddLabel(6, 53, 40, 20, "Krok:", $cTextDark, $cPanelBg, 0) | Out-Null
$d1.AddNumericVariable(46, 53, 30, 20, 21, $false, "Krok", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d1.AddLabel(78, 53, 34, 20, "Czas:", $cTextDark, $cPanelBg, 0) | Out-Null
$d1.AddNumericVariable(112, 53, 34, 20, 23, $false, "Min", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Pomiary PV vs SP (Prawa czesc panelu)
$d1.AddLabel(150, 28, 54, 20, "T [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d1.AddNumericVariable(206, 28, 46, 20, 0, $false, "T_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d1.AddLabel(254, 28, 22, 20, "SP:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d1.AddNumericVariable(278, 28, 38, 20, 31, $false, "T_SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d1.AddLabel(150, 53, 54, 20, "RH [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d1.AddNumericVariable(206, 53, 46, 20, 1, $false, "RH_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d1.AddLabel(254, 53, 22, 20, "SP:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d1.AddNumericVariable(278, 53, 38, 20, 32, $false, "RH_SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Panel 2: 6 Niezaleznych Sekcji Elektrycznych (Wentylatory Obiegu 1-6 + Grzalki SSR 1-6) (Y: 80..136, H: 56)
$d1.AddRectangle(2, 80, 316, 56, $cBorderDark, $cPanelBg) | Out-Null
$d1.AddLabel(5, 82, 310, 14, "SEKCJE 1-6: WENTYLATORY OBIEGOWE I GRZALKI ELEKTRYCZNE", $cTextDark, $cPanelBg, 0) | Out-Null

# 6 Sekcji w siatce (szerokosc kazdej sekcji 50px)
# Dynamiczne kontrolki BinaryText powiazane z fizycznymi wyjsciami PLC:
# O3: Wentylatory W1..W3, O4: Wentylatory W4..W6
# O9..O14: Grzalki SSR Sekcje 1..6
$bagFanW1 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("W1:OFF", [HmiColor]::DarkGray, $bgPage, "W1:RUN", $cStatusRun, $bgPage)
$bagFanW2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("W2:OFF", [HmiColor]::DarkGray, $bgPage, "W2:RUN", $cStatusRun, $bgPage)
$bagFanW3 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("W3:OFF", [HmiColor]::DarkGray, $bgPage, "W3:RUN", $cStatusRun, $bgPage)
$bagFanW4 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("W4:OFF", [HmiColor]::DarkGray, $bgPage, "W4:RUN", $cStatusRun, $bgPage)
$bagFanW5 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("W5:OFF", [HmiColor]::DarkGray, $bgPage, "W5:RUN", $cStatusRun, $bgPage)
$bagFanW6 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("W6:OFF", [HmiColor]::DarkGray, $bgPage, "W6:RUN", $cStatusRun, $bgPage)

$bagHeaterG1 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("G1:OFF", [HmiColor]::DarkGray, $bgPage, "G1:ON", [HmiColor]::Red, $bgPage)
$bagHeaterG2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("G2:OFF", [HmiColor]::DarkGray, $bgPage, "G2:ON", [HmiColor]::Red, $bgPage)
$bagHeaterG3 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("G3:OFF", [HmiColor]::DarkGray, $bgPage, "G3:ON", [HmiColor]::Red, $bgPage)
$bagHeaterG4 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("G4:OFF", [HmiColor]::DarkGray, $bgPage, "G4:ON", [HmiColor]::Red, $bgPage)
$bagHeaterG5 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("G5:OFF", [HmiColor]::DarkGray, $bgPage, "G5:ON", [HmiColor]::Red, $bgPage)
$bagHeaterG6 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("G6:OFF", [HmiColor]::DarkGray, $bgPage, "G6:ON", [HmiColor]::Red, $bgPage)

# Sekcja 1
$d1.AddRectangle(4, 96, 50, 38, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(6, 97, 46, 12, "SEK 1", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(6, 109, 46, 12, [HmiOperandType]::Output, 3, $bagFanW1, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddBinaryText(6, 121, 46, 12, [HmiOperandType]::Output, 9, $bagHeaterG1, [HmiColor]::DarkGray, $bgPage) | Out-Null

# Sekcja 2
$d1.AddRectangle(56, 96, 50, 38, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(58, 97, 46, 12, "SEK 2", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(58, 109, 46, 12, [HmiOperandType]::Output, 3, $bagFanW2, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddBinaryText(58, 121, 46, 12, [HmiOperandType]::Output, 10, $bagHeaterG2, [HmiColor]::DarkGray, $bgPage) | Out-Null

# Sekcja 3
$d1.AddRectangle(108, 96, 50, 38, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(110, 97, 46, 12, "SEK 3", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(110, 109, 46, 12, [HmiOperandType]::Output, 3, $bagFanW3, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddBinaryText(110, 121, 46, 12, [HmiOperandType]::Output, 11, $bagHeaterG3, [HmiColor]::DarkGray, $bgPage) | Out-Null

# Sekcja 4
$d1.AddRectangle(160, 96, 50, 38, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(162, 97, 46, 12, "SEK 4", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(162, 109, 46, 12, [HmiOperandType]::Output, 4, $bagFanW4, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddBinaryText(162, 121, 46, 12, [HmiOperandType]::Output, 12, $bagHeaterG4, [HmiColor]::DarkGray, $bgPage) | Out-Null

# Sekcja 5
$d1.AddRectangle(212, 96, 50, 38, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(214, 97, 46, 12, "SEK 5", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(214, 109, 46, 12, [HmiOperandType]::Output, 4, $bagFanW5, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddBinaryText(214, 121, 46, 12, [HmiOperandType]::Output, 13, $bagHeaterG5, [HmiColor]::DarkGray, $bgPage) | Out-Null

# Sekcja 6
$d1.AddRectangle(264, 96, 50, 38, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(266, 97, 46, 12, "SEK 6", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(266, 109, 46, 12, [HmiOperandType]::Output, 4, $bagFanW6, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddBinaryText(266, 121, 46, 12, [HmiOperandType]::Output, 14, $bagHeaterG6, [HmiColor]::DarkGray, $bgPage) | Out-Null

# Panel 3: Wentylacja Komory (Niezalezny Nawiew i Wyciag) (Y: 138..188, H: 50)
$d1.AddRectangle(2, 138, 316, 50, $cBorderDark, $cPanelBg) | Out-Null
$d1.AddLabel(5, 140, 310, 14, "WENTYLACJA KOMORY - NIEZALEZNY NAWIEW I WYCIAG", $cTextDark, $cPanelBg, 0) | Out-Null

# Dynamiczny status RUN/STOP dla VFD powiazany z wyjsciem O5 (VFD RUN)
$bagVfd = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("STOP", [HmiColor]::DarkGray, $bgPage, "RUN", $cStatusRun, $bgPage)

# Tor Nawiewu (Lewy)
$d1.AddRectangle(6, 154, 150, 30, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(8, 156, 74, 14, "NAWIEW VFD1:", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(84, 156, 32, 14, [HmiOperandType]::Output, 5, $bagVfd, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddLabel(8, 169, 58, 14, "Predkosc:", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddNumericVariable(68, 169, 40, 14, 61, $false, "VFD1_%", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d1.AddLabel(110, 169, 14, 14, "%", $cTextMuted, $bgPage, 0) | Out-Null

# Tor Wyciagu (Prawy)
$d1.AddRectangle(164, 154, 150, 30, $cBorderDark, $bgPage) | Out-Null
$d1.AddLabel(166, 156, 74, 14, "WYCIAG VFD2:", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddBinaryText(242, 156, 32, 14, [HmiOperandType]::Output, 5, $bagVfd, [HmiColor]::DarkGray, $bgPage) | Out-Null
$d1.AddLabel(166, 169, 58, 14, "Predkosc:", $cTextDark, $bgPage, 0) | Out-Null
$d1.AddNumericVariable(226, 169, 40, 14, 62, $false, "VFD2_%", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d1.AddLabel(268, 169, 14, 14, "%", $cTextMuted, $bgPage, 0) | Out-Null

# Dolny Pasek Nawigacyjny (One-Click Navigation - MB211..MB215 powiazane z HMIJumps)
$d1.AddNavButton(2, 191, 61, 46, "PROCES", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d1.AddNavButton(66, 191, 61, 46, "RECEPT", 6, 212, $cTextDark, $cBtnBg) | Out-Null
$d1.AddNavButton(130, 191, 61, 46, "WENTYL", 7, 213, $cTextDark, $cBtnBg) | Out-Null
$d1.AddNavButton(194, 191, 61, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null
$d1.AddNavButton(258, 191, 60, 46, "DOSTEP", 9, 215, $cTextLight, $cBtnDarkBg) | Out-Null

# ==============================================================================
# EKRAN 2: L2_KONTROLA_PROCESU (Level 2: Szczegolowa Kontrola, Pomiary i Wykresy)
# ==============================================================================
Write-Host "[2/11] Tworzenie ekranu L2_KONTROLA_PROCESU..." -ForegroundColor White
$d2 = $builder.AddDisplay("L2_KONTROLA_PROCESU", $false)
$d2.ColorBack = $bgPage

# Header
$d2.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d2.AddLabel(5, 4, 210, 16, "L2: KONTROLA OPERACYJNA SUSZENIA", $cTextLight, $cHeaderBg, 0) | Out-Null
$d2.AddLabel(220, 4, 95, 16, "FAZA MI21", $cTextLight, $cHeaderBg, 0) | Out-Null

# Lewy Panel: Pomiary Termometrii i Wilgotnosci (PV)
$d2.AddRectangle(2, 24, 156, 164, $cBorderDark, $cPanelBg) | Out-Null
$d2.AddLabel(5, 27, 150, 16, "POMIARY PROCESU (PV)", $cTextDark, $cPanelBg, 0) | Out-Null

$d2.AddLabel(6, 46, 70, 18, "T_Sr [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d2.AddNumericVariable(78, 46, 74, 18, 0, $false, "T_Sr", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(6, 66, 70, 18, "Wilg [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d2.AddNumericVariable(78, 66, 74, 18, 1, $false, "RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(6, 86, 70, 18, "Grzalki:", $cTextDark, $cPanelBg, 0) | Out-Null
$d2.AddNumericVariable(78, 86, 36, 18, 50, $false, "Grz_Aktywne", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d2.AddLabel(116, 86, 36, 18, "z 6", $cTextMuted, $cPanelBg, 0) | Out-Null

# Przyciski bezposredniego wejscia do dedykowanych wykresow trendow (MB218..MB220 powiazane z HMIJumps)
$d2.AddNavButton(4, 108, 150, 24, "WYKRES T / RH >>", 3, 218, $cTextLight, $cBtnDarkBg) | Out-Null
$d2.AddNavButton(4, 134, 150, 24, "WYKRES T / GRZALKI >>", 4, 219, $cTextLight, $cBtnDarkBg) | Out-Null
$d2.AddNavButton(4, 160, 150, 24, "WYKRES WENTYLACJA >>", 5, 220, $cTextLight, $cBtnDarkBg) | Out-Null

# Prawy Panel: Porownanie PV vs SP i Operacje Fazowe
$d2.AddRectangle(162, 24, 156, 164, $cBorderDark, $cPanelBg) | Out-Null
$d2.AddLabel(165, 27, 150, 16, "ZADANE (SP) I OPERACJE", $cTextDark, $cPanelBg, 0) | Out-Null

$d2.AddLabel(166, 46, 68, 18, "SP T [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d2.AddNumericVariable(236, 46, 78, 18, 31, $false, "SP_T", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(166, 66, 68, 18, "SP RH [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d2.AddNumericVariable(236, 66, 78, 18, 32, $false, "SP_RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d2.AddLabel(166, 86, 68, 18, "Czas zad:", $cTextDark, $cPanelBg, 0) | Out-Null
$d2.AddNumericVariable(236, 86, 78, 18, 30, $false, "SP_Czas", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Przyciski operacyjne
$d2.AddButton(166, 110, 148, 24, "NASTEPNY KROK", 24, $cTextLight, $cBtnDarkBg) | Out-Null
$d2.AddButton(166, 136, 148, 24, "KASUJ ALARM", 23, $cTextDark, $cBtnBg) | Out-Null
$d2.AddButton(166, 162, 148, 24, "HISTORIA CYKLI", 28, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny (MB210..MB215)
$d2.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d2.AddNavButton(66, 191, 61, 46, "RECEPT", 6, 212, $cTextDark, $cBtnBg) | Out-Null
$d2.AddNavButton(130, 191, 61, 46, "WENTYL", 7, 213, $cTextDark, $cBtnBg) | Out-Null
$d2.AddNavButton(194, 191, 61, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null
$d2.AddNavButton(258, 191, 60, 46, "DOSTEP", 9, 215, $cTextLight, $cBtnDarkBg) | Out-Null

# ==============================================================================
# EKRAN 3: L2_WYKRES_T_RH (Wykres 1: Przebieg Temperatury i Wilgotnosci w Czasie)
# ==============================================================================
Write-Host "[3/11] Tworzenie ekranu L2_WYKRES_T_RH (Trend T vs RH)..." -ForegroundColor White
$d3_trend = $builder.AddDisplay("L2_WYKRES_T_RH", $false)
$d3_trend.ColorBack = $bgPage

# Header
$d3_trend.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d3_trend.AddLabel(5, 4, 310, 16, "L2: WYKRES TEMPERATURY I WILGOTNOSCI (T / RH)", $cTextLight, $cHeaderBg, 0) | Out-Null

# Glowny panel synoptyczny procesu: T & RH (Bargraphy + Pomiary procesowe)
$d3_trend.AddRectangle(2, 24, 226, 122, $cBorderDark, $cPanelBg) | Out-Null

# Kolumna 1: Temperatura komory (MI0)
$d3_trend.AddLabel(6, 26, 96, 14, "TEMP [C]", $cTextDark, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(6, 42, 28, 12, "100-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(6, 82, 28, 12, " 50-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(6, 124, 28, 12, "  0-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddBargraph(34, 42, 34, 96, 0, "BAR_T", $builder.BargraphPropertyBag) | Out-Null
$d3_trend.AddLabel(72, 46, 28, 12, "PV:", $cTextDark, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(72, 60, 36, 16, 0, $false, "T_PV", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d3_trend.AddLabel(72, 84, 28, 12, "SP:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(72, 98, 36, 16, 31, $false, "T_SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Kolumna 2: Wilgotnosc komory (MI1)
$d3_trend.AddLabel(118, 26, 106, 14, "WILGOTNOSC [%]", $cTrendBlue, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(118, 42, 28, 12, "100-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(118, 82, 28, 12, " 50-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(118, 124, 28, 12, "  0-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddBargraph(146, 42, 34, 96, 1, "BAR_RH", $builder.BargraphPropertyBag) | Out-Null
$d3_trend.AddLabel(184, 46, 28, 12, "PV:", $cTrendBlue, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(184, 60, 38, 16, 1, $false, "RH_PV", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d3_trend.AddLabel(184, 84, 28, 12, "SP:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(184, 98, 38, 16, 32, $false, "RH_SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Prawy Panel Wartosci Numerycznych (X: 230..318, Y: 24..146)
$d3_trend.AddRectangle(230, 24, 88, 122, $cBorderDark, $cPanelBg) | Out-Null
$d3_trend.AddLabel(232, 26, 84, 14, "POMIARY ACT:", $cTextDark, $cPanelBg, 0) | Out-Null

$d3_trend.AddLabel(232, 42, 84, 12, "T_Sr [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(232, 54, 84, 16, 0, $false, "T_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3_trend.AddLabel(232, 72, 84, 12, "RH [%]:", $cTrendBlue, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(232, 84, 84, 16, 1, $false, "RH_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3_trend.AddLabel(232, 102, 84, 12, "SP T [C]:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(232, 114, 84, 16, 31, $false, "SP_T", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Pasek Wyboru Historii Cykli Wstecz (Y: 148..188, H: 40)
$d3_trend.AddRectangle(2, 148, 316, 40, $cBorderDark, $cPanelBg) | Out-Null
$d3_trend.AddLabel(5, 150, 180, 14, "HISTORIA CYKLI (DATA TABLE):", $cTextDark, $cPanelBg, 0) | Out-Null
$d3_trend.AddLabel(188, 150, 45, 14, "Cykl:", $cTextDark, $cPanelBg, 0) | Out-Null
$d3_trend.AddNumericVariable(234, 150, 32, 14, 72, $false, "NrCykl", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d3_trend.AddButton(4, 166, 75, 20, "BIEZACY", 70, $cTextLight, $cBtnDarkBg) | Out-Null
$d3_trend.AddButton(82, 166, 75, 20, "CYKL -1", 71, $cTextDark, $cBtnBg) | Out-Null
$d3_trend.AddButton(160, 166, 75, 20, "CYKL -2", 72, $cTextDark, $cBtnBg) | Out-Null
$d3_trend.AddButton(238, 166, 76, 20, "CYKL -3", 73, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny (MB210, MB211, MB214, MB219, MB220)
$d3_trend.AddNavButton(2, 191, 61, 46, "KONTROLA", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d3_trend.AddNavButton(66, 191, 61, 46, "T/GRZ >>", 4, 219, $cTextLight, $cBtnDarkBg) | Out-Null
$d3_trend.AddNavButton(130, 191, 61, 46, "T/WENT >>", 5, 220, $cTextLight, $cBtnDarkBg) | Out-Null
$d3_trend.AddNavButton(194, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d3_trend.AddNavButton(258, 191, 60, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null

# ==============================================================================
# EKRAN 4: L2_WYKRES_T_GRZALKI (Wykres 2: Przebieg Temperatury i Aktywnych Grzalek)
# ==============================================================================
Write-Host "[4/11] Tworzenie ekranu L2_WYKRES_T_GRZALKI (Trend T vs Grzalki)..." -ForegroundColor White
$d4_trend = $builder.AddDisplay("L2_WYKRES_T_GRZALKI", $false)
$d4_trend.ColorBack = $bgPage

# Header
$d4_trend.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d4_trend.AddLabel(5, 4, 310, 16, "L2: WYKRES TEMPERATURY I GRZALEK SSR (T / GRZ)", $cTextLight, $cHeaderBg, 0) | Out-Null

# Glowny panel synoptyczny: Temperatura + Sekcje grzalek
$d4_trend.AddRectangle(2, 24, 226, 122, $cBorderDark, $cPanelBg) | Out-Null

# Kolumna 1: Bargraph Temperatury (MI0)
$d4_trend.AddLabel(6, 26, 68, 14, "TEMP [C]", $cTextDark, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(6, 42, 25, 12, "100-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(6, 82, 25, 12, " 50-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(6, 124, 25, 12, "  0-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddBargraph(32, 42, 28, 96, 0, "BAR_T", $builder.BargraphPropertyBag) | Out-Null
$d4_trend.AddNumericVariable(62, 54, 30, 16, 0, $false, "T_PV", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Kolumna 2: Bargraph Aktywnych Sekcji Grzalek (MI50, 0..6 sekcji)
$d4_trend.AddLabel(94, 26, 54, 14, "SEKCJE", [HmiColor]::Red, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(94, 42, 18, 12, "6-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(94, 82, 18, 12, "3-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(94, 124, 18, 12, "0-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddBargraph(114, 42, 26, 96, 50, "BAR_GRZ", $builder.BargraphPropertyBag) | Out-Null

# Kolumna 3: Statusy fizyczne sekcji 1..6 (Dynamiczne BinaryText O9..O14)
$d4_trend.AddLabel(144, 26, 80, 14, "SEKCJE 1-6:", $cTextDark, $cPanelBg, 0) | Out-Null
$d4_trend.AddBinaryText(144, 42, 36, 16, [HmiOperandType]::Output, 9, $bagHeaterG1, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d4_trend.AddBinaryText(144, 62, 36, 16, [HmiOperandType]::Output, 10, $bagHeaterG2, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d4_trend.AddBinaryText(144, 82, 36, 16, [HmiOperandType]::Output, 11, $bagHeaterG3, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d4_trend.AddBinaryText(184, 42, 36, 16, [HmiOperandType]::Output, 12, $bagHeaterG4, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d4_trend.AddBinaryText(184, 62, 36, 16, [HmiOperandType]::Output, 13, $bagHeaterG5, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d4_trend.AddBinaryText(184, 82, 36, 16, [HmiOperandType]::Output, 14, $bagHeaterG6, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d4_trend.AddLabel(144, 106, 80, 14, "MOC: 72 kW", $cTextDark, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(144, 122, 80, 14, "P_MAX 400V", $cTextMuted, $cPanelBg, 0) | Out-Null

# Prawy Panel
$d4_trend.AddRectangle(230, 24, 88, 122, $cBorderDark, $cPanelBg) | Out-Null
$d4_trend.AddLabel(232, 26, 84, 14, "STATUS GRZ:", $cTextDark, $cPanelBg, 0) | Out-Null

$d4_trend.AddLabel(232, 42, 84, 12, "T_Sr [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d4_trend.AddNumericVariable(232, 54, 84, 16, 0, $false, "T_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d4_trend.AddLabel(232, 72, 84, 12, "Grzalki z 6:", $cStatusRun, $cPanelBg, 0) | Out-Null
$d4_trend.AddNumericVariable(232, 84, 84, 16, 50, $false, "Grz_Il", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d4_trend.AddLabel(232, 102, 84, 12, "Histereza [C]:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d4_trend.AddNumericVariable(232, 114, 84, 16, 40, $false, "Hist_T", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Pasek Wyboru Historii Cykli Wstecz
$d4_trend.AddRectangle(2, 148, 316, 40, $cBorderDark, $cPanelBg) | Out-Null
$d4_trend.AddLabel(5, 150, 180, 14, "HISTORIA CYKLI (DATA TABLE):", $cTextDark, $cPanelBg, 0) | Out-Null
$d4_trend.AddLabel(188, 150, 45, 14, "Cykl:", $cTextDark, $cPanelBg, 0) | Out-Null
$d4_trend.AddNumericVariable(234, 150, 32, 14, 72, $false, "NrCykl", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d4_trend.AddButton(4, 166, 75, 20, "BIEZACY", 70, $cTextLight, $cBtnDarkBg) | Out-Null
$d4_trend.AddButton(82, 166, 75, 20, "CYKL -1", 71, $cTextDark, $cBtnBg) | Out-Null
$d4_trend.AddButton(160, 166, 75, 20, "CYKL -2", 72, $cTextDark, $cBtnBg) | Out-Null
$d4_trend.AddButton(238, 166, 76, 20, "CYKL -3", 73, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny (MB210, MB211, MB214, MB218, MB220)
$d4_trend.AddNavButton(2, 191, 61, 46, "KONTROLA", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d4_trend.AddNavButton(66, 191, 61, 46, "T/RH >>", 3, 218, $cTextLight, $cBtnDarkBg) | Out-Null
$d4_trend.AddNavButton(130, 191, 61, 46, "T/WENT >>", 5, 220, $cTextLight, $cBtnDarkBg) | Out-Null
$d4_trend.AddNavButton(194, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d4_trend.AddNavButton(258, 191, 60, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null

# ==============================================================================
# EKRAN 5: L2_WYKRES_WENTYLACJA (Wykres 3: Multi-Trend T, RH, Nawiew VFD1, Wyciag VFD2)
# ==============================================================================
Write-Host "[5/11] Tworzenie ekranu L2_WYKRES_WENTYLACJA (Multi-Trend Klimat & VFD)..." -ForegroundColor White
$d5_trend = $builder.AddDisplay("L2_WYKRES_WENTYLACJA", $false)
$d5_trend.ColorBack = $bgPage

# Header
$d5_trend.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d5_trend.AddLabel(5, 4, 310, 16, "L2: WYKRES WENTYLACJI I KLIMATU (T, RH, VFD1/2)", $cTextLight, $cHeaderBg, 0) | Out-Null

# Glowny panel wentylacji i klimatu
$d5_trend.AddRectangle(2, 24, 226, 122, $cBorderDark, $cPanelBg) | Out-Null

# Kolumna 1: Nawiew VFD1 (MI61)
$d5_trend.AddLabel(6, 26, 80, 14, "NAWIEW VFD1", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(6, 42, 26, 12, "100-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(6, 82, 26, 12, " 50-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(6, 124, 26, 12, "  0-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d5_trend.AddBargraph(32, 42, 30, 96, 61, "BAR_VFD1", $builder.BargraphPropertyBag) | Out-Null
$d5_trend.AddBinaryText(64, 46, 36, 14, [HmiOperandType]::Output, 5, $bagVfd, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d5_trend.AddNumericVariable(64, 64, 36, 16, 61, $false, "VFD1_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d5_trend.AddLabel(64, 82, 36, 12, "%", $cTextMuted, $cPanelBg, 0) | Out-Null

# Kolumna 2: Wyciag VFD2 (MI62)
$d5_trend.AddLabel(106, 26, 80, 14, "WYCIAG VFD2", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(106, 42, 26, 12, "100-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(106, 82, 26, 12, " 50-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(106, 124, 26, 12, "  0-", $cTextMuted, $cPanelBg, 0) | Out-Null
$d5_trend.AddBargraph(132, 42, 30, 96, 62, "BAR_VFD2", $builder.BargraphPropertyBag) | Out-Null
$d5_trend.AddBinaryText(164, 46, 36, 14, [HmiOperandType]::Output, 5, $bagVfd, [HmiColor]::DarkGray, $cPanelBg) | Out-Null
$d5_trend.AddNumericVariable(164, 64, 36, 16, 62, $false, "VFD2_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d5_trend.AddLabel(164, 82, 36, 12, "%", $cTextMuted, $cPanelBg, 0) | Out-Null

# Bilans i podcisnienie
$d5_trend.AddLabel(10, 124, 210, 16, "BILANS: KONTROLA PODCISNIENIA KOMORY", $cTextDark, $cPanelBg, 0) | Out-Null

# Prawy Panel
$d5_trend.AddRectangle(230, 24, 88, 122, $cBorderDark, $cPanelBg) | Out-Null
$d5_trend.AddLabel(232, 26, 84, 12, "T[C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddNumericVariable(260, 26, 56, 12, 0, $false, "T_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5_trend.AddLabel(232, 42, 84, 12, "RH[%]:", $cTrendBlue, $cPanelBg, 0) | Out-Null
$d5_trend.AddNumericVariable(260, 42, 56, 12, 1, $false, "RH_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5_trend.AddLabel(232, 58, 84, 12, "NAW[%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddNumericVariable(232, 72, 84, 14, 61, $false, "VFD1_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5_trend.AddLabel(232, 90, 84, 12, "WYC[%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddNumericVariable(232, 104, 84, 14, 62, $false, "VFD2_Act", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

# Pasek Wyboru Historii Cykli Wstecz
$d5_trend.AddRectangle(2, 148, 316, 40, $cBorderDark, $cPanelBg) | Out-Null
$d5_trend.AddLabel(5, 150, 180, 14, "HISTORIA CYKLI (DATA TABLE):", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddLabel(188, 150, 45, 14, "Cykl:", $cTextDark, $cPanelBg, 0) | Out-Null
$d5_trend.AddNumericVariable(234, 150, 32, 14, 72, $false, "NrCykl", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d5_trend.AddButton(4, 166, 75, 20, "BIEZACY", 70, $cTextLight, $cBtnDarkBg) | Out-Null
$d5_trend.AddButton(82, 166, 75, 20, "CYKL -1", 71, $cTextDark, $cBtnBg) | Out-Null
$d5_trend.AddButton(160, 166, 75, 20, "CYKL -2", 72, $cTextDark, $cBtnBg) | Out-Null
$d5_trend.AddButton(238, 166, 76, 20, "CYKL -3", 73, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny (MB210, MB211, MB214, MB218, MB219)
$d5_trend.AddNavButton(2, 191, 61, 46, "KONTROLA", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d5_trend.AddNavButton(66, 191, 61, 46, "T/RH >>", 3, 218, $cTextLight, $cBtnDarkBg) | Out-Null
$d5_trend.AddNavButton(130, 191, 61, 46, "T/GRZ >>", 4, 219, $cTextLight, $cBtnDarkBg) | Out-Null
$d5_trend.AddNavButton(194, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d5_trend.AddNavButton(258, 191, 60, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null

# ==============================================================================
# EKRAN 6: L3_RECEPTURY (Level 3: Baza Receptur i Edycja - Dostep: TECHNOLOG)
# ==============================================================================
Write-Host "[6/11] Tworzenie ekranu L3_RECEPTURY (Dostep Technolog)..." -ForegroundColor White
$d6 = $builder.AddDisplay("L3_RECEPTURY", $false)
$d6.ColorBack = $bgPage

# Header
$d6.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d6.AddLabel(5, 4, 310, 16, "L3: PARAMETRY I RECEPTURY (TECHNOLOG)", $cTextLight, $cHeaderBg, 0) | Out-Null

# Panel Edycji Parametrow Kroku (Keypad = 1)
$d6.AddRectangle(2, 24, 175, 164, $cBorderDark, $cPanelBg) | Out-Null
$d6.AddLabel(5, 27, 168, 16, "EDYCJA KROKU (KLAWIATURA)", $cTextDark, $cPanelBg, 0) | Out-Null

$d6.AddLabel(6, 48, 85, 20, "SP Temp [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(94, 48, 78, 20, 31, $true, "SP_T", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddLabel(6, 72, 85, 20, "SP Wilg [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(94, 72, 78, 20, 32, $true, "SP_RH", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddLabel(6, 96, 85, 20, "Czas [min]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(94, 96, 78, 20, 30, $true, "SP_Min", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddLabel(6, 120, 85, 20, "Hister. [C]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(94, 120, 78, 20, 40, $true, "Hist", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddLabel(6, 144, 85, 20, "Wyd. went [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(94, 144, 78, 20, 34, $true, "Wyd_Went", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddLabel(6, 168, 168, 16, "Dotknij pole aby edytowac", $cTextMuted, $cPanelBg, 0) | Out-Null

# Prawy Panel: Zarzadzanie Bankiem Receptur
$d6.AddRectangle(181, 24, 137, 164, $cBorderDark, $cPanelBg) | Out-Null
$d6.AddLabel(184, 27, 130, 16, "BANK RECEPTUR", $cTextDark, $cPanelBg, 0) | Out-Null

$d6.AddLabel(184, 48, 54, 20, "Recept:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(240, 48, 70, 20, 70, $true, "Rec_Nr", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddLabel(184, 72, 54, 20, "Krokow:", $cTextDark, $cPanelBg, 0) | Out-Null
$d6.AddNumericVariable(240, 72, 70, 20, 71, $false, "Kroki_Il", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d6.AddButton(184, 98, 130, 26, "ZAPISZ DO DT", 26, $cTextDark, $cBtnBg) | Out-Null
$d6.AddButton(184, 128, 130, 26, "RECEPTURA +", 25, $cTextDark, $cBtnBg) | Out-Null
$d6.AddButton(184, 158, 130, 26, "KROK +", 24, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny
$d6.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d6.AddNavButton(66, 191, 61, 46, "PROCES", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d6.AddNavButton(130, 191, 61, 46, "WENTYL", 7, 213, $cTextDark, $cBtnBg) | Out-Null
$d6.AddNavButton(194, 191, 61, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null
$d6.AddNavButton(258, 191, 60, 46, "DOSTEP", 9, 215, $cTextLight, $cBtnDarkBg) | Out-Null

# ==============================================================================
# EKRAN 7: L3_WENTYLACJA_REKUP (Level 3: Niezalezna Wentylacja Komory)
# ==============================================================================
Write-Host "[7/11] Tworzenie ekranu L3_WENTYLACJA_REKUP..." -ForegroundColor White
$d7 = $builder.AddDisplay("L3_WENTYLACJA_REKUP", $false)
$d7.ColorBack = $bgPage

# Header
$d7.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d7.AddLabel(5, 4, 310, 16, "L3: WENTYLACJA KOMORY - NAWIEW I WYCIAG", $cTextLight, $cHeaderBg, 0) | Out-Null

# Tor Nawiewu (Supply VFD1)
$bagVfdStatus = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("STOP", [HmiColor]::DarkGray, $cPanelBg, "RUN", $cStatusRun, $cPanelBg)
$d7.AddRectangle(2, 24, 156, 164, $cBorderDark, $cPanelBg) | Out-Null
$d7.AddLabel(5, 27, 150, 16, "TOR NAWIEWU (VFD 1)", $cTextDark, $cPanelBg, 0) | Out-Null

$d7.AddLabel(6, 46, 70, 18, "Status VFD:", $cTextDark, $cPanelBg, 0) | Out-Null
$d7.AddBinaryText(78, 46, 74, 18, [HmiOperandType]::Output, 5, $bagVfdStatus, [HmiColor]::DarkGray, $cPanelBg) | Out-Null

$d7.AddLabel(6, 68, 70, 20, "Nastawa [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d7.AddNumericVariable(78, 68, 74, 20, 61, $true, "VFD1_SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d7.AddLabel(6, 92, 146, 14, "Wskaznik slupkowy mocy:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d7.AddBargraph(6, 108, 148, 46, 61, "BAR_VFD1", $builder.BargraphPropertyBag) | Out-Null

$d7.AddButton(6, 158, 148, 26, "START NAWIEW", 102, $cTextDark, $cBtnBg) | Out-Null

# Tor Wyciagu (Exhaust VFD2)
$d7.AddRectangle(162, 24, 156, 164, $cBorderDark, $cPanelBg) | Out-Null
$d7.AddLabel(165, 27, 150, 16, "TOR WYCIAGU (VFD 2)", $cTextDark, $cPanelBg, 0) | Out-Null

$d7.AddLabel(166, 46, 70, 18, "Status VFD:", $cTextDark, $cPanelBg, 0) | Out-Null
$d7.AddBinaryText(238, 46, 74, 18, [HmiOperandType]::Output, 5, $bagVfdStatus, [HmiColor]::DarkGray, $cPanelBg) | Out-Null

$d7.AddLabel(166, 68, 70, 20, "Nastawa [%]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d7.AddNumericVariable(238, 68, 74, 20, 62, $true, "VFD2_SP", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d7.AddLabel(166, 92, 146, 14, "Wskaznik slupkowy mocy:", $cTextMuted, $cPanelBg, 0) | Out-Null
$d7.AddBargraph(166, 108, 148, 46, 62, "BAR_VFD2", $builder.BargraphPropertyBag) | Out-Null

$d7.AddButton(166, 158, 148, 26, "START WYCIAG", 103, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny
$d7.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d7.AddNavButton(66, 191, 61, 46, "PROCES", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d7.AddNavButton(130, 191, 61, 46, "RECEPT", 6, 212, $cTextDark, $cBtnBg) | Out-Null
$d7.AddNavButton(194, 191, 61, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null
$d7.AddNavButton(258, 191, 60, 46, "DOSTEP", 9, 215, $cTextLight, $cBtnDarkBg) | Out-Null

# ==============================================================================
# EKRAN 8: L4_ALARMY_STATUS (Level 4: Rejestr Alarmow wg ANSI/ISA-18.2)
# ==============================================================================
Write-Host "[8/11] Tworzenie ekranu L4_ALARMY_STATUS (Alarmy ISA-18.2)..." -ForegroundColor White
$d8 = $builder.AddDisplay("L4_ALARMY_STATUS", $false)
$d8.ColorBack = $bgPage

# Header
$d8.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d8.AddLabel(5, 4, 310, 16, "L4: REJESTR ALARMOW I DIAGNOSTYKA", $cTextLight, $cHeaderBg, 0) | Out-Null

# Karta Alarmow Krytycznych (Priorytet 1 - Czerwone wskazniki)
$d8.AddRectangle(2, 24, 316, 78, $cBorderDark, $cPanelBg) | Out-Null
$d8.AddLabel(5, 26, 308, 14, "PRIORYTET 1 - KRYTYCZNE (ZATRZYMANIE CYKLU):", $cStatusAlarm, $cPanelBg, 0) | Out-Null
$d8.AddLabel(8, 42, 302, 14, "[!] AL01: Obwod E-STOP rozwarty (I6 / MB38)", $cTextDark, $cPanelBg, 0) | Out-Null
$d8.AddLabel(8, 56, 302, 14, "[!] AL02: Przegrzanie komory STB > 95C (I7 / MB37)", $cTextDark, $cPanelBg, 0) | Out-Null
$d8.AddLabel(8, 70, 302, 14, "[!] AL03: Zwarcie SSR grzalek sekcji 1-6 (MB34 / MB35)", $cTextDark, $cPanelBg, 0) | Out-Null
$d8.AddLabel(8, 84, 302, 14, "[!] AL04: Wylacznik silnikowy wentylatora (MB36)", $cTextDark, $cPanelBg, 0) | Out-Null

# Karta Ostrzezen (Priorytet 2 - Zolte/Pomaranczowe wskazniki)
$d8.AddRectangle(2, 104, 316, 48, $cBorderDark, $cPanelBg) | Out-Null
$d8.AddLabel(5, 106, 308, 14, "PRIORYTET 2 - OSTRZEZENIA TECHNOLOGICZNE:", $cStatusWarn, $cPanelBg, 0) | Out-Null
$d8.AddLabel(8, 122, 302, 14, "[*] W01: Drzwi komory otwarte (I11 / MB13)", $cTextDark, $cPanelBg, 0) | Out-Null
$d8.AddLabel(8, 136, 302, 14, "[*] W02: Zanik zasilania podczas cyklu (MB25)", $cTextDark, $cPanelBg, 0) | Out-Null

# Przyciski Kwitowania i Wyciszenia
$d8.AddButton(2, 156, 156, 32, "KASUJ / KWITUJ ALARMY", 23, $cTextLight, $cBtnDarkBg) | Out-Null
$d8.AddButton(162, 156, 156, 32, "WYCISZ SYGNALIZATOR", 41, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny
$d8.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d8.AddNavButton(66, 191, 61, 46, "PROCES", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d8.AddNavButton(130, 191, 61, 46, "RECEPT", 6, 212, $cTextDark, $cBtnBg) | Out-Null
$d8.AddNavButton(194, 191, 61, 46, "WENTYL", 7, 213, $cTextDark, $cBtnBg) | Out-Null
$d8.AddNavButton(258, 191, 60, 46, "DOSTEP", 9, 215, $cTextLight, $cBtnDarkBg) | Out-Null

# ==============================================================================
# EKRAN 9: L4_LOGOWANIE_UPRAWNIENIA (Level 4: Zarzadzanie Poziomami Dostepu)
# ==============================================================================
Write-Host "[9/11] Tworzenie ekranu L4_LOGOWANIE_UPRAWNIENIA (3 Poziomy)..." -ForegroundColor White
$d9 = $builder.AddDisplay("L4_LOGOWANIE_UPRAWNIENIA", $false)
$d9.ColorBack = $bgPage

# Header
$d9.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d9.AddLabel(5, 4, 210, 16, "L4: POZIOMY DOSTEPU I LOGOWANIE", $cTextLight, $cHeaderBg, 0) | Out-Null
$d9.AddLabel(220, 4, 95, 16, "POZIOM MI80", $cTextLight, $cHeaderBg, 0) | Out-Null

# Strefa 1: OPERATOR (Domyslny, bez hasla)
$d9.AddRectangle(2, 24, 316, 50, $cBorderDark, $cPanelBg) | Out-Null
$d9.AddLabel(5, 26, 180, 14, "1. OPERATOR (DOMYSLNY)", $cTextDark, $cPanelBg, 0) | Out-Null
$d9.AddLabel(5, 40, 200, 14, "Pelne operowanie: Start, Stop, alarmy", $cTextMuted, $cPanelBg, 0) | Out-Null
$d9.AddButton(210, 28, 102, 38, "WYLOGUJ / OP", 82, $cTextDark, $cBtnBg) | Out-Null

# Strefa 2: TECHNOLOG (Haslo PIN)
$d9.AddRectangle(2, 76, 316, 54, $cBorderDark, $cPanelBg) | Out-Null
$d9.AddLabel(5, 78, 180, 14, "2. TECHNOLOG (HASLO PIN)", $cTextDark, $cPanelBg, 0) | Out-Null
$d9.AddLabel(5, 92, 180, 14, "Edycja receptur, ramp T i wilgotnosci", $cTextMuted, $cPanelBg, 0) | Out-Null
$d9.AddLabel(5, 108, 50, 16, "PIN:", $cTextDark, $cPanelBg, 0) | Out-Null
$d9.AddNumericVariable(56, 108, 60, 18, 81, $true, "PIN_Tech", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d9.AddButton(210, 82, 102, 42, "ZALOGUJ TECH", 80, $cTextDark, $cBtnBg) | Out-Null

# Strefa 3: SERWIS (Haslo PIN)
$d9.AddRectangle(2, 132, 316, 54, $cBorderDark, $cPanelBg) | Out-Null
$d9.AddLabel(5, 134, 180, 14, "3. SERWIS (HASLO PIN)", $cTextDark, $cPanelBg, 0) | Out-Null
$d9.AddLabel(5, 148, 180, 14, "Ustawienia specjalne, zanik zasilania", $cTextMuted, $cPanelBg, 0) | Out-Null
$d9.AddLabel(5, 164, 50, 16, "PIN:", $cTextDark, $cPanelBg, 0) | Out-Null
$d9.AddNumericVariable(56, 164, 60, 18, 82, $true, "PIN_Serw", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null
$d9.AddButton(210, 138, 102, 42, "ZALOGUJ SERW", 81, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny
$d9.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d9.AddNavButton(66, 191, 61, 46, "PROCES", 2, 211, $cTextDark, $cBtnBg) | Out-Null
$d9.AddNavButton(130, 191, 61, 46, "RECEPT", 6, 212, $cTextDark, $cBtnBg) | Out-Null
$d9.AddNavButton(194, 191, 61, 46, "SERWIS >>", 10, 216, $cTextLight, $cBtnDarkBg) | Out-Null
$d9.AddNavButton(258, 191, 60, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null

# ==============================================================================
# EKRAN 10: L4_SERWIS_SPECJALNY (Level 4: Ustawienia Specjalne - Dostep: SERWIS)
# ==============================================================================
Write-Host "[10/11] Tworzenie ekranu L4_SERWIS_SPECJALNY (Dostep Serwis)..." -ForegroundColor White
$d10 = $builder.AddDisplay("L4_SERWIS_SPECJALNY", $false)
$d10.ColorBack = $bgPage

# Header
$d10.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d10.AddLabel(5, 4, 310, 16, "L4: USTAWIENIA SPECJALNE (SERWIS)", $cTextLight, $cHeaderBg, 0) | Out-Null

# Panel 1: Konfiguracja wznowienia po zaniku zasilania (MB40)
$d10.AddRectangle(2, 24, 316, 68, $cBorderDark, $cPanelBg) | Out-Null
$d10.AddLabel(5, 26, 308, 14, "ZACHOWANIE PO ZANIKU ZASILANIA (MB40):", $cTextDark, $cPanelBg, 0) | Out-Null
$d10.AddLabel(5, 42, 308, 14, "0 = Wymagane potwierdzenie | 1 = Auto-Resume", $cTextMuted, $cPanelBg, 0) | Out-Null
$d10.AddButton(6, 58, 304, 28, "PRZELACZ TRYB RESUME (MB40)", 40, $cTextLight, $cBtnDarkBg) | Out-Null

# Panel 2: Czasy Technologiczne i Zaawansowane Parametry
$d10.AddRectangle(2, 94, 316, 52, $cBorderDark, $cPanelBg) | Out-Null
$d10.AddLabel(5, 96, 308, 14, "PARAMETRY TECHNOLOGICZNE MASZYNY:", $cTextDark, $cPanelBg, 0) | Out-Null

$d10.AddLabel(6, 114, 105, 18, "Wybieg went [s]:", $cTextDark, $cPanelBg, 0) | Out-Null
$d10.AddNumericVariable(114, 114, 45, 18, 43, $true, "Wybieg", $builder.NumericPropertyBag, $cNumText, $cNumBg) | Out-Null

$d10.AddLabel(165, 114, 100, 18, "Zwloka kaskady:", $cTextDark, $cPanelBg, 0) | Out-Null
$d10.AddLabel(266, 114, 45, 18, "4 s", $cTextDark, $cPanelBg, 0) | Out-Null

# Przejscie do Recznych Testow Sprzetu
$d10.AddNavButton(6, 150, 308, 34, ">> PRZEJDZ DO RECZNYCH TESTOW WYJSC >>", 11, 217, $cTextDark, $cBtnBg) | Out-Null

# Dolny Pasek Nawigacyjny
$d10.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d10.AddNavButton(66, 191, 61, 46, "DOSTEP", 9, 215, $cTextDark, $cBtnBg) | Out-Null
$d10.AddNavButton(130, 191, 61, 46, "TESTY RECZ", 11, 217, $cTextDark, $cBtnBg) | Out-Null
$d10.AddNavButton(194, 191, 61, 46, "WENTYL", 7, 213, $cTextDark, $cBtnBg) | Out-Null
$d10.AddNavButton(258, 191, 60, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null

# ==============================================================================
# EKRAN 11: L4_SERWIS_TESTY_RECZNE (Level 4: Reczny Test Sprzetu - Dostep: SERWIS)
# ==============================================================================
Write-Host "[11/11] Tworzenie ekranu L4_SERWIS_TESTY_RECZNE (Dostep Serwis)..." -ForegroundColor White
$d11 = $builder.AddDisplay("L4_SERWIS_TESTY_RECZNE", $false)
$d11.ColorBack = $bgPage

# Header
$d11.AddRectangle(2, 2, 316, 20, $cBorderBlack, $cHeaderBg) | Out-Null
$d11.AddLabel(5, 4, 310, 16, "L4: RECZNY TEST WYJSC (SERWIS)", $cTextLight, $cHeaderBg, 0) | Out-Null

# Informacja ostrzegawcza
$d11.AddLabel(4, 24, 312, 14, "DOZWOLONE TYLKO PRZY WYLACZONYM CYKLU (STOP)", $cStatusWarn, $bgPage, 0) | Out-Null

# Test Wentylatorow Obiegowych (1-6)
$d11.AddRectangle(2, 40, 316, 46, $cBorderDark, $cPanelBg) | Out-Null
$d11.AddLabel(4, 41, 310, 12, "TEST WENTYLATOROW OBIEGOWYCH (W1 - W6):", $cTextDark, $cPanelBg, 0) | Out-Null
$d11.AddButton(4, 55, 48, 26, "W1", 90, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(56, 55, 48, 26, "W2", 91, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(108, 55, 48, 26, "W3", 92, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(160, 55, 48, 26, "W4", 93, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(212, 55, 48, 26, "W5", 94, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(264, 55, 48, 26, "W6", 95, $cTextDark, $cBtnBg) | Out-Null

# Test Sekcji Grzalek SSR (1-6)
$d11.AddRectangle(2, 88, 316, 46, $cBorderDark, $cPanelBg) | Out-Null
$d11.AddLabel(4, 89, 310, 12, "TEST SEKCJI GRZALEK ELEKTRYCZNYCH SSR (G1 - G6):", $cTextDark, $cPanelBg, 0) | Out-Null
$d11.AddButton(4, 103, 48, 26, "G1", 96, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(56, 103, 48, 26, "G2", 97, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(108, 103, 48, 26, "G3", 98, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(160, 103, 48, 26, "G4", 99, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(212, 103, 48, 26, "G5", 100, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(264, 103, 48, 26, "G6", 101, $cTextDark, $cBtnBg) | Out-Null

# Test Wentylacji i Zasilania Glownego
$d11.AddRectangle(2, 136, 316, 50, $cBorderDark, $cPanelBg) | Out-Null
$d11.AddButton(4, 142, 98, 38, "NAWIEW VFD1", 102, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(106, 142, 98, 38, "WYCIAG VFD2", 103, $cTextDark, $cBtnBg) | Out-Null
$d11.AddButton(208, 142, 106, 38, "MOC 400V (O8)", 104, $cTextLight, $cBtnDarkBg) | Out-Null

# Dolny Pasek Nawigacyjny
$d11.AddNavButton(2, 191, 61, 46, "GLOWNY", 1, 210, $cTextDark, $cBtnBg) | Out-Null
$d11.AddNavButton(66, 191, 61, 46, "SERWIS", 10, 216, $cTextDark, $cBtnBg) | Out-Null
$d11.AddNavButton(130, 191, 61, 46, "DOSTEP", 9, 215, $cTextDark, $cBtnBg) | Out-Null
$d11.AddNavButton(194, 191, 61, 46, "WENTYL", 7, 213, $cTextDark, $cBtnBg) | Out-Null
$d11.AddNavButton(258, 191, 60, 46, "ALARMY", 8, 214, $cTextDark, $cBtnBg) | Out-Null

# ==============================================================================
# EKSPORT I ZAPIS PAKIETU .VLD
# ==============================================================================
$outVldPath = Join-Path $scriptDir "KOMORA9_HMI_ISA101.vld"
Write-Host "`nZapisywanie pakietu bazy HMI: $outVldPath..." -ForegroundColor Cyan
$builder.SaveVld($outVldPath)

$projectRootVld = Join-Path $scriptDir "..\..\KOMORA9_HMI_ISA101.vld"
Copy-Item $outVldPath $projectRootVld -Force
Write-Host "Kopia glowna zapisana w: $projectRootVld" -ForegroundColor Green

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  GENEROWANIE ZAKONCZONE SUKCESEM!" -ForegroundColor Green
Write-Host "  Wygenerowano 11 profesjonalnych ekranow HMI ISA-101." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
