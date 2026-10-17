# Complete Library of VisiLogic HMI Display Controls (.VLD)
### ANSI/ISA-101.01 Standard | Unitronics Vision Series PLCs (320x240 Matrix, 16-bit Color)

This manual provides an exhaustive reference of all visual controls, touch targets, dynamic meters, and binary Property Bags supported by the `HmiDisplayBuilder.ps1` engine for `.vld` (`HMIBufferColorPages.udb`) files.

---

## 1. Relational Architecture of HMI Controls (.VLD)

A `.vld` display export is a ZIP archive containing a Microsoft Access Jet 4.0 database (`HMIBufferColorPages.udb`). Graphic controls and their PLC bindings are structured in a two-table parent-child hierarchy:

```text
Pages / Pages_all (Display Canvas)
  └── [1 : N] ── HMI_Elements (Graphic Element / Variable Container)
                   └── [1 : N] ── HMI_Operands (Linkage to PLC Memory Address)
```

### 1.1. Core Fields in `HMI_Elements`:
- **`ID`** (`Long`): Primary key identifying the control within the database.
- **`DisplayID`** (`Long`): Foreign key referencing the parent display canvas (`Pages.ID`).
- **`Type`** (`Integer`): Primary element classification code (e.g. 1=Rectangle, 4=Label, 8=Variable, 11=Button).
- **`VarType`** (`Integer`): Sub-type for variable objects (e.g. 8=Numeric, 21=Gauge, 24=Bargraph, 25=Tank).
- **`Xs`, `Ys`** (`Integer`): Top-left origin in pixel grid coordinates ($0 \le Xs \le 319$, $0 \le Ys \le 239$).
- **`Dx`, `Dy`** (`Integer`): Width and height of the bounding rectangle in pixels.
- **`ColorFore`, `ColorBack`** (`Integer`): Foreground (text/border) and background colors from the Unitronics 16-bit palette.
- **`Flat3D`** (`Integer`): Border style: `0` = Flat, `1` = Raised Button, `2` = Sunken, `3` = Bordered.
- **`Alignment`** (`Integer`): Text alignment: `0` = Left, `2` = Right, `4` = Center.
- **`TouchOprndAddr`** (`Integer`): Address of the memory bit `MB` pulsed or set upon touch (`-1` if non-interactive).
- **`VarKeyPadEntry`** (`Integer`): Virtual keypad enable (`1` = popup keypad on touch, `0` = read-only).
- **`[Binary]`** (`OLE Object / Long Binary`): Serialized OLE Property Bag containing typography, graduation ticks, and scaling parameters.

---

## 2. Static Graphic Controls & Touch Buttons

### 2.1. Text Label (Label)
Used for process titles, card headers, engineering units, and static labels.

- **Identification:** `Type = 4`, `VarType = 0`, `[Binary] = NULL`.
- **Dimensions:** Any size within display bounds ($Dx \ge 10, Dy \ge 10$).
- **Typography:** `FontNumber = 282392660`, `Alignment = 4` (Center) or `0` (Left).
- **PowerShell API Call:**
  ```powershell
  $disp.AddLabel($x, $y, $w, $h, "TEMPERATURE [°C]:", [HmiColor]::Black, [HmiColor]::LightGray, 0)
  ```

### 2.2. Panel / Grouping Rectangle (Rectangle)
Used to construct background cards, partition operational zones, and create high-contrast borders adhering to ISA-101.

- **Identification:** `Type = 1`, `VarType = 0`, `[Binary] = NULL`.
- **Properties:** `ColorFore` = Border color, `ColorBack` = Fill color, `Flat3D = 0`.
- **PowerShell API Call:**
  ```powershell
  $disp.AddRectangle($x, $y, $w, $h, [HmiColor]::DarkGray, [HmiColor]::LightGray)
  ```

### 2.3. Dividing Rule (Line)
Used to separate logical zones or delineate the bottom navigation bar.

- **Identification:** `Type = 2`, `VarType = 0`, `[Binary] = NULL`.
- **PowerShell API Call:**
  ```powershell
  $disp.AddLine($x, $y, $w, $h, [HmiColor]::DarkGray)
  ```

### 2.4. Interactive Touch Pushbutton (Button)
Tactile touch element that sets or pulses a designated PLC memory bit `MB`.

