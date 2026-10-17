# Design, Layout, and Linking Rules for VisiLogic HMI Displays (.VLD)
### Engineering Standard | Unitronics Vision Series Controllers (320x240 Touchscreen Matrix)

This reference manual specifies the geometric, database, and ergonomic rules for programmatically generating `.vld` display files. Following these rules ensures 100% stability when importing into Unitronics VisiLogic and guarantees adherence to the **ANSI/ISA-101.01 (High Performance HMI)** standard.

---

## 1. Physical Boundaries & Geometry of the 320x240 Matrix

The Unitronics Vision V350 features a 3.5" color TFT display:
- **Resolution:** Exactly **320 pixels horizontal ($X$)** by **240 pixels vertical ($Y$)**.
- **Color Depth:** 16-bit color (65,536 colors, Unitronics palette).
- **Operator Interface:** Resistive touchscreen + front bezel navigation and function keys.

```text
(0,0) ------------------------------------------------------------- (319,0)
|  Title Banner / System Status (Y = 0 .. 24 px)                          |
|-------------------------------------------------------------------------|
|                                                                         |
|  Active Process Workspace / Synoptic Panels                             |
|  (Y = 25 .. 205 px)                                                     |
|                                                                         |
|-------------------------------------------------------------------------|
|  Bottom "One-Click" Navigation Bar (Y = 206 .. 239 px)                  |
(0,239) --------------------------------------------------------- (319,239)
```

### 1.1. Absolute Coordinate Bounds
No graphic control, border, or drop-shadow may extend beyond the visible display area:
$$0 \le Xs \le 319$$
$$0 \le Ys \le 239$$
$$Xs + Dx \le 320$$
$$Ys + Dy \le 240$$
Violating these bounds causes visual clipping or buffer allocation errors in VisiLogic.

### 1.2. Touch Target Ergonomics
- Minimum touch target dimensions for operator gloves: **$Dx \ge 40$ px, $Dy \ge 24$ px**.
- Inter-element spacing: Minimum **4 pixels** between adjacent touch targets to eliminate accidental presses.

---

## 2. Relational Database Rules for Stability (Zero-Crash Policy)

VisiLogic utilizes legacy 32-bit ActiveX/COM components (`UnHmPge2.dll`) written in Visual Basic 6. Structural or relational inconsistencies in the Access Jet 4.0 database trigger *Run-time error '9': Subscript out of range* or fatal application termination.

### Rule 1: Zero Records in `HMIJumps` for Touchscreen Models (V350)
- **Failure Mode:** `UnHmPge2.dll` allocates an internal fixed-size array `JumpArray(1 To 4)` designed solely for keypad controllers with monochrome displays (e.g. V120, V280). Populating `HMIJumps` on color touchscreen models overruns this buffer, crashing VisiLogic with VB6 Error 9.
- **Mandatory Requirement:** For Vision V350 displays, the `HMIJumps` table in `HMIBufferColorPages.udb` **must contain exactly 0 records**.
- **Touch Navigation Implementation:** Display switching on touchscreen models is handled via touch buttons linked to memory bits (`MB`), which trigger display jump instructions in ladder logic (writing the destination display index to `SI 9`).

### Rule 2: Avoiding Uninitialized Trend Control Dependencies (`VarType = 23`)
- **Failure Mode:** Placing a Trend element issues an immediate SQL query against the target project: `SELECT Name FROM Trends WHERE TrendID=1`. If Trend 1 is not pre-configured in the project, VisiLogic attempts to read an empty collection and crashes.
- **Engineering Solution:** Use self-contained **Process Bargraphs (`VarType = 24`)**, Tank level meters (`VarType = 25`), and dial gauges (`VarType = 21`). These are 100% self-sufficient and require no pre-existing project objects.

### Rule 3: Mandatory Buffer Record in `DisplayNote`
- For every defined display (`PageID`) in `Pages`, **there must exist exactly one record in `DisplayNote`**.
- This record contains a zeroed binary buffer of **exactly 510 bytes**. Omitting this entry causes an unhandled memory violation when double-clicking the display canvas in VisiLogic.

### Rule 4: Mirror Consistency between `Pages` and `Pages_all`
- The `Pages` and `Pages_all` tables must maintain an identical set of records with matching `ID`, `Description`, `ColorBack`, and `ModuleID` fields (`ModuleID = 1` for the startup display, `ModuleID = 2` for secondary pages).

### Rule 5: Foreign-Key Link Integrity in `HMI_Operands`
- Every record in `HMI_Operands` must reference an existing `ElementID` in `HMI_Elements`.
- Every record in `HMI_Elements` must reference an existing `DisplayID` in `Pages`.

---

## 3. Standard Layout Grid and Zone Geometry

To maintain ergonomic visual consistency across screens, construct layouts using these standardized zones:

| Display Region | Y-Start (`Ys`) | Height (`Dy`) | Purpose | Recommended Elements |
|:---|:---:|:---:|:---|:---|
| **Header Banner** | `0` | `24` px | Screen Title & Mode | Label (16x24 font), Heartbeat indicator, Status LED |
| **Workspace** | `25` | `180` px | Process Monitoring & Control | Cards/Panels (`Dx=312, Dy=178`), Bargraphs, Gauges, Keypad entries |
| **Navigation Bar**| `206` | `34` px | Global Display Switching | 4–5 Touch Buttons ($Dx=58 \dots 72$ px, $Dy=30$ px) |

---

## 4. Best Practices for PLC Variable Linkage

1. **Touch Pushbuttons**:
   - Set `FieldRole = 2` in `HMI_Operands`.
   - Link to `MB` flags in the user memory space ($MB \ge 1$).
   - Never link physical output coils directly to touch pushbuttons; route touch inputs through ladder interlocks.
2. **Numeric Display and Entry**:
   - Set `FieldRole = 1` in `HMI_Operands`.
   - Link readouts to `MI` (16-bit integer) or `DW` (32-bit double word) registers.
   - For user setpoint entry, enable the virtual keypad overlay (`VarKeyPadEntry = 1`) and provide unit suffixes (e.g. `°C`, `%RH`, `bar`).
