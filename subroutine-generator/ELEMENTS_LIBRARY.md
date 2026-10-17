# Complete Library of VisiLogic Ladder Elements (.VLX)
### Unitronics Vision Series Ladder Engine (V350, V130, V570, Samba)

This document provides an exhaustive catalog of all ladder commands, function blocks, coils, contacts, and operands supported by the `VlxBuilder.ps1` engine for **Unitronics VisiLogic** `.vlx` files.

---

## 1. Relational Architecture of a Ladder Element

Within a `.vlx` database (Microsoft Access Jet 4.0), every ladder element is defined by a record in `expimp_LdrElements` and linked to its parameters in `expimp_LdrElmsOprs`:

```text
expimp_Subroutine (Subroutine Root)
  └── [1 : N] ── expimp_LdrStrip (Rung Container)
                   └── [1 : N] ── expimp_LdrElements (Graphic Block / Coil / Contact)
                                    └── [1 : N] ── expimp_LdrElmsOprs (Operand Links)
```

### 1.1. Core Fields in `expimp_LdrElements`:
- **`ElmntID`** (`Long`): Primary key identifying the ladder element.
- **`StripID`** (`Long`): Foreign key referencing the parent rung (`expimp_LdrStrip.StripID`).
- **`ElmntType`** (`Integer`): Opcode defining the functional command (see Opcode Matrix below).
- **`Xs`, `Ys`** (`Integer`): Top-left grid coordinate on the rung canvas ($0 \le Xs \le 80$, $Ys = 4$ for main rail).
- **`Dx`, `Dy`** (`Integer`): Span in grid units (primarily for horizontal and vertical wires).
- **`MoreParamsStr`** (`Text`): Target subroutine name for `Call Subroutine` commands.

### 1.2. Operand Mapping Fields in `expimp_LdrElmsOprs`:
- **`ElmntID`** (`Long`): References the ladder element.
- **`Elmnt_Oprnd_Type`** (`Integer`): Operand bank type code (MB=1, MI=3, CONST=37).
- **`Elmnt_Oprnd_Adrs`** (`Integer`): Physical address index (or constant lookup index).
- **`OprndInIdx`** (`Integer`): Block input parameter index (1, 2, 3...; 0 if not applicable).
- **`OprndOutIdx`** (`Integer`): Block output parameter index (1 for result; 0 if not applicable).

---

## 2. Complete Opcodes Matrix

### 2.1. Logic Wires
Wires route power flow between contacts, function blocks, and coils.

| Opcode | Command Name | LAD Symbol | Width | Description |
|:---:|:---|:---:|:---:|:---|
| **`100`** | **Wire Horizontal** | `-------` | $Dx$ | Connects element outputs to subsequent inputs along the horizontal rail. |
| **`101`** | **Wire Vertical** | `│` | $0$ ($Dy$) | Vertical branch connector for parallel OR rungs. |

```powershell
# Horizontal wire:
$builder.AddWire($stripId, $xs, $ys, $dx, 0, $false)

# Vertical wire:
$builder.AddWire($stripId, $xs, $ys, 0, $dy, $true)
```

---

### 2.2. Input Contacts
All contacts occupy **6 grid units** in width ($Xe = Xs + 6$).

| Opcode | Command Name | LAD Symbol | Condition | Supported Operands |
|:---:|:---|:---:|:---|:---|
| **`200`** | **Direct Contact (NO)** | `---| |---` | High state (1 / TRUE) | `MB`, `SB`, `I`, `O`, `T`, `C` |
| **`201`** | **Inverted Contact (NC)** | `---|/|---` | Low state (0 / FALSE) | `MB`, `SB`, `I`, `O`, `T`, `C` |
| **`202`** | **Positive Transition (P)** | `---|P|---` | Rising edge ($0 \to 1$) | `MB`, `SB`, `I`, `O` |
| **`203`** | **Negative Transition (N)** | `---|N|---` | Falling edge ($1 \to 0$) | `MB`, `SB`, `I`, `O` |

```powershell
$builder.AddContact($stripId, $xs, 4, [VlxOpcodes]::DirectContact, [VlxOperandTypes]::MB, 10)
```

---

### 2.3. Output Coils
Coils occupy **6 grid units** and must terminate at the right power rail ($Xs = 74, Xe = 80$).

| Opcode | Command Name | LAD Symbol | Operation | Supported Operands |
|:---:|:---|:---:|:---|:---|
| **`700`** | **Direct Coil** | `---( )---|` | Follows rung power flow | `MB`, `O` |
| **`701`** | **Inverted Coil** | `---(/)---|` | Inverts rung power flow | `MB`, `O` |
| **`702`** | **Set Coil (Latch)** | `---(S)---|` | Latches operand to 1 on power flow | `MB`, `O` |
| **`703`** | **Reset Coil (Unlatch)** | `---(R)---|` | Unlatches operand to 0 on power flow | `MB`, `O` |
| **`704`** | **Toggle Coil** | `---(T)---|` | Inverts state on rising edge | `MB`, `O` |

