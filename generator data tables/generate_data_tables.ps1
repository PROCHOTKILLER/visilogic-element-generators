<#
.SYNOPSIS
    generate_data_tables.ps1 - Narzędzie wiersza poleceń (CLI) do generowania plików Data Tables XML dla Unitronics VisiLogic.
.DESCRIPTION
    Tworzy poprawny semantycznie i strukturalnie plik Data_table.xml na podstawie parametrów CLI,
    pliku konfiguracyjnego JSON lub nagłówków pliku CSV.
.PARAMETER OutputPath
    Docelowa ścieżka do pliku XML.
.PARAMETER TableName
    Nazwa tabeli (np. Recipe_Steps).
.PARAMETER RowsCount
    Liczba wierszy w tabeli (np. 20).
.PARAMETER TableId
    Identyfikator tabeli 1-based (domyślnie 1).
.PARAMETER ConfigJson
    Ścieżka do pliku JSON z definicją tabel i kolumn.
.PARAMETER InputCsv
    Ścieżka do pliku CSV, z którego zostaną pobrane nazwy kolumn.
.PARAMETER Verify
    Przełącznik uruchamiający automatyczną weryfikację integralności po wygenerowaniu pliku.
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$OutputPath,

    [string]$TableName = "DataTable1",
    [int]$RowsCount = 20,
    [int]$TableId = 1,
    [string]$ConfigJson,
    [string]$InputCsv,
    [switch]$Verify
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "DataTableBuilder.ps1")

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " GENERATOR DATA TABLES XML DLA UNITRONICS VISILOGIC (CLI)" -ForegroundColor Cyan
Write-Host " Cel: $OutputPath" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$builder = [DataTableBuilder]::new()

if (-not [string]::IsNullOrEmpty($ConfigJson) -and (Test-Path $ConfigJson)) {
    Write-Host "[INFO] Wczytywanie definicji z pliku JSON: $ConfigJson" -ForegroundColor DarkGray
    $jsonContent = Get-Content -Raw $ConfigJson | ConvertFrom-Json
    
    # Obsluga tablicy tabel lub pojedynczej tabeli
    $tableList = if ($jsonContent -is [array]) { $jsonContent } else { @($jsonContent) }
    
    foreach ($tDef in $tableList) {
        $tId = if ($null -ne $tDef.TableId) { [int]$tDef.TableId } else { 1 }
        $tName = if ($null -ne $tDef.Name) { $tDef.Name } else { "Table$tId" }
        $tRows = if ($null -ne $tDef.RowsCount) { [int]$tDef.RowsCount } else { 20 }

        $tbl = $builder.NewTable($tId, $tName, $tRows)

        if ($null -ne $tDef.Columns) {
            foreach ($c in $tDef.Columns) {
                $cType = if ($null -ne $c.FieldType) { [int]$c.FieldType } else { 2 }
                $cSize = if ($null -ne $c.Size) { [int]$c.Size } else { 2 }
                $cMin = if ($null -ne $c.MinValue) { [long]$c.MinValue } else { -32768 }
                $cMax = if ($null -ne $c.MaxValue) { [long]$c.MaxValue } else { 32767 }
                $cLen = if ($null -ne $c.StringLength) { [int]$c.StringLength } else { 10 }

                $col = [DataColumnDefinition]::new($c.Name, $cType, $cSize, $cMin, $cMax, $cLen)
                if ($null -ne $c.ReadOnly) { $col.ReadOnly = [bool]$c.ReadOnly }
                if ($null -ne $c.PartOfProject) { $col.PartOfProject = [bool]$c.PartOfProject }
                $tbl.AddColumn($col) | Out-Null
            }
        }
    }
} elseif (-not [string]::IsNullOrEmpty($InputCsv) -and (Test-Path $InputCsv)) {
    Write-Host "[INFO] Tworzenie tabeli na podstawie naglowkow CSV: $InputCsv" -ForegroundColor DarkGray
    $lines = Get-Content $InputCsv -Encoding Default
    if ($lines.Count -gt 0) {
        $headerLine = $lines[0]
        # Wykrycie separatora (srednik lub przecinek)
        $sep = if ($headerLine.Contains(";")) { ";" } else { "," }
        $headers = $headerLine.Split($sep) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $tbl = $builder.NewTable($TableId, $TableName, $RowsCount)
        foreach ($h in $headers) {
            $hClean = $h.Trim()
            # Automatyczna detekcja typu po nazwie
            if ($hClean -match "(?i)czas|_s|long|total") {
                $tbl.AddLong($hClean, 0, 86400) | Out-Null
            } elseif ($hClean -match "(?i)nazwa|name|text|opis|str") {
                $tbl.AddString($hClean, 16) | Out-Null
            } elseif ($hClean -match "(?i)flaga|enable|on_off|bit|wentylator") {
                $tbl.AddInteger($hClean, 0, 1) | Out-Null
            } else {
                $tbl.AddInteger($hClean, -32768, 32767) | Out-Null
            }
        }
        Write-Host "[OK] Dodano $($tbl.Columns.Count) kolumn z pliku CSV" -ForegroundColor Green
    } else {
        throw "Plik CSV jest pusty: $InputCsv"
    }
} else {
    Write-Host "[INFO] Generowanie domyslnej tabeli $TableName (ID=$TableId, Wierszy=$RowsCount)" -ForegroundColor DarkGray
    $tbl = $builder.NewTable($TableId, $TableName, $RowsCount)
    $tbl.AddInteger("Numer_Kroku", 1, $RowsCount) | Out-Null
    $tbl.AddLong("Czas_Zadany_s", 0, 86400) | Out-Null
    $tbl.AddInteger("Wartosc_Zadana", 0, 1000) | Out-Null
}

$builder.SaveXml($OutputPath)
Write-Host "[SUKCES] Zapisano plik Data Table XML: $OutputPath" -ForegroundColor Green

if ($Verify) {
    Write-Host "`nUruchamianie weryfikatora integralnosci..." -ForegroundColor Gray
    $verifyScript = Join-Path $scriptDir "verify_data_tables.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript $OutputPath
    exit $LASTEXITCODE
}
