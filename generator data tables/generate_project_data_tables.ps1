<#
.SYNOPSIS
    generate_project_data_tables.ps1 - Generator produkcyjnych tabel danych (Data Tables)
    dla projektu sterownika Unitronics Vision V350 (Komora Suszarnicza nr 9).
.DESCRIPTION
    Generuje w 100% poprawny, zweryfikowany plik XML tabeli receptur DT_Recipe_Steps.xml
    oraz zapisuje go w katalogu wygenerowane_pliki_projektu/data_tables/.
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "DataTableBuilder.ps1")

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " GENERATOR PRODUKCYJNY DATA TABLES - KOMORA SUSZARNICZA NR 9" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$builder = [DataTableBuilder]::new()

# --- Tabela 1: Receptura Suszenia (DT_Recipe_Steps) ---
# 20 krokow suszenia z pelna parametryzacja numeryczna (Integer + Long)
Write-Host "`n[1/2] Konfiguracja tabeli Recipe_Steps (20 wierszy, 10 kolumn numerycznych)..." -ForegroundColor Yellow

$tblRecipe = $builder.NewTable(1, "Recipe_Steps", 20)
$tblRecipe.AddInteger("Numer_Kroku", 1, 20) | Out-Null
$tblRecipe.AddLong("Czas_Zadany_s", 0, 86400) | Out-Null
$tblRecipe.AddInteger("Temp_Zadana_01C", 0, 1200) | Out-Null
$tblRecipe.AddInteger("Wilg_Zadana_01RH", 0, 1000) | Out-Null
$tblRecipe.AddInteger("Warunek_Stop", 0, 7) | Out-Null
$tblRecipe.AddInteger("Tryb_Rekuperatora", 1, 3) | Out-Null
$tblRecipe.AddInteger("Rekup_Wydajnosc_Manual", 0, 100) | Out-Null
$tblRecipe.AddInteger("Rekup_Wydajnosc_Min", 0, 100) | Out-Null
$tblRecipe.AddInteger("Rekup_Wydajnosc_Max", 0, 100) | Out-Null
$tblRecipe.AddInteger("Wentylatory_Obieg", 0, 1) | Out-Null

# --- Sciezka docelowa ---
$outputXml = Join-Path $scriptDir "..\..\wygenerowane_pliki_projektu\data_tables\DT_Recipe_Steps.xml"
$outputXml = [System.IO.Path]::GetFullPath($outputXml)

Write-Host "[2/2] Zapisywanie pliku produkcyjnego: $outputXml" -ForegroundColor Yellow
$builder.SaveXml($outputXml)

Write-Host "[OK] Wygenerowano plik DT_Recipe_Steps.xml!" -ForegroundColor Green

# --- Weryfikacja integralnosci pliku produkcyjnego ---
Write-Host "`nUruchamianie pelnego audytu integralnosci..." -ForegroundColor Cyan
$verifyScript = Join-Path $scriptDir "verify_data_tables.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript $outputXml