```powershell
$builder.AddCoil($stripId, 74, 4, [VlxOpcodes]::DirectCoil, [VlxOperandTypes]::O, 1)
```

---

### 2.4. Comparison Function Blocks
Comparison blocks evaluate two operands and pass power flow when the condition is satisfied. Width: **13 grid units**.

| Opcode | Command Name | Operation | Inputs |
|:---:|:---|:---|:---|
| **`400`** | **Compare Equal (=)** | $A = B$ | Input 1: $A$, Input 2: $B$ |
| **`401`** | **Compare Not Equal (<>)** | $A \ne B$ | Input 1: $A$, Input 2: $B$ |
| **`402`** | **Compare Greater Than (>)** | $A > B$ | Input 1: $A$, Input 2: $B$ |
| **`403`** | **Compare Greater or Equal (>=)** | $A \ge B$ | Input 1: $A$, Input 2: $B$ |
| **`404`** | **Compare Less Than (<)** | $A < B$ | Input 1: $A$, Input 2: $B$ |
| **`405`** | **Compare Less or Equal (<=)** | $A \le B$ | Input 1: $A$, Input 2: $B$ |

```powershell
$builder.AddCompare($stripId, $xs, 4, [VlxOpcodes]::CompareGreater, [VlxOperandTypes]::MI, 10, [VlxOperandTypes]::CONST, 500)
```

---

### 2.5. Math and Move Blocks
Width: **13 grid units**.

| Opcode | Command Name | Operation | Inputs / Outputs |
|:---:|:---|:---|:---|
| **`300`** | **Math ADD (+)** | $Out = A + B$ | In1: $A$, In2: $B$, Out1: $Result$ |
| **`301`** | **Math SUB (-)** | $Out = A - B$ | In1: $A$, In2: $B$, Out1: $Result$ |
| **`302`** | **Math MUL (*)** | $Out = A \times B$ | In1: $A$, In2: $B$, Out1: $Result$ |
| **`303`** | **Math DIV (/)** | $Out = A / B$ | In1: $A$, In2: $B$, Out1: $Result$ |
| **`304`** | **Increment (INC)** | $A = A + 1$ | In1/Out1: $A$ |
| **`305`** | **Decrement (DEC)** | $A = A - 1$ | In1/Out1: $A$ |
| **`500`** | **Store** | $Dest = Source$ | In1: $Source$, Out1: $Dest$ |
| **`501`** | **Store Direct** | $Dest = Literal$ | In1: $Value$, Out1: $Dest$ |
| **`1300`** | **Linearize** | $Y = \text{Scale}(X, X_1, Y_1, X_2, Y_2)$ | In1: $X$, Out1: $Y$ |

```powershell
# Store block:
$builder.AddStore($stripId, $xs, 4, [VlxOperandTypes]::MI, 1, [VlxOperandTypes]::MI, 2)

# Linearize block (Opcode 1300):
$builder.AddLinearize($stripId, $xs, 4, [VlxOperandTypes]::MI, 0, [VlxOperandTypes]::MI, 1)
```

---

### 2.6. Timers and Control Flow

| Opcode | Command Name | Description |
|:---:|:---|:---|
| **`800`** | **Timer TA (ON-Delay)** | Starts timing when powered; output bit energizes after preset. |
| **`801`** | **Timer TD (OFF-Delay)** | Maintains output bit for preset duration after power loss. |
| **`802`** | **Timer TE (Pulse)** | Generates a fixed-duration pulse on activation. |
| **`600`** | **Call Subroutine** | Transfers ladder execution to target subroutine name. |

```powershell
# Subroutine call:
$builder.AddCallSub($stripId, $xs, 4, "Safety_Interlocks")
```

---

## 3. VisiLogic Operand Type Codes Matrix

| Operand Bank | Code (`Elmnt_Oprnd_Type`) | Data Representation |
|:---|:---:|:---|
| **MB** (Memory Bit) | `1` | 1-bit boolean flag |
| **MI** (Memory Integer) | `3` | 16-bit signed integer |
| **ML** (Memory Long) | `5` | 32-bit signed integer |
| **MDW** (Double Word) | `7` | 32-bit unsigned double word |
| **MF** (Float) | `9` | 32-bit IEEE-754 float |
| **I** (Digital Input) | `11` | Physical digital input |
| **O** (Digital Output) | `13` | Physical relay / transistor output |
| **T** (Timer) | `15` | Timer structure (current, preset) |
| **C** (Counter) | `17` | 16-bit integer counter |
| **CONST** (Literal Constant)| `37` | Numeric integer literal |