- **Identification:** `Type = 11`, `VarType = 0`, `[Binary] = NULL`.
- **Interactive Attributes:** `TouchOprndAddr = <MB_Address>`, `Flat3D = 1` (Raised tactile 3D effect).
- **Relational Binding:** Creates a record in `HMI_Operands` with `OprndType = 1` (MB), `OprndPurpose = 2` (Touch bit).
- **PowerShell API Call:**
  ```powershell
  $disp.AddButton($x, $y, $w, $h, "START PUMP", [HmiOperandType]::MB, 10, [HmiColor]::White, [HmiColor]::Green)
  ```

---

## 3. Dynamic Process Variables & Analog Meters

Dynamic meters store format, scale, and threshold properties in binary OLE Property Bags (`templates/*.bin`).

### 3.1. Numeric Variable (Numeric Input/Display)
Displays real-time analog values (`MI`, `DW`, `ML`) and optionally triggers the virtual numeric keypad overlay.

- **Identification:** `Type = 8`, `VarType = 8`.
- **Property Bag:** `templates/numeric_propertybag.bin` (1,740 bytes).
- **Relational Binding:** Creates a record in `HMI_Operands` with `OprndPurpose = 1` (Value read).
- **Attributes:** `VarKeyPadEntry = 1` enables the interactive keypad popup.
- **PowerShell API Call:**
  ```powershell
  # Interactive setpoint with keypad:
  $disp.AddNumericVariable($x, $y, $w, $h, [HmiOperandType]::MI, 20, $true, 1)

  # Read-only process value:
  $disp.AddNumericVariable($x, $y, $w, $h, [HmiOperandType]::MI, 10, $false, 1)
  ```

### 3.2. Dynamic Bargraph (Bargraph)
Renders a vertical or horizontal analog bar indicating operational output, speed reference, or filling percentage.

- **Identification:** `Type = 8`, `VarType = 24`.
- **Property Bag:** `templates/bargraph_propertybag.bin` (624 bytes).
- **Relational Binding:** Creates an entry in `HMI_Operands` bound to target register `MI`.
- **PowerShell API Call:**
  ```powershell
  $disp.AddBargraph($x, $y, $w, $h, [HmiOperandType]::MI, 61, [HmiColor]::DarkBlue, [HmiColor]::LightGray)
  ```

### 3.3. Volumetric Vessel Meter (Tank)
Renders a simulated fluid storage tank with fluid level visualization.

- **Identification:** `Type = 8`, `VarType = 25`.
- **Property Bag:** `templates/tank_propertybag.bin` (512 bytes).
- **PowerShell API Call:**
  ```powershell
  $disp.AddTank($x, $y, $w, $h, [HmiOperandType]::MI, 5, [HmiColor]::Blue, [HmiColor]::LightGray)
  ```

### 3.4. Circular Dial Meter (Dial Gauge)
Models an analog pressure or temperature gauge with an angular needle.

- **Identification:** `Type = 8`, `VarType = 21`.
- **Property Bag:** `templates/gauge_propertybag.bin` (1,464 bytes).
- **PowerShell API Call:**
  ```powershell
  $disp.AddGauge($x, $y, $w, $h, [HmiOperandType]::MI, 12, [HmiColor]::Black, [HmiColor]::LightGray)
  ```

---

## 4. Unitronics 16-Bit Color Palette Reference

The Unitronics Vision display engine utilizes predefined 16-bit integer color codes:

| Color Name | Integer Code | Hex Code | Purpose under ANSI/ISA-101.01 |
|:---|:---:|:---:|:---|
| **Black** | `0` | `#000000` | Primary text, high-contrast numeric readings |
| **White** | `15` | `#FFFFFF` | Text on high-contrast alarm buttons |
| **Light Gray** | `74` | `#D4D0C8` | **Standard screen canvas background (`ColorBack = 74`)** |
| **Panel Gray** | `103` | `#C0C0C0` | Grouping panel and card background fill |
| **Dark Gray** | `68` | `#808080` | Card borders, dividing rules, inactive equipment |
| **Muted Green** | `10` | `#008000` | Normal running equipment (RUN / ON) |
| **Alarm Red** | `2` | `#FF0000` | **Strictly reserved for Critical Safety Alarms (P1)** |
| **Warning Yellow** | `14` | `#FFFF00` | Warnings, maintenance notices, transit states (P2) |
| **Process Blue** | `9` | `#0000FF` | Tank fluid levels, cold media |
