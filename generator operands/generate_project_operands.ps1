<#
.SYNOPSIS
    Generator kompletnego pliku definicji operandow (operands.csv) dla projektu Komora 9.
.DESCRIPTION
    Integruje:
    1. Standardowe opisy systemowe VisiLogic (SB, SI, SL, SDW) z czystego szablonu.
    2. Dotychczasowa baze zmiennych z dokumentacja\Visilogic_projekt_operands.csv.
    3. Sygnaly fizyczne z tabeli io-listy\MAPA_IO_PELNA.csv.
    4. Wszystkie operandy wewnetrzne uzywane w wygenerowanych podprogramach drabinkowych (*.vlx).
#>

# Jezeli uruchomiono w 64-bit, przelacz na SysWOW64 aby miec dostep do Microsoft.Jet.OLEDB.4.0 (skanowanie VLX)
if ([IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $p = Start-Process -FilePath $sysWow64 -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$currentDir = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent (Split-Path -Parent $currentDir)

. (Join-Path $currentDir "OperandsBuilder.ps1")

$templatePath = Join-Path $currentDir "templates\template_operands.csv"
$legacyCsv    = Join-Path $projectRoot "dokumentacja\Visilogic_projekt_operands.csv"
$ioCsv        = Join-Path $projectRoot "io-listy\MAPA_IO_PELNA.csv"
$vlxDir       = Join-Path $projectRoot "wygenerowane_pliki_projektu\vlx_subroutines"
$outputCsv    = Join-Path $projectRoot "wygenerowane_pliki_projektu\Visilogic_operands_complete.csv"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   GENEROWANIE PELNEGO ZESTAWU OPERANDOW PROJEKTU (KOMORA 9)          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$builder = [OperandsBuilder]::new()

# 1. Szablon bazowy
Write-Host "[1/5] Ladowanie szablonu systemowego..." -ForegroundColor White
$builder.LoadTemplate($templatePath)

# 2. Scalanie z istniejacym plikiem
if (Test-Path $legacyCsv) {
    Write-Host "[2/5] Scalanie istniejacych zmiennych z Visilogic_projekt_operands.csv..." -ForegroundColor White
    $builder.MergeExistingCsv($legacyCsv)
}

# 3. Import z tabeli I/O
if (Test-Path $ioCsv) {
    Write-Host "[3/5] Importowanie sygnalow sprzetowych z MAPA_IO_PELNA.csv..." -ForegroundColor White
    $ioCount = $builder.ImportIoList($ioCsv)
    Write-Host "      Zaimportowano $ioCount etykiet I/O." -ForegroundColor Green
}

# 4. Skanowanie uzytych operandow w drabinkach *.vlx i inteligentne nazewnictwo
Write-Host "[4/5] Analiza kodu podprogramow *.vlx i uzupelnianie brakujacych nazw..." -ForegroundColor White
$scan = $builder.ScanVlxOperands($vlxDir)

# Słownik znanych ról zmiennych w projekcie Komory 9
$knownProjectTags = @{
    # MI (Rejestry procesowe, receptury, pomiary, bufory)
    'MI:0'   = 'Pomiar_Temp_Raw_AI0'
    'MI:4'   = 'Status_Komory_Kod'
    'MI:10'  = 'Czas_Kroku_Minuty'
    'MI:11'  = 'Czas_Calkowity_Godziny'
    'MI:12'  = 'Zadana_Temp_Komory_01C'
    'MI:13'  = 'Zadana_Wilg_Komory_01RH'
    'MI:14'  = 'Predkosc_Rekuperacji_Pct'
    'MI:20'  = 'PID_Wartosc_Zadana_SP'
    'MI:21'  = 'PID_Wartosc_Biezaca_PV'
    'MI:22'  = 'PID_Sygnal_Wyjsciowy_CV'
    'MI:23'  = 'PID_Wzmocnienie_Kp'
    'MI:24'  = 'PID_Czas_Zdublowania_Ti'
    'MI:25'  = 'PID_Czas_Rozniczkowania_Td'
    'MI:33'  = 'SSR_Sekcja_1_Moc_Pct'
    'MI:34'  = 'SSR_Sekcja_2_Moc_Pct'
    'MI:35'  = 'SSR_Sekcja_3_Moc_Pct'
    'MI:36'  = 'SSR_Sekcja_4_Moc_Pct'
    'MI:37'  = 'SSR_Sekcja_5_Moc_Pct'
    'MI:38'  = 'SSR_Sekcja_6_Moc_Pct'
    'MI:39'  = 'Licznik_Aktywnych_Sekcji'
    'MI:40'  = 'Moc_Calkowita_Grzania_Pct'
    'MI:41'  = 'Prad_Sekcji_1_3_Pomiar'
    'MI:42'  = 'Prad_Sekcji_4_6_Pomiar'
    'MI:43'  = 'Prog_Pradu_Minimalny'
    'MI:44'  = 'Prog_Pradu_Maksymalny'
    'MI:45'  = 'Kod_Bledu_Autodiagnostyki'
    'MI:46'  = 'Bity_Statusu_Awarii_Mask'
    'MI:47'  = 'Licznik_Zdarzen_STB'
    'MI:48'  = 'Licznik_Restartow_Zasilania'
    'MI:49'  = 'Czas_Podtrzymania_Went_s'
    'MI:61'  = 'HMI_Aktywny_Ekran_Nr'
    'MI:62'  = 'HMI_Poprzedni_Ekran_Nr'
    'MI:63'  = 'HMI_Licznik_Wygaszenia_Osw'
    'MI:99'  = 'Status_Kodu_Funkcji'
    'MI:205' = 'Demo_Test_Rejestr_MI'
    'MI:210' = 'VFD1_Czestotliwosc_Zadana'
    'MI:211' = 'VFD1_Czestotliwosc_Biezaca'
    'MI:212' = 'VFD1_Prad_Silnika_01A'
    'MI:213' = 'VFD1_Napiecie_Wyjsciowe_V'
    'MI:214' = 'VFD1_Kod_Bledu_Falownika'
    'MI:220' = 'VFD2_Czestotliwosc_Zadana'
    'MI:221' = 'VFD2_Czestotliwosc_Biezaca'
    'MI:222' = 'VFD2_Prad_Silnika_01A'
    'MI:230' = 'Kalibracja_Temp_Offset'
    'MI:231' = 'Kalibracja_Temp_Gain'
    'MI:232' = 'Kalibracja_Wilg_Offset'
    'MI:240' = 'Statystyka_Godziny_Pracy_Went'
    'MI:241' = 'Statystyka_Godziny_Pracy_Grz'
    'MI:242' = 'Statystyka_Cykle_Suszenia'
    'MI:245' = 'Bufor_Komunikacji_COM1'
    'MI:246' = 'Bufor_Komunikacji_COM2'
    'MI:301' = 'Rejestr_Testowy_Ultimate'

    # ML (Rejestry 32-bitowe)
    'ML:2'   = 'Calkowity_Czas_Pracy_s'
    'ML:3'   = 'Biezacy_Czas_Kroku_s'
    'ML:41'  = 'Licznik_Impulsow_Energii'
    'ML:42'  = 'Energia_Calkowita_kWh'
    'ML:43'  = 'Licznik_Sekund_Zycia_PLC'
    'ML:44'  = 'Czas_Podtrzymania_Upstart_s'

    # MDW (Podwójne słowa 32-bit)
    'MDW:1'  = 'Data_Rozpoczecia_Cyklu'
    'MDW:2'  = 'Czas_Rozpoczecia_Cyklu'
    'MDW:3'  = 'Data_Zakonczenia_Cyklu'
    'MDW:4'  = 'Czas_Zakonczenia_Cyklu'
    'MDW:15' = 'Maska_Zezwolen_Startu'
    'MDW:16' = 'Maska_Blokad_Bezpieczenstwa'
    'MDW:30' = 'Suma_Kontrolna_Receptury'
    'MDW:31' = 'ID_Zaladowanej_Receptury'
    'MDW:32' = 'Wersja_Struktury_Danych'
    'MDW:90' = 'Bufor_Rejestru_Danych_A'
    'MDW:91' = 'Bufor_Rejestru_Danych_B'
    'MDW:100'= 'Licznik_Transmisji_Modbus'
    'MDW:101'= 'Licznik_Bledow_Transmisji'
    'MDW:102'= 'Rejestr_Konfig_Portu'
    'MDW:110'= 'Test_MDW_Rejestr_1'
    'MDW:111'= 'Test_MDW_Rejestr_2'
    'MDW:112'= 'Test_MDW_Rejestr_3'
    'MDW:120'= 'DTI_Adres_Wskaznika'
    'MDW:121'= 'DTI_Liczba_Wierszy'
    'MDW:200'= 'Rejestr_Danych_VFD1'
    'MDW:201'= 'Rejestr_Danych_VFD2'
    'MDW:210'= 'Parametr_Skalowania_A'
    'MDW:211'= 'Parametr_Skalowania_B'
    'MDW:225'= 'Test_Wartosc_Docelowa'
    'MDW:230'= 'Test_Wartosc_Biezaca'
    'MDW:240'= 'Wskaznik_Struktury_HMI'
    'MDW:241'= 'Kolorystyka_Ekranu_RGB'
    'MDW:242'= 'Wskaznik_Animacji_Went'
    'MDW:250'= 'Kopia_Zapasowa_Statusu'
    'MDW:251'= 'Znacznik_Czasu_Ostatniej_Awarii'
    'MDW:300'= 'Rejestr_Testowy_MDW_A'
    'MDW:301'= 'Rejestr_Testowy_MDW_B'

    # MF (Zmiennoprzecinkowe)
    'MF:2'   = 'Temperatura_Kompensowana_C'

    # T (Timery)
    'T:50'   = 'TMR_Restart_Po_Zaniku'
    'T:51'   = 'TMR_Zwloka_Zalaczenia_Went'
    'T:52'   = 'TMR_Zwloka_Grzania_Rozruch'
    'T:53'   = 'TMR_Autodiagnostyka_Cykl'
    'T:200'  = 'TMR_Testowy_Ultimate'

    # XI (Rejestry rozszerzone 16-bit)
    'XI:0'   = 'Krok_1_Czas_Min'
    'XI:1'   = 'Krok_1_Temp_Zadana'
    'XI:2'   = 'Krok_1_Wilg_Zadana'
    'XI:3'   = 'Krok_2_Czas_Min'
    'XI:4'   = 'Krok_2_Temp_Zadana'
    'XI:5'   = 'Krok_2_Wilg_Zadana'
    'XI:6'   = 'Krok_3_Czas_Min'
    'XI:7'   = 'Krok_3_Temp_Zadana'
    'XI:8'   = 'Krok_3_Wilg_Zadana'
    'XI:9'   = 'Krok_4_Czas_Min'
    'XI:10'  = 'Krok_4_Temp_Zadana'
    'XI:11'  = 'Krok_4_Wilg_Zadana'
    'XI:32'  = 'Rezerwa_Receptury_1'
    'XI:33'  = 'Rezerwa_Receptury_2'
    'XI:34'  = 'Rezerwa_Receptury_3'
    'XI:35'  = 'Rezerwa_Receptury_4'
    'XI:36'  = 'Rezerwa_Receptury_5'
    'XI:37'  = 'Rezerwa_Receptury_6'
    # MB (Bity binarne)
    'MB:60'  = 'DTI_Status_Error'
}

# Uzupelnienie i korekta znanych tagow projektu
foreach ($k in $knownProjectTags.Keys) {
    $t, $a = $k.Split(':')
    $builder.SetOperand($t, [int]$a, $knownProjectTags[$k])
}

# Jeśli pozostały jeszcze jakieś operandy bez nazwy, nadaj unikalną nazwę techniczną
$scanAfter = $builder.ScanVlxOperands($vlxDir)
foreach ($item in $scanAfter['Missing']) {
    $cur = $builder.GetOperand($item.Type, $item.Address)
    if ([string]::IsNullOrEmpty($cur)) {
        $autoName = "Var_$($item.Type)_$($item.Address)"
        $builder.SetOperand($item.Type, $item.Address, $autoName)
    }
}

# 5. Zapis do pliku wynikowego
Write-Host "[5/5] Zapisywanie pelnego pliku operandow do: $outputCsv..." -ForegroundColor White
$builder.SaveToCsv($outputCsv, "Windows-1250")

Write-Host "`n--- Podsumowanie pelnego zestawu operandow ---" -ForegroundColor Cyan
$stats = $builder.GetStats()
$items = [System.Collections.Generic.List[string]]::new()
foreach ($k in $builder.TypeNames) {
    if ($stats[$k] -gt 0) {
        $items.Add(("{0}: {1}" -f $k, $stats[$k]))
    }
}
Write-Host ($items -join " | ") -ForegroundColor White

Write-Host "`n--> Uruchamianie walidatora na wygenerowanym pliku..." -ForegroundColor Cyan
$verifier = Join-Path $currentDir "verify_operands.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $verifier -CsvPath $outputCsv -VlxDir $vlxDir
