<#
.SYNOPSIS
    generate_subroutine_examples.ps1 - Generates universal industrial ladder logic subroutine (.vlx)
    files for Unitronics Vision PLCs:
    1. PUMP_LEAD_LAG_ALTERNATION.vlx - Dual pump alternation on runtime & faults
    2. ANALOG_SCALING_ALARMS.vlx    - 4-20mA sensor scaling and Low/High limit alarm trips
    3. BATCH_STEP_SEQUENCER.vlx     - Step sequence state machine with dwell control
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
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$vlxEngineDir = Join-Path $repoRoot "subroutine-generator"
$vlxBuilderFile = Join-Path $vlxEngineDir "VlxBuilder.ps1"
$templateVlx = Join-Path $vlxEngineDir "templates\template.vlx"
$verifierScript = Join-Path $vlxEngineDir "verify_vlx.ps1"

if (-not (Test-Path $vlxBuilderFile)) {
    throw "VlxBuilder.ps1 not found at: $vlxBuilderFile"
}
if (-not (Test-Path $templateVlx)) {
    throw "template.vlx not found at: $templateVlx"
}

. $vlxBuilderFile

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   UNITRONICS VISION SUBROUTINE EXAMPLES GENERATOR (.VLX)             " -ForegroundColor Cyan
Write-Host "   Applications: Pump Alternation, Analog Scaling, Step Sequencer      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. PUMP_LEAD_LAG_ALTERNATION.vlx
# ------------------------------------------------------------------------------
Write-Host "`n[1/3] Building Subroutine: PUMP_LEAD_LAG_ALTERNATION.vlx..." -ForegroundColor Yellow
$pumpVlx = Join-Path $scriptDir "PUMP_LEAD_LAG_ALTERNATION.vlx"
Copy-Item -Path $templateVlx -Destination $pumpVlx -Force

$builder1 = [VlxBuilder]::new($pumpVlx, "PumpLeadLag")
$builder1.Open()

# Rung 1: Station Permissive (MB0 Auto Mode AND NOT MB10 Dry Run -> MB20 Permissive)
$s1 = $builder1.AddStrip("Rung 1: Dual Pump Enable Permissive Check")
$builder1.AddContact($s1, 0, 4, [VlxOperandTypes]::MB, 0, [VlxOpcodes]::CONTACT_NO)
$builder1.AddWire($s1, 6, 4, 4, 0)
$builder1.AddContact($s1, 10, 4, [VlxOperandTypes]::MB, 10, [VlxOpcodes]::CONTACT_NC)
$builder1.AddWire($s1, 16, 4, 58, 0)
$builder1.AddCoil($s1, 74, 4, [VlxOperandTypes]::MB, 20, [VlxOpcodes]::COIL_DIRECT)

# Rung 2: Lead/Lag Toggle on Demand Pulse (MB20 Permissive AND MB21 Pulse -> Toggle MB22 Lead Select)
$s2 = $builder1.AddStrip("Rung 2: Duty Cycle Lead/Lag Toggle Trigger")
$builder1.AddContact($s2, 0, 4, [VlxOperandTypes]::MB, 20, [VlxOpcodes]::CONTACT_NO)
$builder1.AddWire($s2, 6, 4, 4, 0)
$builder1.AddContact($s2, 10, 4, [VlxOperandTypes]::MB, 21, [VlxOpcodes]::CONTACT_P)
$builder1.AddWire($s2, 16, 4, 58, 0)
$builder1.AddCoil($s2, 74, 4, [VlxOperandTypes]::MB, 22, [VlxOpcodes]::COIL_TOGGLE)

# Rung 3: Pump 1 Run Command (MB20 Permissive AND NOT MB22 Lead Select AND NOT MB6 Fault -> O0 Run)
$s3 = $builder1.AddStrip("Rung 3: Pump 1 Contactor Run Command")
$builder1.AddContact($s3, 0, 4, [VlxOperandTypes]::MB, 20, [VlxOpcodes]::CONTACT_NO)
$builder1.AddWire($s3, 6, 4, 4, 0)
$builder1.AddContact($s3, 10, 4, [VlxOperandTypes]::MB, 22, [VlxOpcodes]::CONTACT_NC)
$builder1.AddWire($s3, 16, 4, 4, 0)
$builder1.AddContact($s3, 20, 4, [VlxOperandTypes]::MB, 6, [VlxOpcodes]::CONTACT_NC)
$builder1.AddWire($s3, 26, 4, 48, 0)
$builder1.AddCoil($s3, 74, 4, [VlxOperandTypes]::O, 0, [VlxOpcodes]::COIL_DIRECT)

