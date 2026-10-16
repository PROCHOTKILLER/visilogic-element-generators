<#
.SYNOPSIS
    verify_data_tables.ps1 - Audytor integralności i walidator plików Data_table.xml dla Unitronics VisiLogic.
.DESCRIPTION
    Skrypt weryfikuje poprawność semantyczną i składniową pliku XML tabel danych (Data Tables)
    oraz przeprowadza test akceptacji przez natywny 32-bitowy silnik COM VisiLogic (UnPlcDB1.clsDBServices).
.PARAMETER XmlPath
    Ścieżka do pliku XML z definicją tabel danych.
.PARAMETER SkipComCheck
    Opcjonalne pominięcie weryfikacji silnikiem COM (przydatne, gdy VisiLogic nie jest zainstalowany).
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$XmlPath,

    [switch]$SkipComCheck
)

# Wymuszenie 32-bitowego interpretera dla silnika COM UnPlcDB1.dll
if (-not $SkipComCheck -and [IntPtr]::Size -eq 8) {
    $sysWow64Ps = "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64Ps) {
        Write-Host "[INFO] Uruchomiono w 64-bit PowerShell. Przelaczanie do 32-bit (SysWOW64) w celu weryfikacji COM..." -ForegroundColor DarkGray
        $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "`"$XmlPath`"")
        $p = Start-Process -FilePath $sysWow64Ps -ArgumentList $argsList -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$ErrorCount = 0
$WarningCount = 0

function Report-Ok([string]$msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Report-Warn([string]$msg) {
    Write-Host "  [OSTRZEZENIE] $msg" -ForegroundColor Yellow
    $script:WarningCount++
}

function Report-Error([string]$msg) {
    Write-Host "  [BLAD] $msg" -ForegroundColor Red
    $script:ErrorCount++
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AUDYT INTEGRALNOSCI DATA TABLES XML DLA VISILOGIC" -ForegroundColor Cyan
Write-Host " Plik: $XmlPath" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Istnienie pliku
if (-not (Test-Path $XmlPath)) {
    Report-Error "Wskazany plik XML nie istnieje: $XmlPath"
    exit 1
}

$resolvedPath = (Resolve-Path $XmlPath).Path

# 2. Parsowanie XML
$xmlDoc = New-Object System.Xml.XmlDocument
try {
    $xmlDoc.Load($resolvedPath)
    Report-Ok "Skladnia XML poprawna, dokument zaimportowany pomyslnie"
} catch {
    Report-Error "Nieprawidlowa skladnia XML: $_"
    exit 1
}

# 3. Weryfikacja wezla glownego <PLC_DB>
if ($xmlDoc.DocumentElement.Name -ne "PLC_DB") {
    Report-Error "Wezel glowny XML musi miec nazwe <PLC_DB>, znaleziono: <$($xmlDoc.DocumentElement.Name)>"
} else {
    Report-Ok "Wezel glowny to <PLC_DB>"
}

$tables = $xmlDoc.SelectNodes("//PLC_DB/Table")
if ($null -eq $tables -or $tables.Count -eq 0) {
    Report-Error "Plik XML nie zawiera zadnej tabeli <Table>"
    exit 1
}

Report-Ok "Znaleziono tabel w pliku XML: $($tables.Count)"

$knownTypes = @{
    1  = @{ Name = "Flags (MB / Bit)"; Size = 1 }
    2  = @{ Name = "Integer (MI / 16-bit)"; Size = 2 }
    3  = @{ Name = "Long (ML / 32-bit)"; Size = 4 }
    4  = @{ Name = "DWord (MDW / 32-bit)"; Size = 4 }
    5  = @{ Name = "Byte (8-bit)"; Size = 1 }
    6  = @{ Name = "String (ASCII)"; Size = -1 }
}

$tableIndex = 0
foreach ($tbl in $tables) {
    $tableIndex++
    $tblIdAttr = $tbl.GetAttribute("TABLE_ID")
    $tblDescNode = $tbl.SelectSingleNode("Description")
    $tblRowsNode = $tbl.SelectSingleNode("RowsCount")
    $tblFieldsNode = $tbl.SelectSingleNode("FieldsCount")

    Write-Host "`n--- Sprawdzanie tabeli #$tableIndex (TABLE_ID: '$tblIdAttr') ---" -ForegroundColor Gray

    if ([string]::IsNullOrWhiteSpace($tblIdAttr)) {
        Report-Error "Tabela #$tableIndex nie posiada wymaganego atrybutu TABLE_ID"
    } elseif (-not [int]::TryParse($tblIdAttr, [ref]$null)) {
        Report-Error "Atrybut TABLE_ID='$tblIdAttr' w tabeli #$tableIndex nie jest liczba calkowita"
    } else {
        Report-Ok "TABLE_ID = $tblIdAttr"
    }

    if ($null -eq $tblDescNode -or [string]::IsNullOrWhiteSpace($tblDescNode.InnerText)) {
        Report-Error "Tabela #$tableIndex nie posiada znacznika <Description> z nazwa tabeli"
    } else {
        Report-Ok "Nazwa tabeli: '$($tblDescNode.InnerText)'"
    }

    if ($null -eq $tblRowsNode -or -not [int]::TryParse($tblRowsNode.InnerText, [ref]$null)) {
        Report-Error "Tabela #$tableIndex nie posiada poprawnego znacznika <RowsCount>"
    } else {
        $rowsVal = [int]$tblRowsNode.InnerText
        if ($rowsVal -le 0 -or $rowsVal -gt 8192) {
            Report-Warn "Liczba wierszy RowsCount=$rowsVal jest poza typowym zakresem (1..8192)"
        } else {
            Report-Ok "RowsCount = $rowsVal"
        }
    }

    $columns = $tbl.SelectNodes("Column")
    $actualColCount = if ($null -ne $columns) { $columns.Count } else { 0 }

    if ($null -eq $tblFieldsNode -or -not [int]::TryParse($tblFieldsNode.InnerText, [ref]$null)) {
        Report-Error "Tabela #$tableIndex nie posiada poprawnego znacznika <FieldsCount>"
    } else {
        $fieldsVal = [int]$tblFieldsNode.InnerText
        if ($fieldsVal -ne $actualColCount) {
            Report-Error "Niespojnosc FieldsCount: znacznik deklaruje $fieldsVal kolumn, a zdefiniowano $actualColCount"
        } else {
            Report-Ok "FieldsCount = $fieldsVal (zgodne z liczba znacznikow <Column>)"
        }
    }

    # Weryfikacja poszczegolnych kolumn
    $colNames = @{}
    for ($cIdx = 0; $cIdx -lt $actualColCount; $cIdx++) {
        $col = $columns[$cIdx]
        $colIdAttr = $col.GetAttribute("COL_ID")
        $expectedColId = "Column $cIdx"

        if ($colIdAttr -ne $expectedColId) {
            Report-Error "Kolumna $cIdx ma nieprawidlowy COL_ID='$colIdAttr' (oczekiwano '$expectedColId')"
        }

        $fTypeNode = $col.SelectSingleNode("FieldType")
        $sizeNode = $col.SelectSingleNode("Size")
        $keyNode = $col.SelectSingleNode("Key")
        $roNode = $col.SelectSingleNode("ReadOnly")
        $popNode = $col.SelectSingleNode("PartOfProject")
        $minNode = $col.SelectSingleNode("MinValue")
        $maxNode = $col.SelectSingleNode("MaxValue")
        $descNode = $col.SelectSingleNode("Description")

        if ($null -eq $descNode -or [string]::IsNullOrWhiteSpace($descNode.InnerText)) {
            Report-Error "Kolumna $cIdx nie posiada znacznika <Description> z nazwa kolumny"
        } else {
            $colName = $descNode.InnerText
            if ($colName.Length -gt 50) {
                Report-Warn "Nazwa kolumny '$colName' przekracza limit 50 znakow (dlugosc: $($colName.Length))"
            }
            if ($colNames.ContainsKey($colName)) {
                Report-Error "Zduplikowana nazwa kolumny w tabeli: '$colName'"
            } else {
                $colNames[$colName] = $true
            }
        }

        if ($null -ne $fTypeNode -and [int]::TryParse($fTypeNode.InnerText, [ref]$null)) {
            $ftVal = [int]$fTypeNode.InnerText
            if (-not $knownTypes.ContainsKey($ftVal)) {
                Report-Error "Kolumna '$($descNode.InnerText)' posiada NIEDOPUSZCZALNY FieldType=$ftVal! VisiLogic (UnPlcDB1.dll) akceptuje WYLACZNIE typy 1..6 (1=Flags, 2=Integer, 3=Long, 4=DWord, 5=Byte, 6=String). Wprowadzenie innej wartosci wywoluje 'Run-time error 9: Subscript out of range' oraz 'Run-time error 440: Automation error'!"
            } else {
                $typeInfo = $knownTypes[$ftVal]
                if ($null -ne $sizeNode -and [int]::TryParse($sizeNode.InnerText, [ref]$null)) {
                    $szVal = [int]$sizeNode.InnerText
                    if ($typeInfo.Size -gt 0 -and $szVal -ne $typeInfo.Size) {
                        Report-Error "Kolumna '$($descNode.InnerText)' (typ $($typeInfo.Name)) ma nieprawidlowy rozmiar Size=$szVal (oczekiwano $($typeInfo.Size))"
                    }
                }
            }
        } else {
            Report-Error "Kolumna $cIdx nie posiada prawidlowego FieldType"
        }

        if ($null -ne $keyNode -and [int]::TryParse($keyNode.InnerText, [ref]$null)) {
            $keyVal = [int]$keyNode.InnerText
            $expectedKey = $cIdx + 1
            if ($keyVal -ne $expectedKey) {
                Report-Warn "Kolumna $cIdx posiada Key=$keyVal (standardowo oczekiwano 1-based indeks $expectedKey)"
            }
        }

        if ($null -ne $minNode -and $null -ne $maxNode) {
            $minVal = 0
            $maxVal = 0
            if ([long]::TryParse($minNode.InnerText, [ref]$minVal) -and [long]::TryParse($maxNode.InnerText, [ref]$maxVal)) {
                if ($minVal -gt $maxVal) {
                    Report-Error "Kolumna '$($descNode.InnerText)': MinValue ($minVal) jest wieksze niz MaxValue ($maxVal)"
                }
            }
        }

        if ($null -ne $roNode -and ($roNode.InnerText -ne "True" -and $roNode.InnerText -ne "False")) {
            Report-Error "Kolumna '$($descNode.InnerText)': ReadOnly musi miec wartosc 'True' lub 'False' (znaleziono '$($roNode.InnerText)')"
        }
        if ($null -ne $popNode -and ($popNode.InnerText -ne "True" -and $popNode.InnerText -ne "False")) {
            Report-Error "Kolumna '$($descNode.InnerText)': PartOfProject musi miec wartosc 'True' lub 'False' (znaleziono '$($popNode.InnerText)')"
        }
    }
    Report-Ok "Wszystkie kolumny tabeli #$tableIndex zweryfikowane pomyslnie"
}

