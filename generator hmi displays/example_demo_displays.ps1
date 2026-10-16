<#
.SYNOPSIS
    Demonstracyjny generator ekranów HMI (.vld) dla Unitronics VisiLogic.
.DESCRIPTION
    Skrypt demonstruje wykorzystanie silnika HmiDisplayBuilder do utworzenia
    dwóch przykładowych ekranów HMI z etykietami, ramkami, przyciskami dotykowymi
    oraz zmiennymi procesowymi (numeryczna i bargraph).
.OUTPUTS
    DEMO_DISPLAYS.vld w katalogu generatora oraz w katalogu głównym projektu.
#>

$ErrorActionPreference = "Stop"

# Ścieżka do silnika HmiDisplayBuilder
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$builderModule = Join-Path $scriptDir "HmiDisplayBuilder.ps1"

if (-not (Test-Path $builderModule)) {
    throw "Nie znaleziono silnika HmiDisplayBuilder.ps1 pod adresem: $builderModule"
}

. $builderModule

Write-Host "=== Tworzenie demonstracyjnych ekranów HMI VisiLogic ===" -ForegroundColor Cyan

$builder = [HmiDisplayBuilder]::new()

# ==============================================================================
# EKRAN 1: ! Start-Up Display (Powitalny)
# ==============================================================================
$d1 = $builder.AddDisplay("! Start-Up Display", $true)
$d1.ColorBack = [HmiColor]::DefaultPageBackground

# Tło ramki nagłówka
$d1.AddRectangle(5, 5, 310, 40, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d1.AddLabel(10, 10, 300, 30, "UNITRONICS VISION V350", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Ramka centralna z opisem
$d1.AddRectangle(5, 55, 310, 115, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d1.AddLabel(15, 65, 290, 24, "DEMO HMI GENERATOR", [HmiColor]::Navy, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 95, 290, 20, "Wersja demonstracyjna", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 120, 290, 20, "Format .vld (HMIBufferColorPages.udb)", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null
$d1.AddLabel(15, 145, 290, 20, "Rozdzielczosc: 320x240 pikseli", [HmiColor]::DarkGray, [HmiColor]::White, 0) | Out-Null

# Przycisk przejścia do ekranu operacyjnego (MB 10)
$d1.AddButton(20, 185, 280, 45, "[ PRZEJDZ DO EKRANU DEMO ]", 10, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# EKRAN 2: DEMO_PANEL (Elementy sterowania i odczytów)
# ==============================================================================
$d2 = $builder.AddDisplay("DEMO_PANEL", $false)
$d2.ColorBack = [HmiColor]::DefaultPageBackground

# Pasek tytułowy
$d2.AddRectangle(2, 2, 316, 26, [HmiColor]::Black, [HmiColor]::Navy) | Out-Null
$d2.AddLabel(5, 4, 310, 22, "PANEL DEMONSTRACYJNY", [HmiColor]::White, [HmiColor]::Navy, 0) | Out-Null

# Sekcja 1: Zmienna numeryczna MI 10
$d2.AddRectangle(5, 35, 150, 70, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d2.AddLabel(10, 40, 140, 20, "Zmienna MI 10:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d2.AddNumericVariable(20, 65, 120, 30, 10, $false, "MI 10", $builder.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::LightGray) | Out-Null

# Sekcja 2: Wskaźnik Bargraph MI 11
$d2.AddRectangle(165, 35, 150, 70, [HmiColor]::DarkGray, [HmiColor]::White) | Out-Null
$d2.AddLabel(170, 40, 140, 20, "Wskaznik MI 11:", [HmiColor]::Black, [HmiColor]::White, 0) | Out-Null
$d2.AddBargraph(175, 68, 130, 25, 11, "BAR_MI11", $builder.BargraphPropertyBag) | Out-Null

# Sekcja 3: Przyciski dotykowe
$d2.AddButton(10, 120, 145, 45, "PRZYCISK START (MB 1)", 1, [HmiColor]::White, [HmiColor]::Green) | Out-Null
$d2.AddButton(165, 120, 145, 45, "PRZYCISK STOP (MB 2)", 2, [HmiColor]::White, [HmiColor]::Red) | Out-Null

# Pasek nawigacyjny na dole
$d2.AddButton(10, 185, 145, 45, "< POWROT", 11, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$d2.AddButton(165, 185, 145, 45, "KASUJ ALARM (MB 3)", 3, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

# ==============================================================================
# Zapis pliku wynikowego
# ==============================================================================
$outVldLocal = Join-Path $scriptDir "DEMO_DISPLAYS.vld"
$builder.SaveVld($outVldLocal)

# Kopia do głównego katalogu projektu
$projectRoot = (Get-Item $scriptDir).Parent.Parent.FullName
$outVldRoot = Join-Path $projectRoot "DEMO_DISPLAYS.vld"
Copy-Item $outVldLocal $outVldRoot -Force

Write-Host "Demo gotowe!" -ForegroundColor Green
Write-Host "Lokalizacje:"
Write-Host "  1. $outVldLocal"
Write-Host "  2. $outVldRoot"
