# Visilogic Data Tables Showcase & Examples

This directory contains pre-generated `Data_table.xml` definition files for Unitronics Vision PLCs, structured according to native VisiLogic COM specifications (`UnPlcDB1.clsDBServices`).

## Generated Examples Overview

| File | Application | Tables | Columns / Types | Purpose |
| :--- | :--- | :---: | :--- | :--- |
| `CHEMICAL_BATCH_RECIPES.xml` | Batch Process Recipes | 2 | `Recipe_Headers`: ID (Int), Name (Str20), Steps (Int), TargetVolume (Long), Active (Bit)<br>`Recipe_Steps`: ID (Int), Step (Int), OpType (Int), Temp (Int), RPM (Int), Dwell (Long), Dose (Long) | Relational recipe management with multi-step process staging (temperature, agitation, dosing). |
| `SHIFT_PRODUCTION_LOG.xml` | Production & OEE Logging | 1 | Shift ID, Date, Leader, Produced units, Rejects, Uptime (s), Energy (kWh), Efficiency (%) | 24-shift circular production logger for OEE analysis and shift-to-shift KPI tracking. |
| `ALARM_AUDIT_TRAIL.xml` | Event & Alarm Historian | 1 | Event ID, Timestamp, Alarm Code, Severity, Ack State, Trigger Value, Tag Name | Historical event and alarm audit buffer for compliance, diagnostics, and root cause analysis. |

---

## Data Table Architecture Details

### VisiLogic Data Types Reference
Each column in the XML adheres to the strict 1..6 data type identifier required by the VisiLogic database engine:
- `1` = **Flags** (`MB` / 1-bit boolean, 1 byte in row buffer)
- `2` = **Integer** (`MI` / 16-bit signed integer, 2 bytes)
- `3` = **Long** (`ML` / 32-bit signed integer, 4 bytes)
- `4` = **DWord** (`MDW` / 32-bit unsigned integer, 4 bytes)
- `5` = **Byte** (`8-bit` unsigned integer, 1 byte)
- `6` = **String** (`ASCII` string, configurable length)

---

## How to Import into VisiLogic

1. In VisiLogic, open the **Data Tables** window (`Project` -> `Data Tables` or via the sidebar).
2. Right-click on **Data Tables** and select **Import Data Tables...** (or click the Import icon on the Data Tables toolbar).
3. Select the desired `.xml` file from this directory.
4. VisiLogic will parse the `<PLC_DB>` structure, build the table schema, and display the configured columns and row limits.

---

## Regenerating the Examples

To regenerate and verify all 3 XML tables:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_data_table_examples.ps1
```