# Rung 4: Pump 2 Run Command (MB20 Permissive AND MB22 Lead Select AND NOT MB7 Fault -> O1 Run)
$s4 = $builder1.AddStrip("Rung 4: Pump 2 Contactor Run Command")
$builder1.AddContact($s4, 0, 4, [VlxOperandTypes]::MB, 20, [VlxOpcodes]::CONTACT_NO)
$builder1.AddWire($s4, 6, 4, 4, 0)
$builder1.AddContact($s4, 10, 4, [VlxOperandTypes]::MB, 22, [VlxOpcodes]::CONTACT_NO)
$builder1.AddWire($s4, 16, 4, 4, 0)
$builder1.AddContact($s4, 20, 4, [VlxOperandTypes]::MB, 7, [VlxOpcodes]::CONTACT_NC)
$builder1.AddWire($s4, 26, 4, 48, 0)
$builder1.AddCoil($s4, 74, 4, [VlxOperandTypes]::O, 1, [VlxOpcodes]::COIL_DIRECT)

$builder1.AddReturnStrip()
$builder1.SaveOperands()
$builder1.Close()
Write-Host "  -> Generated successfully: $pumpVlx" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 2. ANALOG_SCALING_ALARMS.vlx
# ------------------------------------------------------------------------------
Write-Host "`n[2/3] Building Subroutine: ANALOG_SCALING_ALARMS.vlx..." -ForegroundColor Yellow
$analogVlx = Join-Path $scriptDir "ANALOG_SCALING_ALARMS.vlx"
Copy-Item -Path $templateVlx -Destination $analogVlx -Force

$builder2 = [VlxBuilder]::new($analogVlx, "AnalogScaling")
$builder2.Open()

# Rung 1: Linearize 4-20mA sensor: MI0 (0..4095) -> MI10 (0..500 cm)
$s1 = $builder2.AddStrip("Rung 1: Linear Scaling 4-20mA Transmitter (0..4095 to 0..500 cm)")
$builder2.AddContact($s1, 0, 4, [VlxOperandTypes]::SB, 2, [VlxOpcodes]::CONTACT_NO)
$builder2.AddWire($s1, 6, 4, 4, 0)
$builder2.AddLinearize($s1, 10, 4, [VlxOperandTypes]::MI, 0, "0", "0", "4095", "500", [VlxOperandTypes]::MI, 10)
$builder2.AddWire($s1, 27, 4, 47, 0)
$builder2.AddCoil($s1, 74, 4, [VlxOperandTypes]::MB, 30, [VlxOpcodes]::COIL_DIRECT)

# Rung 2: Low-Low Suction Alarm: If MI10 < 50 cm -> Set MB8
$s2 = $builder2.AddStrip("Rung 2: Low-Low Level Trip Alarm (Level < 50 cm)")
$builder2.AddContact($s2, 0, 4, [VlxOperandTypes]::MB, 30, [VlxOpcodes]::CONTACT_NO)
$builder2.AddWire($s2, 6, 4, 4, 0)
$builder2.AddCompare($s2, 10, 4, [VlxOpcodes]::CMP_LT, [VlxOperandTypes]::MI, 10, "", [VlxOperandTypes]::CONST, 0, "50")
$builder2.AddWire($s2, 23, 4, 51, 0)
$builder2.AddCoil($s2, 74, 4, [VlxOperandTypes]::MB, 8, [VlxOpcodes]::COIL_SET)

# Rung 3: High-High Basin Alarm: If MI10 > 450 cm -> Set MB9
$s3 = $builder2.AddStrip("Rung 3: High-High Level Trip Alarm (Level > 450 cm)")
$builder2.AddContact($s3, 0, 4, [VlxOperandTypes]::MB, 30, [VlxOpcodes]::CONTACT_NO)
$builder2.AddWire($s3, 6, 4, 4, 0)
$builder2.AddCompare($s3, 10, 4, [VlxOpcodes]::CMP_GT, [VlxOperandTypes]::MI, 10, "", [VlxOperandTypes]::CONST, 0, "450")
$builder2.AddWire($s3, 23, 4, 51, 0)
$builder2.AddCoil($s3, 74, 4, [VlxOperandTypes]::MB, 9, [VlxOpcodes]::COIL_SET)

