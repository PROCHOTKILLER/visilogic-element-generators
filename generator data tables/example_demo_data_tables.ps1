<#
.SYNOPSIS
    example_demo_data_tables.ps1 - Skrypt demonstracyjny prezentujący pełnię możliwości silnika DataTableBuilder.
.DESCRIPTION
    Tworzy przykładowy zestaw tabel danych (Data Tables) zawierający różnorodne typy danych
    (Integer, Long, String, Float, Timer, DWord, Flags, Byte) oraz wielotabelowy plik XML,
    a następnie przeprowadza jego rygorystyczną weryfikację.
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "DataTableBuilder.ps1")

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " DEMO GENERATORA DATA TABLES VISILOGIC (AIO)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$builder = [DataTableBuilder]::new()

# --- Tabela 1: Receptura Procesowa (Recipe_Process) ---
Write-Host "`n[1/3] Tworzenie Tabeli 1: Recipe_Process (10 wierszy)..." -ForegroundColor Yellow
$tblRecipe = $builder.NewTable(1, "Recipe_Process", 10)
$tblRecipe.AddInteger("Krok_Id", 1, 10) | Out-Null
$tblRecipe.AddString("Nazwa_Fazy", 16) | Out-Null
$tblRecipe.AddLong("Czas_Trwania_s", 0, 86400) | Out-Null
$tblRecipe.AddInteger("Temperatura_01C", 0, 1200) | Out-Null
$tblRecipe.AddInteger("Wilgotnosc_01RH", 0, 1000) | Out-Null
$tblRecipe.AddInteger("Tryb_Pracy", 1, 3) | Out-Null
$tblRecipe.AddFlags("Wentylacja_Zezwolenie") | Out-Null

# --- Tabela 2: Parametry Regulacji i Nastawy PID (PID_Config) ---
Write-Host "[2/3] Tworzenie Tabeli 2: PID_Config (4 wiersze)..." -ForegroundColor Yellow
$tblPid = $builder.NewTable(2, "PID_Config", 4)
$tblPid.AddString("Nazwa_Petli", 16) | Out-Null
$tblPid.AddFloat("Wspolczynnik_Kp", 0, 10000) | Out-Null
$tblPid.AddTimer("Czas_Zdwojenia_Ti", 0, 999999) | Out-Null
$tblPid.AddTimer("Czas_Wyprzedzenia_Td", 0, 999999) | Out-Null
$tblPid.AddDWord("Maska_Alarmow", 0, 4294967295) | Out-Null
$tblPid.AddByte("Priorytet", 1, 10) | Out-Null

# --- Zapis pliku wynikowego DEMO ---
$demoXmlPath = Join-Path $scriptDir "DEMO_DATA_TABLES.xml"
Write-Host "`n[3/3] Zapisywanie pliku demonstracyjnego: $demoXmlPath" -ForegroundColor Yellow
$builder.SaveXml($demoXmlPath)

Write-Host "[OK] Wygenerowano plik DEMO z $($builder.Tables.Count) tabelami!" -ForegroundColor Green

# --- Weryfikacja integralnosci ---
Write-Host "`nUruchamianie audytora integralnosci..." -ForegroundColor Cyan
$verifyScript = Join-Path $scriptDir "verify_data_tables.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript $demoXmlPath
