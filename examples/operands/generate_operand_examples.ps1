<#
.SYNOPSIS
    generate_operand_examples.ps1 - Generates universal industrial operands.csv files
    for Unitronics VisiLogic (Water Treatment, HVAC, Batch Chemical Reactor).
#>

[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$builderPath = Join-Path $repoRoot "operands-generator\OperandsBuilder.ps1"
$verifierPath = Join-Path $repoRoot "operands-generator\verify_operands.ps1"
$templatePath = Join-Path $repoRoot "operands-generator\templates\template_operands.csv"

if (-not (Test-Path $builderPath)) {
    throw "OperandsBuilder.ps1 not found at: $builderPath"
}
if (-not (Test-Path $templatePath)) {
    throw "template_operands.csv not found at: $templatePath"
}

. $builderPath

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VISILOGIC OPERANDS GENERATOR - EXAMPLES SUITE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. WATER_TREATMENT_OPERANDS.csv
# -------------------------------------------------------------
Write-Host "`n[1/3] Generating Water Treatment Operands..." -ForegroundColor Yellow
$waterCsv = Join-Path $scriptDir "WATER_TREATMENT_OPERANDS.csv"
$waterBuilder = [OperandsBuilder]::new()
$waterBuilder.LoadTemplate($templatePath)

# Inputs
$waterBuilder.SetOperand("I", 0, "LS_INTAKE_WELL_LOW")
$waterBuilder.SetOperand("I", 1, "LS_INTAKE_WELL_HIGH")
$waterBuilder.SetOperand("I", 2, "PUMP1_THERMAL_OK")
$waterBuilder.SetOperand("I", 3, "PUMP2_THERMAL_OK")
$waterBuilder.SetOperand("I", 4, "FLOW_SWITCH_DISCHARGE")
$waterBuilder.SetOperand("I", 5, "EMERGENCY_STOP_PB")

# Outputs
$waterBuilder.SetOperand("O", 0, "PUMP1_CONTACTOR_CMD")
$waterBuilder.SetOperand("O", 1, "PUMP2_CONTACTOR_CMD")
$waterBuilder.SetOperand("O", 2, "INLET_VALVE_SOLENOID")
$waterBuilder.SetOperand("O", 3, "CHLORINE_DOSING_PUMP")
$waterBuilder.SetOperand("O", 4, "HORN_ALARM_BEACON")

# Memory Bits (MB)
$waterBuilder.SetOperand("MB", 0, "SYS_AUTO_MODE")
$waterBuilder.SetOperand("MB", 1, "SYS_MANUAL_MODE")
$waterBuilder.SetOperand("MB", 2, "PUMP1_AUTO_REQ")
$waterBuilder.SetOperand("MB", 3, "PUMP2_AUTO_REQ")
$waterBuilder.SetOperand("MB", 4, "PUMP1_RUNNING")
$waterBuilder.SetOperand("MB", 5, "PUMP2_RUNNING")
$waterBuilder.SetOperand("MB", 6, "PUMP1_FAULT")
$waterBuilder.SetOperand("MB", 7, "PUMP2_FAULT")
$waterBuilder.SetOperand("MB", 8, "ALARM_LOW_SUCTION")
$waterBuilder.SetOperand("MB", 9, "ALARM_HIGH_DISCHARGE")
$waterBuilder.SetOperand("MB", 10, "ALARM_DRY_RUN")
$waterBuilder.SetOperand("MB", 11, "ALARM_ACK_CMD")

# Memory Integers (MI)
$waterBuilder.SetOperand("MI", 0, "AI_INTAKE_LEVEL_RAW")
$waterBuilder.SetOperand("MI", 1, "AI_DISCHARGE_PRESS_RAW")
$waterBuilder.SetOperand("MI", 2, "AI_FLOW_RATE_RAW")
$waterBuilder.SetOperand("MI", 10, "INTAKE_LEVEL_CM")
$waterBuilder.SetOperand("MI", 11, "DISCHARGE_PRESS_BAR_X10")
$waterBuilder.SetOperand("MI", 12, "FLOW_RATE_M3H_X10")
$waterBuilder.SetOperand("MI", 20, "SP_START_LEVEL_CM")
$waterBuilder.SetOperand("MI", 21, "SP_STOP_LEVEL_CM")
$waterBuilder.SetOperand("MI", 22, "SP_LAG_START_LEVEL_CM")
$waterBuilder.SetOperand("MI", 30, "PUMP1_DUTY_HOURS")
$waterBuilder.SetOperand("MI", 31, "PUMP2_DUTY_HOURS")

# Memory Longs (ML)
$waterBuilder.SetOperand("ML", 0, "TOTAL_VOLUME_M3")

# Timers (T)
$waterBuilder.SetOperand("T", 0, "TMR_PUMP_STAGGER_DELAY")
$waterBuilder.SetOperand("T", 1, "TMR_LOW_LEVEL_PERSIST")

$waterBuilder.SaveToCsv($waterCsv)
Write-Host "  -> Saved: $waterCsv" -ForegroundColor Green

# -------------------------------------------------------------
# 2. HVAC_SYSTEM_OPERANDS.csv
# -------------------------------------------------------------
Write-Host "`n[2/3] Generating HVAC System Operands..." -ForegroundColor Yellow
$hvacCsv = Join-Path $scriptDir "HVAC_SYSTEM_OPERANDS.csv"
$hvacBuilder = [OperandsBuilder]::new()
$hvacBuilder.LoadTemplate($templatePath)

# Inputs
$hvacBuilder.SetOperand("I", 0, "FREEZE_STAT_CONTACT")
$hvacBuilder.SetOperand("I", 1, "FIRE_SMOKE_DETECTOR")
$hvacBuilder.SetOperand("I", 2, "SUPPLY_FAN_DP_SWITCH")
$hvacBuilder.SetOperand("I", 3, "EXHAUST_FAN_DP_SWITCH")
$hvacBuilder.SetOperand("I", 4, "FILTER_DP_HIGH_SWITCH")

# Outputs
$hvacBuilder.SetOperand("O", 0, "SUPPLY_FAN_VFD_ENABLE")
$hvacBuilder.SetOperand("O", 1, "EXHAUST_FAN_VFD_ENABLE")
$hvacBuilder.SetOperand("O", 2, "HEATING_VALVE_ACTUATOR")
$hvacBuilder.SetOperand("O", 3, "COOLING_DX_STAGE_1")
$hvacBuilder.SetOperand("O", 4, "COOLING_DX_STAGE_2")

# Memory Bits (MB)
$hvacBuilder.SetOperand("MB", 0, "AHU_OCCUPIED_CMD")
$hvacBuilder.SetOperand("MB", 1, "AHU_FAN_RUN_STATUS")
$hvacBuilder.SetOperand("MB", 2, "AHU_FREEZE_TRIP")
$hvacBuilder.SetOperand("MB", 3, "AHU_FIRE_TRIP")
$hvacBuilder.SetOperand("MB", 4, "FILTER_DIRTY_ALARM")
$hvacBuilder.SetOperand("MB", 5, "ECONOMIZER_FREE_COOL_EN")

# Memory Integers (MI)
$hvacBuilder.SetOperand("MI", 0, "AI_SUPPLY_TEMP_RAW")
$hvacBuilder.SetOperand("MI", 1, "AI_RETURN_TEMP_RAW")
$hvacBuilder.SetOperand("MI", 2, "AI_OUTSIDE_AIR_TEMP_RAW")
$hvacBuilder.SetOperand("MI", 3, "AI_DUCT_STATIC_PRESS_RAW")
$hvacBuilder.SetOperand("MI", 10, "SUPPLY_TEMP_C_X10")
$hvacBuilder.SetOperand("MI", 11, "RETURN_TEMP_C_X10")
$hvacBuilder.SetOperand("MI", 12, "OUTSIDE_AIR_TEMP_C_X10")
$hvacBuilder.SetOperand("MI", 13, "DUCT_STATIC_PRESS_PA")
$hvacBuilder.SetOperand("MI", 20, "SP_SUPPLY_TEMP_C_X10")
$hvacBuilder.SetOperand("MI", 21, "SP_DUCT_PRESS_PA")
$hvacBuilder.SetOperand("MI", 30, "PID_HEAT_OUTPUT_PCT")
$hvacBuilder.SetOperand("MI", 31, "PID_COOL_OUTPUT_PCT")
$hvacBuilder.SetOperand("MI", 32, "DAMPER_OUTSIDE_AIR_PCT")

# Timers (T)
$hvacBuilder.SetOperand("T", 0, "TMR_FAN_SPIN_UP")
$hvacBuilder.SetOperand("T", 1, "TMR_STAGE_RECYCLE_DELAY")

$hvacBuilder.SaveToCsv($hvacCsv)
Write-Host "  -> Saved: $hvacCsv" -ForegroundColor Green

# -------------------------------------------------------------
# 3. BATCH_REACTOR_OPERANDS.csv
# -------------------------------------------------------------
Write-Host "`n[3/3] Generating Chemical Batch Reactor Operands..." -ForegroundColor Yellow
$batchCsv = Join-Path $scriptDir "BATCH_REACTOR_OPERANDS.csv"
$batchBuilder = [OperandsBuilder]::new()
$batchBuilder.LoadTemplate($templatePath)

# Inputs
$batchBuilder.SetOperand("I", 0, "REACTOR_LID_CLOSED_LS")
$batchBuilder.SetOperand("I", 1, "EMERGENCY_VENT_VALVE_OPEN")
$batchBuilder.SetOperand("I", 2, "AGITATOR_VFD_FAULT")
$batchBuilder.SetOperand("I", 3, "HIGH_HIGH_LEVEL_FLOAT")

# Outputs
$batchBuilder.SetOperand("O", 0, "AGITATOR_MOTOR_RUN")
$batchBuilder.SetOperand("O", 1, "ACID_FEED_PUMP_RUN")
$batchBuilder.SetOperand("O", 2, "SOLVENT_FEED_VALVE")
$batchBuilder.SetOperand("O", 3, "STEAM_JACKET_VALVE")
$batchBuilder.SetOperand("O", 4, "COOLING_WATER_VALVE")
$batchBuilder.SetOperand("O", 5, "BOTTOM_DRAIN_VALVE")

# Memory Bits (MB)
$batchBuilder.SetOperand("MB", 0, "BATCH_SEQ_START")
$batchBuilder.SetOperand("MB", 1, "BATCH_SEQ_PAUSE")
$batchBuilder.SetOperand("MB", 2, "BATCH_SEQ_ABORT")
$batchBuilder.SetOperand("MB", 3, "BATCH_IN_PROGRESS")
$batchBuilder.SetOperand("MB", 4, "BATCH_PHASE_COMPLETE")
$batchBuilder.SetOperand("MB", 5, "ALARM_EXOTHERM_HIGH")
$batchBuilder.SetOperand("MB", 6, "ALARM_PRESSURE_HIGH")

# Memory Integers (MI)
$batchBuilder.SetOperand("MI", 0, "AI_VESSEL_TEMP_RAW")
$batchBuilder.SetOperand("MI", 1, "AI_JACKET_TEMP_RAW")
$batchBuilder.SetOperand("MI", 2, "AI_VESSEL_PRESS_RAW")
$batchBuilder.SetOperand("MI", 3, "AI_VESSEL_WEIGHT_RAW")
$batchBuilder.SetOperand("MI", 10, "VESSEL_TEMP_C_X10")
$batchBuilder.SetOperand("MI", 11, "JACKET_TEMP_C_X10")
$batchBuilder.SetOperand("MI", 12, "VESSEL_PRESS_MBAR")
$batchBuilder.SetOperand("MI", 13, "VESSEL_WEIGHT_KG")
$batchBuilder.SetOperand("MI", 20, "ACTIVE_RECIPE_ID")
$batchBuilder.SetOperand("MI", 21, "ACTIVE_STEP_NUMBER")
$batchBuilder.SetOperand("MI", 22, "AGITATOR_SPEED_RPM")
$batchBuilder.SetOperand("MI", 23, "SP_AGITATOR_RPM")

# Memory Longs (ML)
$batchBuilder.SetOperand("ML", 0, "STEP_ELAPSED_SEC")
$batchBuilder.SetOperand("ML", 1, "STEP_TARGET_SEC")
$batchBuilder.SetOperand("ML", 2, "TOTAL_DOSING_PULSES")

# Timers (T)
$batchBuilder.SetOperand("T", 0, "TMR_REACTION_DWELL")
$batchBuilder.SetOperand("T", 1, "TMR_PURGE_NITROGEN")

$batchBuilder.SaveToCsv($batchCsv)
Write-Host "  -> Saved: $batchCsv" -ForegroundColor Green

# -------------------------------------------------------------
# Verification Run
# -------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " RUNNING INTEGRITY VERIFICATION ON GENERATED CSVs" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$csvFiles = @($waterCsv, $hvacCsv, $batchCsv)
foreach ($cf in $csvFiles) {
    Write-Host "`nVerifying $([System.IO.Path]::GetFileName($cf))..." -ForegroundColor DarkYellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verifierPath -CsvPath $cf
    if ($LASTEXITCODE -ne 0) {
        throw "Verification failed for $cf"
    }
}

Write-Host "`n[ALL OPERAND EXAMPLES GENERATED AND VERIFIED SUCCESSFULLY!]" -ForegroundColor Green