$builder2.AddReturnStrip()
$builder2.SaveOperands()
$builder2.Close()
Write-Host "  -> Generated successfully: $analogVlx" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 3. BATCH_STEP_SEQUENCER.vlx
# ------------------------------------------------------------------------------
Write-Host "`n[3/3] Building Subroutine: BATCH_STEP_SEQUENCER.vlx..." -ForegroundColor Yellow
$batchVlx = Join-Path $scriptDir "BATCH_STEP_SEQUENCER.vlx"
Copy-Item -Path $templateVlx -Destination $batchVlx -Force

$builder3 = [VlxBuilder]::new($batchVlx, "BatchSequencer")
$builder3.Open()

# Rung 1: Batch Start Trigger -> Store 1 to MI21 and Set MB3 In Progress
$s1 = $builder3.AddStrip("Rung 1: Initialize Batch State Machine (Start -> Step 1)")
$builder3.AddContact($s1, 0, 4, [VlxOperandTypes]::MB, 0, [VlxOpcodes]::CONTACT_P)
$builder3.AddWire($s1, 6, 4, 4, 0)
$builder3.AddStore($s1, 10, 4, [VlxOperandTypes]::CONST, 0, "1", [VlxOperandTypes]::MI, 21)
$builder3.AddWire($s1, 23, 4, 51, 0)
$builder3.AddCoil($s1, 74, 4, [VlxOperandTypes]::MB, 3, [VlxOpcodes]::COIL_SET)

# Rung 2: Advance Step on Phase Complete Flag -> Increment MI21 and Reset MB4
$s2 = $builder3.AddStrip("Rung 2: Step Increment on Phase Complete")
$builder3.AddContact($s2, 0, 4, [VlxOperandTypes]::MB, 4, [VlxOpcodes]::CONTACT_P)
$builder3.AddWire($s2, 6, 4, 4, 0)
$builder3.AddContact($s2, 10, 4, [VlxOperandTypes]::MB, 3, [VlxOpcodes]::CONTACT_NO)
$builder3.AddWire($s2, 16, 4, 4, 0)
$builder3.AddInc($s2, 20, 4, [VlxOperandTypes]::MI, 21)
$builder3.AddWire($s2, 33, 4, 41, 0)
$builder3.AddCoil($s2, 74, 4, [VlxOperandTypes]::MB, 4, [VlxOpcodes]::COIL_RESET)

# Rung 3: Sequence Complete (If Step >= 5 -> Reset MB3 In Progress)
$s3 = $builder3.AddStrip("Rung 3: Sequence Finalization (Step >= 5 -> Reset Active Flag)")
$builder3.AddContact($s3, 0, 4, [VlxOperandTypes]::MB, 3, [VlxOpcodes]::CONTACT_NO)
$builder3.AddWire($s3, 6, 4, 4, 0)
$builder3.AddCompare($s3, 10, 4, [VlxOpcodes]::CMP_GE, [VlxOperandTypes]::MI, 21, "", [VlxOperandTypes]::CONST, 0, "5")
$builder3.AddWire($s3, 23, 4, 51, 0)
$builder3.AddCoil($s3, 74, 4, [VlxOperandTypes]::MB, 3, [VlxOpcodes]::COIL_RESET)

$builder3.AddReturnStrip()
$builder3.SaveOperands()
$builder3.Close()
Write-Host "  -> Generated successfully: $batchVlx" -ForegroundColor Green

# ------------------------------------------------------------------------------
# Verification Run
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host " RUNNING INTEGRITY VERIFICATION ON GENERATED VLX SUBROUTINES           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

& powershell -NoProfile -ExecutionPolicy Bypass -File $verifierScript -TargetPath $scriptDir
if ($LASTEXITCODE -ne 0) {
    throw "Verification failed for one or more VLX files!"
}

Write-Host "`n[ALL SUBROUTINE EXAMPLES GENERATED AND VERIFIED SUCCESSFULLY!]" -ForegroundColor Green
