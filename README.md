# Unitronics VisiLogic - Automated Element Generators Suite

A modular suite of automation tools and PowerShell generators designed to programmatically create, validate, and export project elements for **Unitronics VisiLogic** (Vision & Samba series, including V130, V350, V570, V1040, V1210).

This toolkit automates tedious manual engineering tasks by converting structured configurations, CSVs, and domain rules into native VisiLogic file formats ready for instant import.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%20%7C%207%2B-blue.svg)
![VisiLogic](https://img.shields.io/badge/visilogic-9.8.x%20%7C%209.9.x-orange.svg)

---

## 📦 Modules Overview

The suite contains four specialized generators and shared template engines:

```text
visilogic-element-generators/
│
├── data-tables-generator/       # VisiLogic Data Tables Generator (.xml)
├── hmi-displays-generator/      # HMI Screens & Display Generator (.vld)
├── operands-generator/          # Operands & Symbols Database Generator (.csv)
├── subroutine-generator/        # Ladder Logic Subroutines Generator (.vlx)
│
├── generate_manual_pdf.ps1      # Documentation to PDF compiler
├── .gitignore                   # Version control rules
└── README.md                    # Project documentation
```

---

### 1. 📊 Data Tables Generator (`data-tables-generator/`)
- **Output Format**: Native VisiLogic Data Table XML files (`.xml`).
- **Core Builder**: `DataTableBuilder.ps1`
- **Capabilities**:
  - Automatically structures multi-column data tables (Part Names, Recipes, Logged Parameters, Alarm Histograms).
  - Supports field types: Bit (`MB`), Int16 (`MI`), Int32 (`ML`), Double Word (`DW`), String/ASCII, Date/Time.
  - Generates initial values, column widths, and table headers.
  - Includes `run_ultimate_test.ps1` and verification scripts ensuring compatibility with VisiLogic's schema.
- **Import into VisiLogic**:
  - In VisiLogic: **Data Tables** > Right Click > **Import Data Table from XML**.

---

### 2. 🖥️ HMI Displays Generator (`hmi-displays-generator/`)
- **Output Format**: VisiLogic Display files (`.vld`).
- **Core Builder**: `HmiDisplayBuilder.ps1`
- **Capabilities**:
  - Generates complete HMI graphical screens compliant with the **ANSI/ISA-101.01** High-Performance HMI industrial standard (grayscale backgrounds, high-contrast alarm indicators, analog bar meters).
  - Generates touch buttons, numeric variables (`MI`), binary text indicators (`MB`), timers (`T`), alarms, and navigation bars.
  - Includes sample displays (`KOMORA9_HMI_DISPLAYS.vld`, `KOMORA9_HMI_ISA101.vld`, `DEMO_DISPLAYS.vld`).
  - Comprehensive documentation in `ISA101_HMI_STANDARD.md` and `ELEMENTS_LIBRARY.md`.
- **Import into VisiLogic**:
  - In VisiLogic: **HMI Displays** > Right Click > **Import Display** (`.vld`).

---

### 3. 🏷️ Operands Database Generator (`operands-generator/`)
- **Output Format**: Operands description and symbolic tag table (`.csv`).
- **Core Builder**: `OperandsBuilder.ps1`
- **Capabilities**:
  - Automatically provisions, groups, and assigns symbolic descriptions and comments for all PLC operand banks:
    - **MB** (Memory Bits) - Flags, cycle steps, alarm flags, pushbuttons
    - **MI** (Memory Integers) - Process values, setpoints, states
    - **ML** (Memory Longs) - Counters, 32-bit accumulators
    - **MD / DW** - Double words
    - **MF** - Floating point variables
    - **XB / XI / XD / XL** - Extended operands
  - Ensures clean separation of operand addresses, prevents overlaps, and adheres to VisiLogic's 22-character symbol naming conventions.
- **Import into VisiLogic**:
  - In VisiLogic: **Project** > **Operands** > **Import Operand Descriptions** (`.csv`).

---

### 4. 🪜 Ladder Subroutine Generator (`subroutine-generator/`)
- **Output Format**: Native Ladder Subroutine export files (`.vlx`).
- **Core Builder**: `VlxBuilder.ps1`
- **Capabilities**:
  - Generates ladder rungs (networks), logic contacts (NO, NC, Transition positive/negative), coils, and function blocks (Math, Store, Compare, Timer, Subroutine Calls).
  - Encodes rungs according to VisiLogic's binary/XML ladder serialization rules.
  - Supports modular state machine (sequencer) patterns and safety interlock routines.
  - Includes element catalog in `ELEMENTS_LIBRARY.md` and rung connection guide in `CREATION_AND_LINKING_RULES.md`.
- **Import into VisiLogic**:
  - In VisiLogic: **Ladder** > Right Click on Subroutines > **Import Subroutine** (`.vlx`).

---

## 🚀 Quick Start

### Generating Operands:
```powershell
cd operands-generator
.\example_demo_operands.ps1
```

### Generating HMI Displays:
```powershell
cd hmi-displays-generator
.\generate_isa101_displays.ps1
```

### Generating Data Tables:
```powershell
cd data-tables-generator
.\example_demo_data_tables.ps1
```

### Generating Ladder Subroutine:
```powershell
cd subroutine-generator
.\example_demo.ps1
```

---

## 📄 License

Distributed under the MIT License.
