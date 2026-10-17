# Visilogic HMI Displays Showcase & Examples

This directory contains pre-generated `.vld` display export packages for Unitronics Vision PLCs (320x240 QVGA color HMI display resolution), showcasing different industrial design styles and real-world automation applications.

## Generated Examples Overview

| File | Application | Visual Style | Displays | Controls | Features |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `WATER_TREATMENT_PUMPING.vld` | Water Intake & Pumping Station | **ISA-101 High Performance** | 3 | 38 | Grayscale background, situational awareness, alarm priority accents, vertical level tanks, intake flow rates |
| `HVAC_AIR_HANDLING_UNIT.vld` | Commercial AHU & Climate Control | **Modern Dark Industrial** | 3 | 44 | Dark slate background, vibrant neon status indicators, temperature/humidity loops, freeze protection alarms |
| `CHEMICAL_BATCH_REACTOR.vld` | Chemical Dosing & Mixing Vessel | **Process Schematic P&ID** | 3 | 37 | Clean schematic layout, agitator RPM bar graphs, dosing pumps, emergency drain interlocks |
| `COLD_STORAGE_REFRIGERATION.vld` | Industrial Cold Storage & Chiller | **Clean Modular Grid** | 2 | 29 | High contrast grid, compressor duty cycling, defrost staging, defrost countdown timer |

---

## Visual Design Styles & Palette Profiles

### 1. ISA-101 High Performance Grayscale (`WATER_TREATMENT_PUMPING.vld`)
- **Background:** `0xD6D6D6` (Neutral Light Gray)
- **Philosophy:** Following ANSI/ISA-101 standards, normal operations use muted grays and neutrals. Color is strictly reserved for abnormal process conditions and critical alarms (Yellow for Warning, Red for High Alarm).
- **Key Displays:**
  1. `1_Intake_Overview`: Overall station status, intake basin level tank, total station discharge flow.
  2. `2_Pump_Control`: Dual booster pump speeds, operating hours, manual/auto selector switches.
  3. `3_Alarms_Summary`: Active alarms table, station low suction alarm, emergency isolation valve.

### 2. Modern Dark Industrial (`HVAC_AIR_HANDLING_UNIT.vld`)
- **Background:** `0x1E222A` (Dark Charcoal / Slate)
- **Philosophy:** High-contrast dark theme optimized for reduced operator glare in low-light control rooms. Bright cyan, emerald, and amber accent colors highlight running components and measurement values.
- **Key Displays:**
  1. `1_AHU_Synoptic`: Air flow synoptic diagram showing supply/return fan statuses, filter delta P, damper positions.
  2. `2_AHU_Loops`: Heating & cooling PID loop outputs, supply temp setpoints, relative humidity.
  3. `3_AHU_Safety`: Freeze stat protection, fire damper trip status, emergency shutdown pushbuttons.

### 3. Process Schematic P&ID Light (`CHEMICAL_BATCH_REACTOR.vld`)
- **Background:** `0xF4F6F9` (P&ID Engineering Off-White)
- **Philosophy:** Mimics standard piping and instrumentation diagrams (P&ID) with high readability for process engineers and operators.
- **Key Displays:**
  1. `1_Reactor_Vessel`: Vessel fluid level tank indicator, internal temperature, agitator motor status and RPM.
  2. `2_Reactor_Dosing`: Acid and solvent dosing pump flow rates, totalizer counters, recipe batch status.
  3. `3_Reactor_Safety`: Overpressure relief status, emergency nitrogen purge, reactor jacket cooling valve.

### 4. Clean Modular Grid (`COLD_STORAGE_REFRIGERATION.vld`)
- **Background:** `0xEBF2F8` (Cool Ice Gray-Blue)
- **Philosophy:** Modular tile/grid layout providing fast glanceable telemetry for multi-zone refrigeration systems.
- **Key Displays:**
  1. `1_Cold_Dashboard`: Room air temperatures, suction/discharge pressures, compressor rack operating state.
  2. `2_Cold_Defrost`: Electric defrost heater staging, evaporator defrost countdown timer, coil temperatures.

---

## How to Import into VisiLogic

1. Open your project in **Unitronics VisiLogic**.
2. In the project tree, right-click on **HMI Displays** (or open the HMI Editor).
3. Select **Import Display...** (or **Import Displays**).
4. Browse to the desired `.vld` file in this directory and click **Open**.
5. All screens, graphic controls, and PLC operand links are automatically created.

---

## Regenerating the Examples

To regenerate or customize all 4 HMI packages, run the PowerShell generation script:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_hmi_examples.ps1
```

> [!NOTE]
> The generator requires 32-bit execution due to the Jet 4.0 OLEDB driver (`Microsoft.Jet.OLEDB.4.0`). The script automatically detects 64-bit environments and relaunches itself in 32-bit PowerShell.
