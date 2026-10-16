<#
.SYNOPSIS
    run_ultimate_test.ps1 - Ostateczny, rygorystyczny test generatora Data Tables XML dla VisiLogic.
.DESCRIPTION
    Generuje rozbudowaną, wielotabelową bazę danych PLC zawierającą 4 odrębne tabele procesowe
    i wykorzystującą WSZYSTKIE dopuszczalne typy danych sterownika Unitronics Vision:
    Flags (1), Integer (2), Long (3), DW (4), Byte (5), String (6) oraz bezpieczne adaptery
    dla wartości czasowych (Timer -> Long) i zmiennoprzecinkowych (Float -> DW).
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "DataTableBuilder.ps1")

Write-Host "======================================================================" -ForegroundColor Magenta
Write-Host " OSTATECZNY TEST GENERATORA DATA TABLES XML DLA VISILOGIC (STRESS TEST)" -ForegroundColor Magenta
Write-Host "======================================================================" -ForegroundColor Magenta

$builder = [DataTableBuilder]::new()

# ============================================================================
# TABELA 1: DT_Master_Recipe (Wielofazowa Receptura Suszarnicza)
# 20 wierszy, 12 kolumn: String, Integer, Long, Flags, Byte
# ============================================================================
Write-Host "`n[1/4] Budowanie Tabeli 1: DT_Master_Recipe (20 wierszy, 12 kolumn)..." -ForegroundColor Yellow
$t1 = $builder.NewTable(1, "DT_Master_Recipe", 20)
$t1.AddInteger("Krok_ID", 1, 20) | Out-Null
$t1.AddString("Nazwa_Fazy", 24) | Out-Null
$t1.AddLong("Czas_Kroku_Sekundy", 0, 259200) | Out-Null          # do 72h
$t1.AddInteger("Temp_Nawiewu_01C", 0, 1200) | Out-Null          # 0..120.0 C
$t1.AddInteger("Temp_Komory_01C", 0, 1200) | Out-Null           # 0..120.0 C
$t1.AddInteger("Wilg_Zadana_01RH", 0, 1000) | Out-Null          # 0..100.0 %RH
$t1.AddInteger("Delta_T_Zadana_01C", 0, 300) | Out-Null         # 0..30.0 C
$t1.AddByte("Priorytet_Kroku", 1, 10) | Out-Null                # Byte (8-bit)
$t1.AddByte("Tryb_Klimatyzacji", 1, 5) | Out-Null               # Byte (8-bit)
$t1.AddFlags("Wentylacja_Wymuszona") | Out-Null                 # Flags (Bit)
$t1.AddFlags("Dozwolone_Zraszanie") | Out-Null                  # Flags (Bit)
$t1.AddInteger("Kod_Warunku_Stop", 0, 15) | Out-Null

# ============================================================================
# TABELA 2: DT_PID_Loops_Config (Nastawy Wielopętlowych Regulatorów PID)
# 8 pętli regulacyjnych, 10 kolumn: Float, Timer, DWord, UINT16, Integer
# ============================================================================
Write-Host "[2/4] Budowanie Tabeli 2: DT_PID_Loops_Config (8 wierszy, 10 kolumn)..." -ForegroundColor Yellow
$t2 = $builder.NewTable(2, "DT_PID_Loops_Config", 8)
$t2.AddString("Nazwa_Obiegu_PID", 16) | Out-Null
$t2.AddFloat("Wspolczynnik_Kp", 0, 50000) | Out-Null            # Float (32-bit MF)
$t2.AddFloat("Wspolczynnik_Ki", 0, 10000) | Out-Null            # Float (32-bit MF)
$t2.AddFloat("Wspolczynnik_Kd", 0, 10000) | Out-Null            # Float (32-bit MF)
$t2.AddTimer("Czas_Calkowania_Ti", 0, 999999) | Out-Null        # Timer (32-bit T)
$t2.AddTimer("Czas_Rozniczkowania_Td", 0, 999999) | Out-Null    # Timer (32-bit T)
$t2.AddDWord("Maska_Blokad_Sprzetowych", 0, 4294967295) | Out-Null # DWord (32-bit MDW)
$t2.AddUINT16("Czestotliwosc_Probkowania_ms", 10, 5000) | Out-Null # UINT16 (16-bit)
$t2.AddInteger("Strefa_Nieczulosci_01C", 0, 50) | Out-Null
$t2.AddFlags("AutoTuning_Aktywny") | Out-Null

