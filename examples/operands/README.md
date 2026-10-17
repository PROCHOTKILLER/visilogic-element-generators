# Visilogic Operands Showcase & Examples

This directory contains pre-generated operand database symbol definitions (`operands.csv`) for Unitronics Vision PLCs, structured according to native VisiLogic export/import specifications.

## Generated Examples Overview

| File | Application | Operands Configured | Features & Symbol Types |
| :--- | :--- | :---: | :--- |
| `WATER_TREATMENT_OPERANDS.csv` | Water Intake & Pumping Station | 39 tags + system symbols | Digital inputs (well levels, overloads, flow switches), digital outputs (contactor drives, inlet valves), MB flags (auto/manual, fault latches), MI analog signals (4-20mA raw inputs, scaled levels, discharge pressures), ML totalizer, and stagger timers. |
| `HVAC_SYSTEM_OPERANDS.csv` | Commercial AHU & Climate Control | 31 tags + system symbols | Safety inputs (freeze stat, duct smoke, filter differential pressure), outputs (VFD commands, pre-heat valve, DX compressor stages), setpoints, and PID loop output registers. |
| `BATCH_REACTOR_OPERANDS.csv` | Chemical Batch Reactor & Mixing | 34 tags + system symbols | Interlocks (vessel lid, relief vent), dosing pumps, agitator speed setpoint and actual RPM, vessel weight, temperature registers, dwell timers, and purge timers. |

---

## File Structure & Specification

- **File Format:** CSV (`Windows-1250` / ANSI encoded)
- **Dimensions:** Exactly 8,193 rows (1 header row + 8,192 address rows: index 0 to 8191)
- **Columns (18):**
  1. `Address` (0..8191)
  2. `MB` (Memory Bits)
  3. `MI` (Memory Integers 16-bit)
  4. `MF` (Memory Floats 32-bit)
  5. `ML` (Memory Longs 32-bit)
  6. `MDW` (Memory DWords 32-bit unsigned)
  7. `SB` (System Bits)
  8. `SI` (System Integers)
  9. `SL` (System Longs)
  10. `SDW` (System DWords)
  11. `I` (Physical Digital Inputs)
  12. `O` (Physical Digital Outputs)
  13. `T` (Timers)
  14. `C` (Counters)
  15. `XB` (Extended Bits)
  16. `XI` (Extended Integers)
  17. `XL` (Extended Longs)
  18. `XDW` (Extended DWords)

---

## How to Import into VisiLogic

1. In VisiLogic, navigate to the menu: **Operands** -> **Import / Export** -> **Import Operands**.
2. Select the desired `.csv` file from this directory.
3. Choose **Overwrite** or **Merge** according to your project requirements.
4. All operand names and system comments will instantly be populated across your ladder and HMI editors.

---

## Regenerating the Examples

To regenerate and verify all 3 operand CSV files:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_operand_examples.ps1
```