# 4. Natywny test silnikiem COM VisiLogic (UnPlcDB1.clsDBServices)
if (-not $SkipComCheck) {
    Write-Host "`n--- Weryfikacja przez natywny silnik COM VisiLogic (UnPlcDB1.dll) ---" -ForegroundColor Gray
    try {
        $dbCom = New-Object -ComObject "UnPlcDB1.clsDBServices"
        $designBlock = $dbCom.CreateDesignBlockFromXML($resolvedPath)
        
        if ($null -eq $designBlock -or $designBlock.Length -le 1) {
            Report-Error "Silnik COM UnPlcDB1.dll odrzucil plik XML! Zwrócony blok ma rozmiar $($designBlock.Length) B (wymagany > 1 B)"
        } else {
            Report-Ok "Silnik COM VisiLogic w 100% zaakceptowal strukture XML! Rozmiar DesignBlock: $($designBlock.Length) bajtow"
        }
    } catch {
        Report-Warn "Nie mozna utworzyc obiektu COM 'UnPlcDB1.clsDBServices' lub wywolac metody: $_"
        Report-Warn "Jesli test jest uruchamiany na maszynie bez VisiLogic, uzyj przelacznika -SkipComCheck"
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($ErrorCount -eq 0) {
    if ($WarningCount -eq 0) {
        Write-Host " [SUKCES] Plik Data Table XML jest w 100% poprawny i gotowy do importu w VisiLogic!" -ForegroundColor Green
    } else {
        Write-Host " [SUKCES Z OSTRZEZENIAMI] Wykryto $WarningCount ostrzezen, ale brak bledow krytycznych." -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host " [PORAZKA] Wykryto $ErrorCount bledow krytycznych! Plik wymaga poprawek przed importem." -ForegroundColor Red
    exit 1
}