# ============================================================================
# TABELA 3: DT_Modbus_RTU_Gateway (Matryca Wymiany Komunikacyjnej Modbus)
# 16 urządzeń slave, 8 kolumn: Byte, UINT16, DWord, Flags
# ============================================================================
Write-Host "[3/4] Budowanie Tabeli 3: DT_Modbus_RTU_Gateway (16 wierszy, 8 kolumn)..." -ForegroundColor Yellow
$t3 = $builder.NewTable(3, "DT_Modbus_Gateway", 16)
$t3.AddByte("Modbus_Slave_ID", 1, 247) | Out-Null               # Byte
$t3.AddString("Opis_Urzadzenia", 16) | Out-Null
$t3.AddUINT16("Adres_Rejestru_Start", 0, 65535) | Out-Null      # UINT16
$t3.AddByte("Liczba_Rejestrow", 1, 125) | Out-Null
$t3.AddTimer("Timeout_Odpowiedzi_ms", 50, 5000) | Out-Null       # Timer
$t3.AddDWord("Licznik_Transmisji_OK", 0, 4294967295) | Out-Null # DWord
$t3.AddUINT16("Licznik_Bledow_CRC", 0, 65535) | Out-Null        # UINT16
$t3.AddFlags("Urzadzenie_Online") | Out-Null                    # Flags

# ============================================================================
# TABELA 4: DT_Security_Audit_Log (Dziennik Zdarzeń i Bezpieczeństwa)
# 50 wierszy, 7 kolumn: Long, Timer, String, Integer, Byte
# ============================================================================
Write-Host "[4/4] Budowanie Tabeli 4: DT_Audit_Log (50 wierszy, 7 kolumn)..." -ForegroundColor Yellow
$t4 = $builder.NewTable(4, "DT_Audit_Log", 50)
$t4.AddLong("Timestamp_Epoch_s", 0, 2147483647) | Out-Null      # Long (32-bit ze znakiem)
$t4.AddString("Uzytkownik", 16) | Out-Null
$t4.AddInteger("Kod_Zdarzenia", 1000, 9999) | Out-Null
$t4.AddByte("Poziom_Waznosci", 1, 4) | Out-Null                 # 1=Info, 2=Warn, 3=Alarm, 4=Krytyczny
$t4.AddInteger("Wartosc_Poprzednia", -32768, 32767) | Out-Null
$t4.AddInteger("Wartosc_Nowa", -32768, 32767) | Out-Null
$t4.AddFlags("Zatwierdzono_Przez_Kierownika") | Out-Null

# ============================================================================
# Zapis pliku wynikowego
# ============================================================================
$targetFile = Join-Path $scriptDir "ULTIMATE_TEST_DATA_TABLES.xml"
Write-Host "`nZapisywanie kompleksowego pliku testowego: $targetFile" -ForegroundColor Cyan
$builder.SaveXml($targetFile)

$projectTarget = Join-Path $scriptDir "..\..\wygenerowane_pliki_projektu\data_tables\ULTIMATE_TEST_DATA_TABLES.xml"
$projectTarget = [System.IO.Path]::GetFullPath($projectTarget)
$builder.SaveXml($projectTarget)
Write-Host "[OK] Zsynchronizowano plik z katalogiem projektu: $projectTarget" -ForegroundColor Green

Write-Host "[OK] Wygenerowano plik zawierający $($builder.Tables.Count) tabele i $($builder.Tables | ForEach-Object { $_.Columns.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum) unikalnych kolumn!" -ForegroundColor Green

# ============================================================================
# Uruchomienie pełnego audytu integralności
# ============================================================================
Write-Host "`nUruchamianie walidatora integralności i natywnego silnika COM..." -ForegroundColor Cyan
$verifyScript = Join-Path $scriptDir "verify_data_tables.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript $targetFile
