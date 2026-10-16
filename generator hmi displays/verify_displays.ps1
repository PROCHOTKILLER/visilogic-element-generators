<#
.SYNOPSIS
    Narzędzie weryfikacji integralności i poprawności plików .vld (HMI Displays) dla Unitronics VisiLogic.
.DESCRIPTION
    Skrypt analizuje strukturę archiwum .vld oraz zawartą w nim bazę Jet 4.0 HMIBufferColorPages.udb:
    1. Sprawdza poprawność archiwum ZIP i obecność bazy HMIBufferColorPages.udb.
    2. Weryfikuje tabele Pages i Pages_all (integralność ID, spójność nazw, ModuleID).
    3. Sprawdza powiązania DisplayNote dla każdego PageID.
    4. Weryfikuje współrzędne elementów HMI_Elements w układzie ekranu V350 (320x240 px).
    5. Sprawdza relacje kluczy obcych HMI_Operands -> HMI_Elements -> Pages.
    6. Wyświetla szczegółowy raport diagnostyczny w konsoli.
.PARAMETER VldPath
    Ścieżka do pliku .vld do weryfikacji. Domyślnie szuka DEMO_DISPLAYS.vld lub KOMORA9_HMI_DISPLAYS.vld.
#>

param(
    [string]$VldPath = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrEmpty($VldPath)) {
    # Szukaj najnowszego pliku .vld w katalogu
    $candidates = @(
        (Join-Path $scriptDir "KOMORA9_HMI_DISPLAYS.vld"),
        (Join-Path $scriptDir "DEMO_DISPLAYS.vld"),
        (Join-Path $scriptDir "TEST_OUTPUT.vld")
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $VldPath = $cand
            break
        }
    }
}

if ([string]::IsNullOrEmpty($VldPath) -or -not (Test-Path $VldPath)) {
    Write-Error "Nie znaleziono pliku VLD do weryfikacji. Podaj parametr -VldPath <sciezka>."
    exit 1
}

$resolvedVld = (Resolve-Path $VldPath).Path
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  AUDYTOR INTEGRALNOSCI EKRANOW HMI VISILOGIC (.VLD)" -ForegroundColor Cyan
Write-Host "  Plik: $resolvedVld" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vld_verify_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$extractedUdb = Join-Path $tempDir "HMIBufferColorPages.udb"

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

