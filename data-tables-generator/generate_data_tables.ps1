<#
.SYNOPSIS
    generate_data_tables.ps1 - Universal CLI Generator for Unitronics VisiLogic Data Tables (.xml).
.DESCRIPTION
    Builds VisiLogic Data Tables (.xml) from a JSON schema definition, CSV input file, or command-line parameters,
    and automatically validates the resulting XML file with verify_data_tables.ps1.
.EXAMPLE
    .\generate_data_tables.ps1 -TableName "Recipe_Steps" -Rows 20 -CsvInput ".\steps.csv" -OutputPath ".\Recipe_Steps.xml"
#>

param(
    [string]$OutputPath = "",
    [string]$TableName = "Data_Table_1",
    [int]$Rows = 16,
    [string]$CsvInput = "",
    [string]$JsonSpecPath = "",
    [switch]$PartOfProject,
    [switch]$ReadOnly
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "DataTableBuilder.ps1")

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptDir "GENERATED_DATA_TABLES.xml"
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   UNITRONICS VISILOGIC DATA TABLES GENERATOR (.XML)                  " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$builder = [DataTableBuilder]::new()

if (-not [string]::IsNullOrWhiteSpace($JsonSpecPath)) {
    if (-not (Test-Path $JsonSpecPath)) {
        throw "JSON specification file not found: $JsonSpecPath"
    }
    Write-Host "[INFO] Loading table schema from JSON specification: $JsonSpecPath" -ForegroundColor Yellow
    $spec = Get-Content -Path $JsonSpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($tSpec in $spec.tables) {
        $tbl = $builder.AddTable([string]$tSpec.name, [int]$tSpec.rows)
        if ($tSpec.partOfProject) { $tbl.PartOfProject = 1 }
        if ($tSpec.readOnly) { $tbl.ReadOnly = 1 }

        foreach ($cSpec in $tSpec.columns) {
            $dt = [VisiDataType]([string]$cSpec.type)
            $sz = if ($cSpec.size) { [int]$cSpec.size } else { 1 }
            $fmt = if ($cSpec.format) { [int]$cSpec.format } else { 0 }
            [void]$tbl.AddColumn([string]$cSpec.name, $dt, $sz, $fmt)
        }

        if ($tSpec.data) {
            foreach ($rData in $tSpec.data) {
                $tbl.AddRow([object[]]$rData)
            }
        }
    }
}
elseif (-not [string]::IsNullOrWhiteSpace($CsvInput)) {
    if (-not (Test-Path $CsvInput)) {
        throw "CSV input file not found: $CsvInput"
    }
    Write-Host "[INFO] Importing table structure and rows from CSV: $CsvInput" -ForegroundColor Yellow
    $csvRows = Import-Csv -Path $CsvInput
    $rowCount = [Math]::Max($Rows, $csvRows.Count)
    $tbl = $builder.AddTable($TableName, $rowCount)
    if ($PartOfProject) { $tbl.PartOfProject = 1 }
    if ($ReadOnly) { $tbl.ReadOnly = 1 }

    $headers = $csvRows[0].PSObject.Properties.Name
    foreach ($h in $headers) {
        if ($h -match "(?i)(time|duration|sec|total|count32|long)") {
            [void]$tbl.AddLongColumn($h)
        } elseif ($h -match "(?i)(name|desc|label|title|text|code)") {
            [void]$tbl.AddStringColumn($h, 16)
        } elseif ($h -match "(?i)(flag|enable|active|bool)") {
            [void]$tbl.AddBoolColumn($h)
        } else {
            [void]$tbl.AddIntColumn($h)
        }
    }

    foreach ($row in $csvRows) {
        $vals = @()
        foreach ($h in $headers) {
            $vals += $row.$h
        }
        $tbl.AddRow($vals)
    }
}
else {
    Write-Host "[INFO] Generating default Data Table '$TableName' ($Rows rows)..." -ForegroundColor Yellow
    $tbl = $builder.AddTable($TableName, $Rows)
    if ($PartOfProject) { $tbl.PartOfProject = 1 }
    if ($ReadOnly) { $tbl.ReadOnly = 1 }

    [void]$tbl.AddIntColumn("Step_Number")
    [void]$tbl.AddLongColumn("Target_Duration_s")
    [void]$tbl.AddIntColumn("Target_Setpoint")
    [void]$tbl.AddStringColumn("Step_Description", 16)

    for ($i = 1; $i -le [Math]::Min(5, $Rows); $i++) {
        $tbl.AddRow(@($i, ($i * 600), (200 + $i * 50), "Phase_$i"))
    }
}

$builder.SaveXml($OutputPath)
Write-Host "[SUCCESS] Generated Data Tables XML file: $OutputPath" -ForegroundColor Green

$verifier = Join-Path $scriptDir "verify_data_tables.ps1"
if (Test-Path $verifier) {
    & $verifier -XmlPath $OutputPath
}
