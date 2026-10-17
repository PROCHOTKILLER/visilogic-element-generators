<#
.SYNOPSIS
    generate_hmi_examples.ps1 - Generates 4 diverse, production-ready HMI display packages (.vld)
    for Unitronics Vision V350 in distinct visual styles and industrial applications:
    1. Water Treatment & Pumping Station (ISA-101 High Performance Grayscale)
    2. HVAC Air Handling Unit (Modern Dark Industrial)
    3. Chemical Batch Reactor & Mixing (Process Schematic P&ID High Contrast)
    4. Cold Storage & Refrigeration (Clean Modular Grid)
#>

# Self-relaunch in 32-bit PowerShell (SysWOW64) for Microsoft.Jet.OLEDB.4.0 database driver
if ([IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $p = Start-Process -FilePath $sysWow64 -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$scriptDir = Split-Path -Parent $PSCommandPath
$hmiEngineDir = Join-Path $scriptDir "..\..\hmi-displays-generator"
. (Join-Path $hmiEngineDir "HmiDisplayBuilder.ps1")
$hmiTemplatesDir = Join-Path $hmiEngineDir "templates"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   UNITRONICS VISION HMI DISPLAY EXAMPLES GENERATOR (.VLD)            " -ForegroundColor Cyan
Write-Host "   Target: 4 Distinct Styles & Industrial Applications                " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. WATER TREATMENT & PUMPING STATION (ISA-101 High Performance Grayscale)
# ------------------------------------------------------------------------------
Write-Host "`n[1/4] Generating Water Treatment & Pumping Station HMI..." -ForegroundColor Yellow
$builder1 = [HmiDisplayBuilder]::new()
$builder1.Init($hmiTemplatesDir)

# Screen 1: Intake Overview
$p1_1 = $builder1.AddDisplay("1_Intake_Overview", $true)
$p1_1.AddRectangle(0, 0, 320, 24, [HmiColor]::DarkGray, [HmiColor]::Black) | Out-Null
$p1_1.AddLabel(10, 3, 300, 18, "PUMPING STATION - INTAKE OVERVIEW", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$p1_1.AddLabel(10, 30, 140, 18, "Wet Well Level:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p1_1.AddBargraph(10, 52, 140, 100, 10, "Well_Level", $builder1.BargraphPropertyBag) | Out-Null
$p1_1.AddNumericVariable(10, 156, 140, 22, 10, $false, "Level %", $builder1.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$p1_1.AddLabel(165, 30, 145, 18, "Discharge Pressure:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p1_1.AddNumericVariable(165, 50, 145, 22, 15, $false, "bar", $builder1.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$p1_1.AddLabel(165, 78, 145, 18, "System Flow Rate:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p1_1.AddNumericVariable(165, 98, 145, 22, 16, $false, "m3/h", $builder1.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$btP1 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("PUMP 1: STOPPED", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "PUMP 1: RUNNING", [HmiColor]::White, [HmiColor]::Green)
$p1_1.AddBinaryText(165, 126, 145, 24, [HmiOperandType]::MB, 10, $btP1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$btP2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("PUMP 2: STOPPED", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "PUMP 2: RUNNING", [HmiColor]::White, [HmiColor]::Green)
$p1_1.AddBinaryText(165, 154, 145, 24, [HmiOperandType]::MB, 11, $btP2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

# Navigation Bar
$p1_1.AddButton(5, 210, 100, 26, "Overview", 1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_1.AddJump(1, 1) | Out-Null
$p1_1.AddButton(110, 210, 100, 26, "Pumps", 2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_1.AddJump(2, 2) | Out-Null
$p1_1.AddButton(215, 210, 100, 26, "Alarms", 3, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_1.AddJump(3, 3) | Out-Null

# Screen 2: Pump Control
$p1_2 = $builder1.AddDisplay("2_Pump_Control", $false)
$p1_2.AddRectangle(0, 0, 320, 24, [HmiColor]::DarkGray, [HmiColor]::Black) | Out-Null
$p1_2.AddLabel(10, 3, 300, 18, "PUMPS - RUN HOURS & CONTROL", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$p1_2.AddLabel(10, 32, 140, 18, "Pump 1 Run Hours:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p1_2.AddNumericVariable(10, 52, 140, 24, 20, $false, "Hours", $builder1.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$p1_2.AddLabel(165, 32, 140, 18, "Pump 2 Run Hours:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p1_2.AddNumericVariable(165, 52, 140, 24, 21, $false, "Hours", $builder1.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$btLead = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("LEAD: PUMP 1", [HmiColor]::White, [HmiColor]::Blue, "LEAD: PUMP 2", [HmiColor]::White, [HmiColor]::Navy)
$p1_2.AddBinaryText(85, 86, 150, 26, [HmiOperandType]::MB, 15, $btLead, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p1_2.AddButton(10, 122, 140, 30, "START P1 MAN", 22, [HmiColor]::White, [HmiColor]::Green) | Out-Null
$p1_2.AddButton(10, 158, 140, 30, "STOP P1 MAN", 23, [HmiColor]::White, [HmiColor]::Red) | Out-Null
$p1_2.AddButton(165, 122, 140, 30, "START P2 MAN", 24, [HmiColor]::White, [HmiColor]::Green) | Out-Null
$p1_2.AddButton(165, 158, 140, 30, "STOP P2 MAN", 25, [HmiColor]::White, [HmiColor]::Red) | Out-Null

$p1_2.AddButton(5, 210, 100, 26, "Overview", 1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_2.AddJump(1, 1) | Out-Null
$p1_2.AddButton(110, 210, 100, 26, "Pumps", 2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_2.AddJump(2, 2) | Out-Null
$p1_2.AddButton(215, 210, 100, 26, "Alarms", 3, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_2.AddJump(3, 3) | Out-Null

# Screen 3: Alarms
$p1_3 = $builder1.AddDisplay("3_Alarms_Summary", $false)
$p1_3.AddRectangle(0, 0, 320, 24, [HmiColor]::DarkGray, [HmiColor]::Black) | Out-Null
$p1_3.AddLabel(10, 3, 300, 18, "ALARM SUMMARY & INTERLOCKS", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$btSpill = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("WET WELL LEVEL: NORMAL", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "HIGH LEVEL SPILL TRIP!", [HmiColor]::White, [HmiColor]::Red)
$p1_3.AddBinaryText(20, 35, 280, 26, [HmiOperandType]::MB, 30, $btSpill, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$btDry = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("DRY RUN SENSOR: OK", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "DRY RUN INTERLOCK ACTIVE!", [HmiColor]::White, [HmiColor]::Red)
$p1_3.AddBinaryText(20, 68, 280, 26, [HmiOperandType]::MB, 31, $btDry, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$btVfd1 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("VFD 1 DRIVE: HEALTHY", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "VFD 1 TRIP FAULT!", [HmiColor]::White, [HmiColor]::Red)
$p1_3.AddBinaryText(20, 101, 280, 26, [HmiOperandType]::MB, 32, $btVfd1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$btVfd2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("VFD 2 DRIVE: HEALTHY", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "VFD 2 TRIP FAULT!", [HmiColor]::White, [HmiColor]::Red)
$p1_3.AddBinaryText(20, 134, 280, 26, [HmiOperandType]::MB, 33, $btVfd2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p1_3.AddButton(80, 168, 160, 32, "ACKNOWLEDGE ALARMS", 35, [HmiColor]::Black, [HmiColor]::Yellow) | Out-Null

$p1_3.AddButton(5, 210, 100, 26, "Overview", 1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_3.AddJump(1, 1) | Out-Null
$p1_3.AddButton(110, 210, 100, 26, "Pumps", 2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_3.AddJump(2, 2) | Out-Null
$p1_3.AddButton(215, 210, 100, 26, "Alarms", 3, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p1_3.AddJump(3, 3) | Out-Null

$vldOutput1 = Join-Path $scriptDir "WATER_TREATMENT_PUMPING.vld"
$builder1.SaveVld($vldOutput1)
Write-Host "  -> Generated: $vldOutput1" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 2. HVAC AIR HANDLING UNIT (Modern Dark Industrial Style)
# ------------------------------------------------------------------------------
Write-Host "`n[2/4] Generating HVAC Air Handling Unit HMI (Dark Industrial)..." -ForegroundColor Yellow
$builder2 = [HmiDisplayBuilder]::new()
$builder2.Init($hmiTemplatesDir)

# Screen 1: AHU Synoptic
$p2_1 = $builder2.AddDisplay("1_AHU_Synoptic", $true)
$p2_1.AddRectangle(0, 0, 320, 240, [HmiColor]::DarkGray, [HmiColor]::DarkGray) | Out-Null
$p2_1.AddRectangle(0, 0, 320, 24, [HmiColor]::Black, [HmiColor]::DarkGray) | Out-Null
$p2_1.AddLabel(10, 3, 300, 18, "AHU-01 - MAIN SYNOPTIC OVERVIEW", [HmiColor]::Cyan, [HmiColor]::Transparent, 0) | Out-Null

$p2_1.AddLabel(10, 30, 95, 16, "SUPPLY TEMP", [HmiColor]::LightGray, [HmiColor]::Transparent, 0) | Out-Null
$p2_1.AddNumericVariable(10, 48, 95, 22, 20, $false, "C", $builder2.NumericPropertyBag, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$p2_1.AddLabel(112, 30, 95, 16, "RETURN TEMP", [HmiColor]::LightGray, [HmiColor]::Transparent, 0) | Out-Null
$p2_1.AddNumericVariable(112, 48, 95, 22, 21, $false, "C", $builder2.NumericPropertyBag, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$p2_1.AddLabel(215, 30, 95, 16, "OUTSIDE TEMP", [HmiColor]::LightGray, [HmiColor]::Transparent, 0) | Out-Null
$p2_1.AddNumericVariable(215, 48, 95, 22, 22, $false, "C", $builder2.NumericPropertyBag, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$btFanS = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("SUPPLY FAN: OFF", [HmiColor]::White, [HmiColor]::DarkGray, "SUPPLY FAN: ON", [HmiColor]::Black, [HmiColor]::Green)
$p2_1.AddBinaryText(10, 85, 145, 24, [HmiOperandType]::MB, 40, $btFanS, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

$btFanE = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("EXTRACT FAN: OFF", [HmiColor]::White, [HmiColor]::DarkGray, "EXTRACT FAN: ON", [HmiColor]::Black, [HmiColor]::Green)
$p2_1.AddBinaryText(165, 85, 145, 24, [HmiOperandType]::MB, 41, $btFanE, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

$btRot = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("HEAT WHEEL: OFF", [HmiColor]::White, [HmiColor]::DarkGray, "HEAT WHEEL: RUN", [HmiColor]::Black, [HmiColor]::Cyan)
$p2_1.AddBinaryText(85, 118, 150, 24, [HmiOperandType]::MB, 42, $btRot, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null

$p2_1.AddLabel(10, 152, 140, 16, "Heating Valve %:", [HmiColor]::Orange, [HmiColor]::Transparent, 0) | Out-Null
$p2_1.AddNumericVariable(10, 170, 140, 22, 26, $false, "%", $builder2.NumericPropertyBag, [HmiColor]::Orange, [HmiColor]::Black) | Out-Null

$p2_1.AddLabel(165, 152, 140, 16, "Cooling Valve %:", [HmiColor]::Cyan, [HmiColor]::Transparent, 0) | Out-Null
$p2_1.AddNumericVariable(165, 170, 140, 22, 27, $false, "%", $builder2.NumericPropertyBag, [HmiColor]::Cyan, [HmiColor]::Black) | Out-Null

$p2_1.AddButton(5, 210, 100, 26, "Synoptic", 4, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_1.AddJump(4, 1) | Out-Null
$p2_1.AddButton(110, 210, 100, 26, "PID Loops", 5, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_1.AddJump(5, 2) | Out-Null
$p2_1.AddButton(215, 210, 100, 26, "Filters/Safe", 6, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_1.AddJump(6, 3) | Out-Null

# Screen 2: PID Loops & Dampers
$p2_2 = $builder2.AddDisplay("2_AHU_Loops", $false)
$p2_2.AddRectangle(0, 0, 320, 240, [HmiColor]::DarkGray, [HmiColor]::DarkGray) | Out-Null
$p2_2.AddRectangle(0, 0, 320, 24, [HmiColor]::Black, [HmiColor]::DarkGray) | Out-Null
$p2_2.AddLabel(10, 3, 300, 18, "AHU-01 - PID LOOPS & DAMPERS", [HmiColor]::Cyan, [HmiColor]::Transparent, 0) | Out-Null

$p2_2.AddLabel(10, 35, 140, 18, "Temp Setpoint SP:", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null
$p2_2.AddNumericVariable(160, 32, 140, 24, 25, $true, "SP C", $builder2.NumericPropertyBag, [HmiColor]::Yellow, [HmiColor]::Black) | Out-Null

$p2_2.AddLabel(10, 70, 140, 18, "Fresh Air Damper %:", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null
$p2_2.AddNumericVariable(160, 68, 140, 24, 28, $true, "%", $builder2.NumericPropertyBag, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$p2_2.AddButton(10, 115, 95, 32, "AUTO MODE", 45, [HmiColor]::Black, [HmiColor]::Green) | Out-Null
$p2_2.AddButton(112, 115, 95, 32, "ECO MODE", 46, [HmiColor]::Black, [HmiColor]::Cyan) | Out-Null
$p2_2.AddButton(215, 115, 95, 32, "NIGHT OFF", 47, [HmiColor]::White, [HmiColor]::Navy) | Out-Null

$p2_2.AddButton(5, 210, 100, 26, "Synoptic", 4, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_2.AddJump(4, 1) | Out-Null
$p2_2.AddButton(110, 210, 100, 26, "PID Loops", 5, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_2.AddJump(5, 2) | Out-Null
$p2_2.AddButton(215, 210, 100, 26, "Filters/Safe", 6, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_2.AddJump(6, 3) | Out-Null

# Screen 3: Filter & Safety
$p2_3 = $builder2.AddDisplay("3_AHU_Safety", $false)
$p2_3.AddRectangle(0, 0, 320, 240, [HmiColor]::DarkGray, [HmiColor]::DarkGray) | Out-Null
$p2_3.AddRectangle(0, 0, 320, 24, [HmiColor]::Black, [HmiColor]::DarkGray) | Out-Null
$p2_3.AddLabel(10, 3, 300, 18, "AHU-01 - FILTERS & SAFETY INTERLOCKS", [HmiColor]::Cyan, [HmiColor]::Transparent, 0) | Out-Null

$p2_3.AddLabel(15, 35, 130, 16, "Supply Filter DP:", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null
$p2_3.AddNumericVariable(15, 54, 130, 22, 30, $false, "Pa", $builder2.NumericPropertyBag, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$p2_3.AddLabel(170, 35, 130, 16, "Extract Filter DP:", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null
$p2_3.AddNumericVariable(170, 54, 130, 22, 31, $false, "Pa", $builder2.NumericPropertyBag, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$btFrost = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("FROST THERMOSTAT: NORMAL", [HmiColor]::White, [HmiColor]::Black, "FROST ALARM ACTIVE!", [HmiColor]::White, [HmiColor]::Red)
$p2_3.AddBinaryText(15, 95, 290, 26, [HmiOperandType]::MB, 50, $btFrost, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$btFire = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("FIRE DAMPER: OK (OPEN)", [HmiColor]::White, [HmiColor]::Black, "FIRE ALARM / DAMPER TRIP!", [HmiColor]::White, [HmiColor]::Red)
$p2_3.AddBinaryText(15, 130, 290, 26, [HmiOperandType]::MB, 51, $btFire, [HmiColor]::White, [HmiColor]::Black) | Out-Null

$p2_3.AddButton(5, 210, 100, 26, "Synoptic", 4, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_3.AddJump(4, 1) | Out-Null
$p2_3.AddButton(110, 210, 100, 26, "PID Loops", 5, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_3.AddJump(5, 2) | Out-Null
$p2_3.AddButton(215, 210, 100, 26, "Filters/Safe", 6, [HmiColor]::White, [HmiColor]::DarkGray) | Out-Null
$p2_3.AddJump(6, 3) | Out-Null

$vldOutput2 = Join-Path $scriptDir "HVAC_AIR_HANDLING_UNIT.vld"
$builder2.SaveVld($vldOutput2)
Write-Host "  -> Generated: $vldOutput2" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 3. CHEMICAL BATCH REACTOR (Process Schematic P&ID Light Style)
# ------------------------------------------------------------------------------
Write-Host "`n[3/4] Generating Chemical Batch Reactor HMI (P&ID Light)..." -ForegroundColor Yellow
$builder3 = [HmiDisplayBuilder]::new()
$builder3.Init($hmiTemplatesDir)

# Screen 1: Vessel Overview
$p3_1 = $builder3.AddDisplay("1_Reactor_Vessel", $true)
$p3_1.AddRectangle(0, 0, 320, 24, [HmiColor]::Navy, [HmiColor]::Navy) | Out-Null
$p3_1.AddLabel(10, 3, 300, 18, "BATCH REACTOR R-101 - VESSEL", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$p3_1.AddRectangle(15, 35, 110, 160, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null
$p3_1.AddLabel(20, 40, 100, 16, "VESSEL R-101", [HmiColor]::Navy, [HmiColor]::Transparent, 0) | Out-Null
$p3_1.AddTank(25, 60, 90, 85, 40, "Level", $builder3.TankPropertyBag) | Out-Null
$p3_1.AddNumericVariable(25, 150, 90, 22, 40, $false, "kg", $builder3.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::White) | Out-Null

$p3_1.AddLabel(140, 35, 165, 18, "Jacket Temperature:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p3_1.AddNumericVariable(140, 55, 165, 22, 41, $false, "C", $builder3.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p3_1.AddLabel(140, 82, 165, 18, "Internal Pressure:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p3_1.AddNumericVariable(140, 102, 165, 22, 42, $false, "mbar", $builder3.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$btMixer = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("AGITATOR: STOPPED", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "AGITATOR: MIXING", [HmiColor]::White, [HmiColor]::Green)
$p3_1.AddBinaryText(140, 130, 165, 24, [HmiOperandType]::MB, 60, $btMixer, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p3_1.AddLabel(140, 158, 80, 18, "Speed RPM:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p3_1.AddNumericVariable(220, 156, 85, 22, 45, $false, "RPM", $builder3.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p3_1.AddButton(5, 210, 100, 26, "Vessel", 7, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_1.AddJump(7, 1) | Out-Null
$p3_1.AddButton(110, 210, 100, 26, "Dosing", 8, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_1.AddJump(8, 2) | Out-Null
$p3_1.AddButton(215, 210, 100, 26, "Safety", 9, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_1.AddJump(9, 3) | Out-Null

# Screen 2: Dosing & Valves
$p3_2 = $builder3.AddDisplay("2_Reactor_Dosing", $false)
$p3_2.AddRectangle(0, 0, 320, 24, [HmiColor]::Navy, [HmiColor]::Navy) | Out-Null
$p3_2.AddLabel(10, 3, 300, 18, "BATCH REACTOR R-101 - DOSING", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$btVa = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("VALVE A (SOLVENT): CLOSED", [HmiColor]::Black, [HmiColor]::LightGray, "VALVE A (SOLVENT): OPEN", [HmiColor]::White, [HmiColor]::Green)
$p3_2.AddBinaryText(15, 35, 290, 24, [HmiOperandType]::MB, 65, $btVa, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$btVb = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("VALVE B (CATALYST): CLOSED", [HmiColor]::Black, [HmiColor]::LightGray, "VALVE B (CATALYST): OPEN", [HmiColor]::White, [HmiColor]::Green)
$p3_2.AddBinaryText(15, 65, 290, 24, [HmiOperandType]::MB, 66, $btVb, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$btVd = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("BOTTOM DRAIN VALVE: CLOSED", [HmiColor]::Black, [HmiColor]::LightGray, "BOTTOM DRAIN VALVE: OPEN", [HmiColor]::White, [HmiColor]::Orange)
$p3_2.AddBinaryText(15, 95, 290, 24, [HmiOperandType]::MB, 67, $btVd, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$p3_2.AddLabel(15, 130, 140, 18, "Dosing Flow L/min:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p3_2.AddNumericVariable(165, 128, 140, 22, 50, $false, "L/min", $builder3.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p3_2.AddLabel(15, 160, 140, 18, "Active Recipe Phase:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p3_2.AddNumericVariable(165, 158, 140, 22, 52, $false, "Step", $builder3.NumericPropertyBag, [HmiColor]::Navy, [HmiColor]::ButtonGray) | Out-Null

$p3_2.AddButton(5, 210, 100, 26, "Vessel", 7, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_2.AddJump(7, 1) | Out-Null
$p3_2.AddButton(110, 210, 100, 26, "Dosing", 8, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_2.AddJump(8, 2) | Out-Null
$p3_2.AddButton(215, 210, 100, 26, "Safety", 9, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_2.AddJump(9, 3) | Out-Null

# Screen 3: Safety & Purge
$p3_3 = $builder3.AddDisplay("3_Reactor_Safety", $false)
$p3_3.AddRectangle(0, 0, 320, 24, [HmiColor]::Navy, [HmiColor]::Navy) | Out-Null
$p3_3.AddLabel(10, 3, 300, 18, "REACTOR R-101 - SAFETY INTERLOCKS", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$btDisk = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("RUPTURE DISK: INTACT", [HmiColor]::DarkGray, [HmiColor]::LightGray, "RUPTURE DISK BURST!", [HmiColor]::White, [HmiColor]::Red)
$p3_3.AddBinaryText(15, 38, 290, 26, [HmiOperandType]::MB, 70, $btDisk, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$btN2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("N2 PURGE BLANKET: PRESSURIZED", [HmiColor]::DarkGray, [HmiColor]::LightGray, "N2 BLANKET PRESSURE LOW!", [HmiColor]::White, [HmiColor]::Orange)
$p3_3.AddBinaryText(15, 72, 290, 26, [HmiOperandType]::MB, 71, $btN2, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$btSafe = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("TEMPERATURE LIMIT SWITCH: OK", [HmiColor]::DarkGray, [HmiColor]::LightGray, "HIGH TEMP SAFETY TRIP!", [HmiColor]::White, [HmiColor]::Red)
$p3_3.AddBinaryText(15, 106, 290, 26, [HmiOperandType]::MB, 72, $btSafe, [HmiColor]::Black, [HmiColor]::LightGray) | Out-Null

$p3_3.AddButton(60, 150, 200, 34, "EMERGENCY N2 DUMP", 75, [HmiColor]::White, [HmiColor]::Red) | Out-Null

$p3_3.AddButton(5, 210, 100, 26, "Vessel", 7, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_3.AddJump(7, 1) | Out-Null
$p3_3.AddButton(110, 210, 100, 26, "Dosing", 8, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_3.AddJump(8, 2) | Out-Null
$p3_3.AddButton(215, 210, 100, 26, "Safety", 9, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p3_3.AddJump(9, 3) | Out-Null

$vldOutput3 = Join-Path $scriptDir "CHEMICAL_BATCH_REACTOR.vld"
$builder3.SaveVld($vldOutput3)
Write-Host "  -> Generated: $vldOutput3" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 4. COLD STORAGE REFRIGERATION (Clean Modular Grid Style)
# ------------------------------------------------------------------------------
Write-Host "`n[4/4] Generating Cold Storage Refrigeration HMI (Modular Grid)..." -ForegroundColor Yellow
$builder4 = [HmiDisplayBuilder]::new()
$builder4.Init($hmiTemplatesDir)

# Screen 1: Zone Dashboard
$p4_1 = $builder4.AddDisplay("1_Cold_Dashboard", $true)
$p4_1.AddRectangle(0, 0, 320, 24, [HmiColor]::Blue, [HmiColor]::Blue) | Out-Null
$p4_1.AddLabel(10, 3, 300, 18, "COLD STORAGE - ZONE DASHBOARD", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

# Card Zone 1 (Deep Freeze)
$p4_1.AddRectangle(10, 32, 145, 125, [HmiColor]::DarkGray, [HmiColor]::LightGray) | Out-Null
$p4_1.AddLabel(15, 36, 135, 16, "ZONE 1 (FREEZER)", [HmiColor]::Navy, [HmiColor]::Transparent, 0) | Out-Null
$p4_1.AddLabel(15, 56, 135, 14, "Temperature:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p4_1.AddNumericVariable(15, 72, 135, 22, 60, $false, "-22 C", $builder4.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::White) | Out-Null
$btDoor1 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("DOOR: CLOSED", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "DOOR: OPEN!", [HmiColor]::White, [HmiColor]::Orange)
$p4_1.AddBinaryText(15, 100, 135, 22, [HmiOperandType]::MB, 80, $btDoor1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$btComp1 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("RACK 1: OFF", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "RACK 1: RUN", [HmiColor]::White, [HmiColor]::Green)
$p4_1.AddBinaryText(15, 126, 135, 22, [HmiOperandType]::MB, 85, $btComp1, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

# Card Zone 2 (Chiller)
$p4_1.AddRectangle(165, 32, 145, 125, [HmiColor]::DarkGray, [HmiColor]::LightGray) | Out-Null
$p4_1.AddLabel(170, 36, 135, 16, "ZONE 2 (CHILLER)", [HmiColor]::Navy, [HmiColor]::Transparent, 0) | Out-Null
$p4_1.AddLabel(170, 56, 135, 14, "Temperature:", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p4_1.AddNumericVariable(170, 72, 135, 22, 61, $false, "+4 C", $builder4.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::White) | Out-Null
$btDoor2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("DOOR: CLOSED", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "DOOR: OPEN!", [HmiColor]::White, [HmiColor]::Orange)
$p4_1.AddBinaryText(170, 100, 135, 22, [HmiOperandType]::MB, 81, $btDoor2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$btComp2 = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("RACK 2: OFF", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "RACK 2: RUN", [HmiColor]::White, [HmiColor]::Green)
$p4_1.AddBinaryText(170, 126, 135, 22, [HmiOperandType]::MB, 86, $btComp2, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p4_1.AddButton(10, 165, 145, 34, "FREEZER DEFROST", 95, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p4_1.AddButton(165, 165, 145, 34, "CHILLER DEFROST", 96, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p4_1.AddButton(20, 210, 130, 26, "Dashboard", 10, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p4_1.AddJump(10, 1) | Out-Null
$p4_1.AddButton(170, 210, 130, 26, "Defrost Timers", 11, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p4_1.AddJump(11, 2) | Out-Null

# Screen 2: Defrost Timers
$p4_2 = $builder4.AddDisplay("2_Cold_Defrost", $false)
$p4_2.AddRectangle(0, 0, 320, 24, [HmiColor]::Blue, [HmiColor]::Blue) | Out-Null
$p4_2.AddLabel(10, 3, 300, 18, "COLD STORAGE - DEFROST PARAMETERS", [HmiColor]::White, [HmiColor]::Transparent, 0) | Out-Null

$p4_2.AddLabel(15, 40, 150, 18, "Defrost Interval (h):", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p4_2.AddNumericVariable(175, 38, 130, 22, 65, $true, "Hours", $builder4.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::White) | Out-Null

$p4_2.AddLabel(15, 75, 150, 18, "Defrost Duration (min):", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p4_2.AddNumericVariable(175, 73, 130, 22, 66, $true, "Min", $builder4.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::White) | Out-Null

$p4_2.AddLabel(15, 110, 150, 18, "Drip / Fan Delay (min):", [HmiColor]::Black, [HmiColor]::Transparent, 0) | Out-Null
$p4_2.AddNumericVariable(175, 108, 130, 22, 67, $true, "Min", $builder4.NumericPropertyBag, [HmiColor]::Black, [HmiColor]::White) | Out-Null

$btDefActive = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("STATUS: COOLING ACTIVE", [HmiColor]::DarkGray, [HmiColor]::ButtonGray, "STATUS: DEFROST IN PROGRESS", [HmiColor]::White, [HmiColor]::Red)
$p4_2.AddBinaryText(20, 150, 280, 28, [HmiOperandType]::MB, 90, $btDefActive, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null

$p4_2.AddButton(20, 210, 130, 26, "Dashboard", 10, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p4_2.AddJump(10, 1) | Out-Null
$p4_2.AddButton(170, 210, 130, 26, "Defrost Timers", 11, [HmiColor]::Black, [HmiColor]::ButtonGray) | Out-Null
$p4_2.AddJump(11, 2) | Out-Null

$vldOutput4 = Join-Path $scriptDir "COLD_STORAGE_REFRIGERATION.vld"
$builder4.SaveVld($vldOutput4)
Write-Host "  -> Generated: $vldOutput4" -ForegroundColor Green

Write-Host "`nAll 4 HMI display packages generated successfully!" -ForegroundColor Cyan
exit 0
