# Unitronics VisiLogic Elements Showcase & Examples Suite

This directory contains production-ready, verified example assets for Unitronics Vision PLCs (V350, V120, V570, Samba). All files are categorized into dedicated subdirectories and cover diverse industrial automation applications:

```text
examples/
├── hmi-displays/         # Color HMI Display Packages (*.vld)
├── data-tables/          # Database Structure Files (*.xml)
├── operands/             # Operand Symbol Tables (*.csv)
├── subroutines/          # Ladder Logic Subroutine Packages (*.vlx)
├── generate_all_examples.ps1 # One-click Master Generator & Validator
└── README.md             # This Documentation
```

---

## 1. Directory Breakdown

### 🎨 [HMI Displays (`examples/hmi-displays/`)](hmi-displays/README.md)
Contains 4 distinct graphical styles for 320x240 QVGA color screens:
- `WATER_TREATMENT_PUMPING.vld`: **ISA-101 High Performance Grayscale** (Situational awareness, muted background, high-visibility alarm accents).
- `HVAC_AIR_HANDLING_UNIT.vld`: **Modern Dark Industrial** (Low-glare slate theme, vibrant neon telemetry).
- `CHEMICAL_BATCH_REACTOR.vld`: **Process Schematic P&ID Light** (High-contrast piping & instrumentation diagram style).
- `COLD_STORAGE_REFRIGERATION.vld`: **Clean Modular Grid** (Card-based quick-glance status monitoring).

### 📊 [Data Tables (`examples/data-tables/`)](data-tables/README.md)
Contains XML relational table schemas validated against native COM `UnPlcDB1.clsDBServices`:
- `CHEMICAL_BATCH_RECIPES.xml`: Multi-step batch recipe management (`Recipe_Headers` + `Recipe_Steps`).
- `SHIFT_PRODUCTION_LOG.xml`: 24-shift circular logger for units produced, rejects, uptime, and energy consumption.
- `ALARM_AUDIT_TRAIL.xml`: 100-event historical alarm and audit log with timestamp, severity, and tag identification.

### 🏷️ [Operands (`examples/operands/`)](operands/README.md)
Contains fully formatted 8,193-row CSV operand symbol tables:
- `WATER_TREATMENT_OPERANDS.csv`: Pump station digital I/O, auto/manual flags, analog levels/pressures, and stagger timers.
- `HVAC_SYSTEM_OPERANDS.csv`: Safety freeze/fire inputs, VFD outputs, PID control loops, and temperature sensors.
- `BATCH_REACTOR_OPERANDS.csv`: Vessel weight, reactor temperature, jacket cooling, agitator speed, and dwell timers.

### 🪜 [Subroutines (`examples/subroutines/`)](subroutines/README.md)
Contains pre-compiled ladder logic `.vlx` subroutines with strict grid geometry and zero relational NULLs:
- `PUMP_LEAD_LAG_ALTERNATION.vlx`: Dual pump duty alternation on runtime & fault bypass.
- `ANALOG_SCALING_ALARMS.vlx`: 4-20mA sensor linear scaling (`Linearize 1300`) and Low-Low / High-High alarm trips.
- `BATCH_STEP_SEQUENCER.vlx`: Batch state machine with step initialization, pulse advance, and sequence completion.

---

## One-Click Master Generation & Verification

To recompile and run full integrity checks on all examples in all 4 categories, simply execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_all_examples.ps1
```

The script automatically manages 32-bit (SysWOW64) execution for Microsoft Jet 4.0 database drivers, verifies all files against their respective native VisiLogic validators, and reports comprehensive status.
