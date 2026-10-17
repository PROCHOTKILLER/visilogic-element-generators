# Unitronics VisiLogic - Automated Element Generators Suite

A modular suite of automation tools and PowerShell engines designed to programmatically generate, validate, and export project elements for **Unitronics VisiLogic** (Vision & Samba series, including V130, V350, V430, V570, V1040, and V1210).

This toolkit automates engineering tasks by converting structured configurations, CSV datasets, and industrial automation standards into native VisiLogic file formats ready for immediate import.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%20%7C%207%2B-blue.svg)
![Architecture](https://img.shields.io/badge/architecture-x86%20%2F%20SysWOW64-yellow.svg)
![VisiLogic](https://img.shields.io/badge/visilogic-9.8.x%20%7C%209.9.x-orange.svg)

---

## 📦 Modules Overview

The repository consists of four core generator engines, an automated examples suite, and shared templates:

```text
visilogic-element-generators/
│
├── data-tables-generator/       # VisiLogic Data Tables Generator (.xml)
│   ├── DataTableBuilder.ps1     # OOP Data Tables engine
│   ├── generate_data_tables.ps1 # CLI generator (CSV/JSON/Params)
│   ├── verify_data_tables.ps1   # 32-bit COM validation bridge (UnPlcDB1.dll)
│   └── templates/               # Reference XML schemas
│
├── hmi-displays-generator/      # HMI Screens & Display Generator (.vld)
│   ├── HmiDisplayBuilder.ps1    # OOP HMI engine for Jet 4.0 database
│   ├── verify_displays.ps1      # 5-stage relational & geometry auditor
│   ├── ISA101_HMI_STANDARD.md   # ANSI/ISA-101.01 design guide
│   ├── CREATION_AND_LINKING_RULES.md # 320x240 layout & zero-crash rules
│   ├── ELEMENTS_LIBRARY.md      # Binary property bags & element catalog
│   └── templates/               # Empty UDB database & binary property bags
│
├── operands-generator/          # Operands & Tag Database Generator (.csv)
│   ├── OperandsBuilder.ps1      # OOP Operands database engine
│   ├── generate_operands.ps1    # CLI generator with VLX symbol scanner
│   ├── verify_operands.ps1      # 18-column / 8192-row CP1250 validator
│   └── templates/               # Standard Unitronics system symbols template
│
├── subroutine-generator/        # Ladder Logic Subroutine Generator (.vlx)
│   ├── VlxBuilder.ps1           # OOP Ladder Logic engine for Jet 4.0
│   ├── generate_subroutine.ps1  # CLI generator with 32-bit launcher
│   ├── verify_vlx.ps1           # Relational ladder rung & wire auditor
│   ├── CREATION_AND_LINKING_RULES.md # Grid 80x60 wiring and coil rules
│   ├── ELEMENTS_LIBRARY.md      # Ladder opcodes matrix & contacts catalog
│   └── templates/               # Base VLX Access database template
│
└── examples/                    # Multi-Industry Application Examples & Master Suite
    ├── generate_all_examples.ps1# 1-click master generation and verification script
    ├── hmi-displays/            # 4 distinct HMI design styles (.vld)
    ├── data-tables/             # 3 production data table packages (.xml)
    ├── operands/                # 3 fully mapped CSV symbol tables (CP1250)
    └── subroutines/             # 3 verified ladder logic subroutines (.vlx)
```

---

## 🛠️ Generator Engines

### 1. 📊 Data Tables Generator (`data-tables-generator/`)
- **Output Format**: Native VisiLogic Data Table XML files (`.xml`).
- **Core Builder**: `DataTableBuilder.ps1`
- **Capabilities**:
  - Automatically structures multi-column data tables (Recipes, Production Logs, Alarm Audit Trails, Calibration Tables).
  - Supports 6 native column types: Flags (`MB`), Integer (`MI`), Long (`ML`), DWord (`DW`), Byte, and String ASCII.
  - Implements adapters for Timers (`Long`), Floats (`DWord` IEEE-754 or scaled `Integer`), and unsigned registers (`UINT16`).
  - Verifies binary `DesignBlock` compilation via the native 32-bit `UnPlcDB1.clsDBServices` COM automation server.
- **Import into VisiLogic**:
  - Right-click **Data Tables** > **Import Table Structure (from XML)**.

---

### 2. 🖥️ HMI Displays Generator (`hmi-displays-generator/`)
- **Output Format**: VisiLogic Display packages (`.vld` / PKWare ZIP containing `HMIBufferColorPages.udb`).
- **Core Builder**: `HmiDisplayBuilder.ps1`
- **Capabilities**:
  - Full compliance with the **ANSI/ISA-101.01** High-Performance HMI standard (grayscale backgrounds, high-contrast alarm indicators, analog bargraphs, dial gauges, and tank indicators).
  - Generates touch buttons, numeric variables (`MI`/`DW`) with interactive keypad overlay (`Keypad=1`), system bits, alarms, and multi-tier security navigation bars.
  - Relational database builder with automated GUID generation, `DisplayNote` buffer creation, and foreign-key link integrity.
- **Import into VisiLogic**:
  - Right-click **HMI Displays** > **Import Displays...** (`.vld`).

---

### 3. 🏷️ Operands Database Generator (`operands-generator/`)
- **Output Format**: Operands description and symbolic tag table (`.csv`, Windows-1250 / ANSI encoding).
- **Core Builder**: `OperandsBuilder.ps1`
- **Capabilities**:
  - Generates the full 8,193-line address matrix ($0 \dots 8191$) across all 17 Unitronics memory types:
    - **MB** (Memory Bits) - Cycle steps, alarm flags, pushbuttons
    - **MI** (Memory Integers) - Process values, analog setpoints, state machine codes
    - **ML** (Memory Longs) - 32-bit counters, elapsed process timers
    - **MDW** - Double Words / bitmasks
    - **MF** - Floating point variables
    - **I / O** - Digital inputs and outputs
    - **T / C** - Hardware timers and counters
    - **XB / XI / XL / XDW** - Extended memory banks
    - **SB / SI / SL / SDW** - Preserves native Unitronics system diagnostics tags
  - Built-in Microsoft Jet 4.0 scanner extracts all operand references from ladder logic (`*.vlx`) and auto-names unassigned variables.
- **Import into VisiLogic**:
  - Select **Project** > **Operands** > **Import from CSV**.

---

### 4. 🪜 Ladder Subroutine Generator (`subroutine-generator/`)
- **Output Format**: Native Ladder Subroutine export files (`.vlx` Jet 4.0 database with password `UniOpenSesame`).
- **Core Builder**: `VlxBuilder.ps1`
- **Capabilities**:
  - Generates complete ladder rungs on the discrete $80 \times 60$ grid:
    - Contacts: Direct (NO), Inverted (NC), Positive Transition (P), Negative Transition (N)
    - Coils: Direct, Inverted, Set, Reset, Toggle
    - Blocks: Math (Add, Sub, Mul, Div), Compare, Store, Timers, Subroutine Calls, Linearize
  - Automatic wire routing (horizontal line $Ys=4$, parallel branches with vertical bridges, coil termination at $Xs=74$).
  - Built-in mandatory `Return` rung generation preventing ladder execution overflow.
- **Import into VisiLogic**:
  - Right-click **Ladder** > **Import Subroutine** (`.vlx`).

---

## 🌟 Industrial Examples Suite (`examples/`)

The repository includes a comprehensive, verified suite of pre-generated examples across 4 distinct industrial sectors and visual styles:

| Domain / Industry | HMI Display Style | Data Table Module | Operands Database | Ladder Subroutine |
| :--- | :--- | :--- | :--- | :--- |
| **Water Treatment & Pumping** | **ISA-101 High Performance Grayscale** (`WATER_TREATMENT_PUMPING.vld`) | Shift Production OEE Log (`SHIFT_PRODUCTION_LOG.xml`) | Process Tags & Symbols (`WATER_TREATMENT_OPERANDS.csv`) | Lead-Lag Pump Alternation (`PUMP_LEAD_LAG_ALTERNATION.vlx`) |
| **HVAC & Building Automation** | **Modern Dark Industrial** (`HVAC_AIR_HANDLING_UNIT.vld`) | Alarm & Event Audit Trail (`ALARM_AUDIT_TRAIL.xml`) | AHU Air Handling Tags (`HVAC_SYSTEM_OPERANDS.csv`) | Analog Scaling & Alarms (`ANALOG_SCALING_ALARMS.vlx`) |
| **Chemical Batch Processing** | **Process Schematic P&ID** (`CHEMICAL_BATCH_REACTOR.vld`) | Batch Recipe Headers & Steps (`CHEMICAL_BATCH_RECIPES.xml`) | Reactor Automation Tags (`BATCH_REACTOR_OPERANDS.csv`) | Batch Sequencer State Machine (`BATCH_STEP_SEQUENCER.vlx`) |
| **Cold Storage & Refrigeration** | **Clean Modular Grid** (`COLD_STORAGE_REFRIGERATION.vld`) | Multi-temperature Logs | System Sensor Database | Defrost Cycle Scheduler |

### Generating All Examples at Once:
Run the master PowerShell orchestrator (automatically runs 32-bit execution):
```powershell
cd examples
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_all_examples.ps1
```

---

## 🚀 Quick Start Guide

### 1. Generating HMI Displays:
```powershell
cd examples/hmi-displays
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_hmi_examples.ps1
```

### 2. Generating Data Tables:
```powershell
cd examples/data-tables
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_data_table_examples.ps1
```

### 3. Generating Operands:
```powershell
cd examples/operands
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_operand_examples.ps1
```

### 4. Generating Ladder Subroutines:
```powershell
cd examples/subroutines
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate_subroutine_examples.ps1
```

---

## ⚙️ Architecture Requirements

- **Operating System**: Windows 7 / 10 / 11 (x86 or x64).
- **Execution Environment**: 32-bit Windows PowerShell (`C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`).
  > 💡 All generator CLI scripts feature automatic 64-to-32-bit process elevation.
- **Database Drivers**: Microsoft Jet 4.0 OLEDB Provider (`Microsoft.Jet.OLEDB.4.0`) or Access Database Engine 32-bit.
- **Target Software**: Unitronics VisiLogic versions 9.8.x through 9.9.x.

---

## 📄 License

Distributed under the MIT License.
