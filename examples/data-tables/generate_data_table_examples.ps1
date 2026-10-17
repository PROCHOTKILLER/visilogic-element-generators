<#
.SYNOPSIS
    generate_data_table_examples.ps1 - Generates universal industrial Data Tables XML examples
    for Unitronics VisiLogic (Recipes, Production Logs, Audit Trail).
#>

[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$builderPath = Join-Path $repoRoot "data-tables-generator\DataTableBuilder.ps1"
$verifierPath = Join-Path $repoRoot "data-tables-generator\verify_data_tables.ps1"

if (-not (Test-Path $builderPath)) {
    throw "DataTableBuilder.ps1 not found at: $builderPath"
}

. $builderPath

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VISILOGIC DATA TABLES GENERATOR - EXAMPLES SUITE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. CHEMICAL_BATCH_RECIPES.xml
# -------------------------------------------------------------
Write-Host "`n[1/3] Generating Chemical Batch Recipes Data Table..." -ForegroundColor Yellow
$recipeFile = Join-Path $scriptDir "CHEMICAL_BATCH_RECIPES.xml"
$recipeBuilder = [DataTableBuilder]::new()

# Table 1: Recipe Headers
$tblHeader = $recipeBuilder.NewTable(1, "Recipe_Headers", 10)
$tblHeader.AddInteger("Recipe_ID", 1, 10) | Out-Null
$tblHeader.AddString("Recipe_Name", 20) | Out-Null
$tblHeader.AddInteger("Total_Steps", 1, 20) | Out-Null
$tblHeader.AddLong("Target_Volume_L", 0, 50000) | Out-Null
$tblHeader.AddFlags("Is_Active") | Out-Null

# Table 2: Recipe Steps
$tblSteps = $recipeBuilder.NewTable(2, "Recipe_Steps", 50)
$tblSteps.AddInteger("Recipe_ID", 1, 10) | Out-Null
$tblSteps.AddInteger("Step_Number", 1, 20) | Out-Null
$tblSteps.AddInteger("Operation_Type", 1, 8) | Out-Null # 1=Fill, 2=Heat, 3=Mix, 4=Dose, 5=React, 6=Cool, 7=Drain, 8=CIP
$tblSteps.AddInteger("Set_Temp_C", 0, 1500) | Out-Null # Scaled 0.1 C
$tblSteps.AddInteger("Agitator_Speed_RPM", 0, 1500) | Out-Null
$tblSteps.AddLong("Dwell_Time_s", 0, 86400) | Out-Null
$tblSteps.AddLong("Acid_Dose_ml", 0, 50000) | Out-Null

$recipeBuilder.SaveXml($recipeFile)
Write-Host "  -> Saved: $recipeFile" -ForegroundColor Green

# -------------------------------------------------------------
# 2. SHIFT_PRODUCTION_LOG.xml
# -------------------------------------------------------------
Write-Host "`n[2/3] Generating Shift Production Log Data Table..." -ForegroundColor Yellow
$shiftFile = Join-Path $scriptDir "SHIFT_PRODUCTION_LOG.xml"
$shiftBuilder = [DataTableBuilder]::new()

$tblShift = $shiftBuilder.NewTable(1, "Production_Shifts", 24)
$tblShift.AddInteger("Shift_ID", 1, 24) | Out-Null
$tblShift.AddString("Shift_Date", 10) | Out-Null # YYYY-MM-DD
$tblShift.AddString("Shift_Leader", 16) | Out-Null
$tblShift.AddLong("Units_Produced", 0, 1000000) | Out-Null
$tblShift.AddLong("Units_Rejected", 0, 1000000) | Out-Null
$tblShift.AddLong("Uptime_Seconds", 0, 86400) | Out-Null
$tblShift.AddLong("Energy_kWh", 0, 100000) | Out-Null
$tblShift.AddInteger("Efficiency_Pct", 0, 100) | Out-Null

$shiftBuilder.SaveXml($shiftFile)
Write-Host "  -> Saved: $shiftFile" -ForegroundColor Green

# -------------------------------------------------------------
# 3. ALARM_AUDIT_TRAIL.xml
# -------------------------------------------------------------
Write-Host "`n[3/3] Generating Alarm & Event Audit Trail Data Table..." -ForegroundColor Yellow
$alarmFile = Join-Path $scriptDir "ALARM_AUDIT_TRAIL.xml"
$alarmBuilder = [DataTableBuilder]::new()

$tblAlarm = $alarmBuilder.NewTable(1, "Alarm_Audit_Log", 100)
$tblAlarm.AddLong("Event_ID", 1, 1000000) | Out-Null
$tblAlarm.AddString("Timestamp", 20) | Out-Null # YYYY-MM-DD HH:MM:SS
$tblAlarm.AddInteger("Alarm_Code", 1000, 9999) | Out-Null
$tblAlarm.AddByte("Alarm_Severity", 1, 4) | Out-Null # 1=Info, 2=Warning, 3=High, 4=Critical
$tblAlarm.AddFlags("Ack_State") | Out-Null
$tblAlarm.AddLong("Trigger_Value", -2147483648, 2147483647) | Out-Null
$tblAlarm.AddString("Tag_Name", 16) | Out-Null

$alarmBuilder.SaveXml($alarmFile)
Write-Host "  -> Saved: $alarmFile" -ForegroundColor Green

# -------------------------------------------------------------
# Verification Run
# -------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " RUNNING INTEGRITY VERIFICATION ON GENERATED XMLs" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$xmlFiles = @($recipeFile, $shiftFile, $alarmFile)
foreach ($xf in $xmlFiles) {
    Write-Host "`nVerifying $([System.IO.Path]::GetFileName($xf))..." -ForegroundColor DarkYellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verifierPath -XmlPath $xf
    if ($LASTEXITCODE -ne 0) {
        throw "Verification failed for $xf"
    }
}

Write-Host "`n[ALL DATA TABLE EXAMPLES GENERATED AND VERIFIED SUCCESSFULLY!]" -ForegroundColor Green