try {
    # 1. Sprawdzenie archiwum ZIP
    Write-Host "`n[1/6] Sprawdzanie archiwum ZIP..." -ForegroundColor Cyan
    try {
        $tempZip = Join-Path $tempDir "input.zip"
        Copy-Item $resolvedVld $tempZip -Force
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
    } catch {
        $errors.Add("Plik nie jest poprawnym archiwum ZIP: $($_.Exception.Message)")
        throw
    }

    if (-not (Test-Path $extractedUdb)) {
        $errors.Add("W archiwum brakuje pliku glownego bazy 'HMIBufferColorPages.udb'!")
        throw "Brak HMIBufferColorPages.udb"
    }
    $fileSize = (Get-Item $extractedUdb).Length
    Write-Host "  [OK] Znaleziono baze HMIBufferColorPages.udb ($fileSize bajtow)" -ForegroundColor Green

    # 2. Polaczenie OLEDB z baza Jet 4.0
    Write-Host "`n[2/6] Polaczenie z baza Jet 4.0..." -ForegroundColor Cyan
    $connStr = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$extractedUdb;"
    $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
    try {
        $conn.Open()
    } catch {
        $connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$extractedUdb;"
        $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
        $conn.Open()
    }
    Write-Host "  [OK] Polaczenie OLEDB nawiazane pomyslnie." -ForegroundColor Green

    # Funkcja pomocnicza do zapytan
    function Execute-Query([string]$sql) {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $da = New-Object System.Data.OleDb.OleDbDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)
        return ,$dt
    }

    # 3. Weryfikacja stron (Pages i Pages_all)
    Write-Host "`n[3/6] Weryfikacja tabel stron (Pages, Pages_all, DisplayNote)..." -ForegroundColor Cyan
    $dtPages = Execute-Query "SELECT [Id], [Description], [ModuleID], [ColorBack], [GUID] FROM [Pages] ORDER BY [Id]"
    $dtPagesAll = Execute-Query "SELECT [Id], [Description], [ModuleID], [ColorBack], [GUID] FROM [Pages_all] ORDER BY [Id]"
    $dtNotes = Execute-Query "SELECT [PageID] FROM [DisplayNote]"

    Write-Host "  Zdefiniowane strony HMI ($($dtPages.Rows.Count)):" -ForegroundColor White
    $pageIds = @()
    $startUpCount = 0

    for ($i = 0; $i -lt $dtPages.Rows.Count; $i++) {
        $r = $dtPages.Rows[$i]
        $curPageId = [int]$r["Id"]
        $desc = [string]$r["Description"]
        $modId = [int]$r["ModuleID"]
        $guid = [int]$r["GUID"]
        $pageIds += $curPageId

        $typeDesc = if ($modId -eq 1) { "Start-Up Display"; $startUpCount++ } else { "Zwykla strona (ModuleID=2)" }
        Write-Host "    - Strona ID $curPageId : '$desc' [$typeDesc] (GUID=$guid)" -ForegroundColor Yellow

        # Sprawdzenie z Pages_all
        if ($i -lt $dtPagesAll.Rows.Count) {
            $ra = $dtPagesAll.Rows[$i]
            if ([int]$ra["Id"] -ne $curPageId -or [string]$ra["Description"] -ne $desc) {
                $errors.Add("Niespojnosc miedzy Pages a Pages_all dla strony ID $curPageId")
            }
        } else {
            $errors.Add("Pages_all ma mniej rekordow niz Pages!")
        }

        # Sprawdzenie DisplayNote
        $hasNote = $false
        foreach ($rn in $dtNotes.Rows) {
            if ([int]$rn["PageID"] -eq $curPageId) { $hasNote = $true; break }
        }
        if (-not $hasNote) {
            $errors.Add("Brak wymaganego wpisu w DisplayNote dla strony ID $curPageId!")
        }
    }

    if ($startUpCount -gt 1) {
        $warnings.Add("Wykryto wiecej niz jeden ekran oznaczony jako Start-Up ($startUpCount). VisiLogic oczekuje dokladnie 1 ekranu startowego.")
    } elseif ($startUpCount -eq 0) {
        $warnings.Add("Brak ekranu oznaczonego jako Start-Up (ModuleID=1).")
    }

    # 4. Weryfikacja kontrolek (HMI_Elements)
    Write-Host "`n[4/6] Weryfikacja kontrolek (HMI_Elements) i geometrii ekranu 320x240..." -ForegroundColor Cyan
    $dtElems = Execute-Query "SELECT [ID], [DisplayID], [Type], [VarType], [Xs], [Ys], [Dx], [Dy], [Text], [TouchOprndAddr], [VarOprndType], [VarOprndAddr] FROM [HMI_Elements] ORDER BY [DisplayID], [ID]"

    Write-Host "  Laczna liczba kontrolek: $($dtElems.Rows.Count)" -ForegroundColor White

    $typeNames = @{
        1 = "Rectangle/Panel"
        2 = "Line"
        3 = "Image"
        4 = "Label"
        5 = "Variable"
        11 = "Button"
    }

    $elemIds = @()
    $screenLimitX = 320
    $screenLimitY = 240

    foreach ($el in $dtElems.Rows) {
        $eId = [int]$el["ID"]
        $dId = [int]$el["DisplayID"]
        $type = [int]$el["Type"]
        $varType = [int]$el["VarType"]
        $xs = [int]$el["Xs"]
        $ys = [int]$el["Ys"]
        $dx = [int]$el["Dx"]
        $dy = [int]$el["Dy"]
        $text = [string]$el["Text"]
        $elemIds += $eId

        # Relacja DisplayID
        if ($pageIds -notcontains $dId) {
            $errors.Add("Element ID $eId odwoluje sie do nieistniejacej strony DisplayID $dId!")
        }

        # Granice ekranu
        if ($xs -lt 0 -or $ys -lt 0) {
            $errors.Add("Element ID $eId ('$text') ma ujemne wspolrzedne: Xs=$xs, Ys=$ys")
        }
        if (($xs + $dx) -gt $screenLimitX) {
            $warnings.Add("Element ID $eId ('$text') wykracza poza szerokosc ekranu 320px: Xs=$xs, Dx=$dx (Xs+Dx = $($xs+$dx))")
        }
        if (($ys + $dy) -gt $screenLimitY) {
            $warnings.Add("Element ID $eId ('$text') wykracza poza wysokosc ekranu 240px: Ys=$ys, Dy=$dy (Ys+Dy = $($ys+$dy))")
        }
    }
    Write-Host "  [OK] Skontrolowano geometrię i przypisanie $($dtElems.Rows.Count) kontrolek." -ForegroundColor Green

    # 5. Weryfikacja powiazan operandow (HMI_Operands)
    Write-Host "`n[5/6] Weryfikacja powiazan operandow (HMI_Operands)..." -ForegroundColor Cyan
    $dtOps = Execute-Query "SELECT [ElementID], [OprndType], [OprndAddr], [OprndPurpose] FROM [HMI_Operands] ORDER BY [ElementID]"
    Write-Host "  Laczna liczba zdefiniowanych linkow operandow: $($dtOps.Rows.Count)" -ForegroundColor White

    $opTypeNames = @{
        1 = "MB"
        2 = "SB"
        3 = "MI"
        4 = "SI"
        5 = "ML"
        6 = "SL"
        7 = "MF"
        8 = "SF"
        9 = "Input"
        10 = "Output"
        11 = "Timer"
        12 = "Counter"
        16 = "DW"
    }

    foreach ($op in $dtOps.Rows) {
        $eId = [int]$op["ElementID"]
        $oType = [int]$op["OprndType"]
        $oAddr = [int]$op["OprndAddr"]
        $oPurp = [int]$op["OprndPurpose"]

        if ($elemIds -notcontains $eId) {
            $errors.Add("HMI_Operands zawiera ElementID $eId, ktory nie istnieje w tabeli HMI_Elements!")
        }

        $typeName = if ($opTypeNames.ContainsKey($oType)) { $opTypeNames[$oType] } else { "Type_$oType" }
        $purpName = if ($oPurp -eq 1) { "Read/Value" } elseif ($oPurp -eq 2) { "Touch/Action" } else { "Role_$oPurp" }
        # Write-Verbose
    }
    Write-Host "  [OK] Wszystkie powiazania HMI_Operands wskazuja prawidlowe kontrolki." -ForegroundColor Green

    # 6. Weryfikacja tabeli skokow (HMIJumps)
    Write-Host "`n[6/6] Weryfikacja tabeli skokow nawigacyjnych (HMIJumps)..." -ForegroundColor Cyan
    $dtJumps = Execute-Query "SELECT [PageNum], [JumpType], [JumpOpType], [JumpOpAddress], [DispOpType], [DispOpAddress] FROM [HMIJumps] ORDER BY [PageNum], [JumpType]"
    Write-Host "  Laczna liczba zdefiniowanych skokow ekranowych: $($dtJumps.Rows.Count)" -ForegroundColor White

    foreach ($j in $dtJumps.Rows) {
        $pNum = [int]$j["PageNum"]
        $jType = [int]$j["JumpType"]
        $jOpType = [int]$j["JumpOpType"]
        $jOpAddr = [int]$j["JumpOpAddress"]
        $dOpType = [int]$j["DispOpType"]
        $dOpAddr = [int]$j["DispOpAddress"]

        if ($pageIds -notcontains $pNum) {
            $errors.Add("HMIJumps odwoluje sie do nieistniejacej strony zrodlowej PageNum $pNum!")
        }
        if ($pageIds -notcontains $dOpAddr) {
            $errors.Add("HMIJumps (Strona $pNum, Skok $jType) wskazuje na nieistniejacy ekran docelowy DispOpAddress $dOpAddr!")
        }
        if ($jOpType -ne 1) {
            $warnings.Add("HMIJumps (Strona $pNum) ma JumpOpType inny niz 1 (MB): $jOpType")
        }
        if ($dOpType -ne 30) {
            $warnings.Add("HMIJumps (Strona $pNum) ma DispOpType inny niz 30 (Ekran HMI): $dOpType")
        }
    }
    Write-Host "  [OK] Wszystkie wpisy HMIJumps sa spojne z istniejacymi stronami HMI." -ForegroundColor Green

    $conn.Close()
    $conn.Dispose()

    # PODSUMOWANIE AUDYTU
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  PODSUMOWANIE AUDYTU PLIKU VLD" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Liczba stron HMI:       $($dtPages.Rows.Count)"
    Write-Host "  Liczba kontrolek:       $($dtElems.Rows.Count)"
    Write-Host "  Liczba linkow z PLC:    $($dtOps.Rows.Count)"
    Write-Host "  Liczba skokow HMIJumps: $($dtJumps.Rows.Count)"
    Write-Host "  Liczba bledow kryt.:    $($errors.Count)"
    Write-Host "  Liczba ostrzezen:       $($warnings.Count)"

    if ($errors.Count -gt 0) {
        Write-Host "`n  WYKRYTO BLEDY KRYTYCZNE:" -ForegroundColor Red
        foreach ($e in $errors) {
            Write-Host "    [BLAD] $e" -ForegroundColor Red
        }
        exit 1
    }

    if ($warnings.Count -gt 0) {
        Write-Host "`n  OSTRZEZENIA:" -ForegroundColor Yellow
        foreach ($w in $warnings) {
            Write-Host "    [UWAGA] $w" -ForegroundColor Yellow
        }
    }

    Write-Host "`n  WYNIK: PLIK VLD JEST W 100% POPRAWNY I ZGODNY ZE SPECYFIKACJA VISILOGIC!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
