# Complete Rules for Creation, Wiring, and Geometry of VisiLogic Subroutines (.VLX)
### Engineering Standard | Unitronics Vision Series Ladder Engine (V350, V130, V570, Samba)

This document establishes the mandatory geometric, electrical, logic, and relational database rules required to generate `.vlx` ladder subroutine files. Strict adherence ensures 100% compilation success in Unitronics VisiLogic without visual artifacts, disconnected wire pins, or compiler crashes.

---

## 1. Discrete Grid Geometry Rules (Grid 0..80 x 0..60)

The VisiLogic ladder diagram editor executes within a discrete coordinate system:
- **Horizontal Axis ($X$):** Range from `0` to `80`.
  - Left power rail (logic source): $X = 0$.
  - Right power rail (coil return): $X = 80$.
- **Vertical Axis ($Y$):** Range from `0` to `60`.
  - Default single-line rung height: 14 units (`Height = 14`).

```text
X=0                                                                     X=74      X=80
 |                                                                        |        |
 |--[ NO Contact ]------[ Compare Block ]------[ Math ADD ]---------------( Coil )--|
 |   (Xs=0, Xe=6)        (Xs=10, Xe=23)         (Xs=28, Xe=41)          (Xs=74,Xe=80)
 |
 Ys=4 ----------------- Main Signal Power Flow Rail ------------------------------- Ys=4
```

### 1.1. The Iron Rule of the Signal Axis: $Ys = 4$
- All contacts (NO, NC, P, N) and function block enable inputs (`EN`) in the primary rung path **must be placed strictly at $Ys = 4$**.
- Using any other vertical coordinate (e.g. $Ys=0$, $Ys=5$, $Ys=10$) creates disconnected pins, staircase bends, and broken power flow in the ladder canvas.

### 1.2. The Coil Placement Rule: $Xs = 74, Xe = 80$
- Every coil (`Direct`, `Inverted`, `Set`, `Reset`, `Toggle`) and Timer coil **must be anchored to the right power rail**.
- Coordinates are strictly: $Xs = 74, Ys = 4$ (with element width 6, $Xe = 74 + 6 = 80$).
- Placing a coil mid-rung (e.g. $Xs = 30$) is an illegal syntax error in VisiLogic.

---

## 2. Wiring and Continuity Rules

### 2.1. Horizontal Continuity (No Air Gaps in Power Flow)
- Empty space between adjacent elements must be closed with an Opcode 100 horizontal wire (`Wire Horizontal`).
- If element $A$ ends at $Xe_A$ and element $B$ begins at $Xs_B$, where $Xs_B > Xe_A$, insert a wire:
  $$\text{AddWire}(sid, Xs = Xe_A, Ys = 4, Dx = Xs_B - Xe_A, Dy = 0, \text{isVert} = \text{false})$$
- The segment from the output of the final logic block to the coil at $Xs = 74$ **must always be closed**:
  $$\text{AddWire}(sid, Xs = Xe_{last}, Ys = 4, Dx = 74 - Xe_{last}, Dy = 0, \text{isVert} = \text{false})$$

### 2.2. Parallel Branches (OR Logic)
When constructing parallel logic branches:
1. **Branch Split Node:** At the branch coordinate $X_{split}$, place a vertical downward wire:
   $$\text{AddWire}(sid, Xs = X_{split}, Ys = 4, Dx = 0, Dy = 10, \text{isVert} = \text{true})$$
2. **Lower Branch Line:** Place alternative contacts or blocks along the parallel line $Ys = 14$ ($4 + 10$).
3. **Branch Join Node:** After the last element of the lower branch, place a vertical upward wire returning to the main line ($Ys = 4$).
4. **Rung Height Adjustment:** Parallel branches require adjusting the rung `Height` to `24` (or `34` for 3 parallel rungs).

---

## 3. Element Width and Spacing Constants Matrix

When calculating horizontal positions along $Ys = 4$, utilize the following dimension standards:

| Element Category | Opcode | Width $\Delta X$ | Start Coord ($Xs$) | End Coord ($Xe$) | Output Pin Position |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Direct / Inverted Contact** | `200`, `201` | **6** | $Xs$ | $Xs + 6$ | Right edge ($Xe$) |
| **Transition Contact (P / N)**| `202`, `203` | **6** | $Xs$ | $Xs + 6$ | Right edge ($Xe$) |
| **Compare Block (=, >, <)**   | `400` .. `405` | **13** | $Xs$ | $Xs + 13$ | Right edge ($Xe$) |
| **Math Block (ADD, SUB, etc)**| `300` .. `303` | **13** | $Xs$ | $Xs + 13$ | Right edge ($Xe$) |
| **Store / Store Direct Block**| `500`, `501` | **13** | $Xs$ | $Xs + 13$ | Right edge ($Xe$) |
| **Linearize Block**           | `1300` | **13** | $Xs$ | $Xs + 13$ | Right edge ($Xe$) |
| **Timer Block (TA / TD / TE)**| `800` .. `802` | **13** | $Xs$ | $Xs + 13$ | Right edge ($Xe$) |
| **Subroutine Call (Call Sub)**| `600` | **13** | $Xs$ | $Xs + 13$ | Right edge ($Xe$) |
| **Coil (Direct, Set, Reset)** | `700` .. `704` | **6** | **74** | **80** | Right power rail |

---

## 4. Relational Database Rules for Stability

1. **Sequential Rung Ordering (`OrderNum`)**:
   - Rung order in `expimp_LdrStrip` must be continuous ($1, 2, 3 \dots$).
2. **Zero NULL Keys in Relational Tables**:
   - `expimp_LdrElements` and `expimp_LdrElmsOprs` must never contain NULL in foreign key fields (`ElmntID`, `StripID`, `Elmnt_Oprnd_Type`, `Elmnt_Oprnd_Adrs`). NULL values crash VisiLogic during deserialization.
3. **Mandatory Terminating `Return` Rung**:
   - Every subroutine must end with a single uncoiled horizontal wire across the grid ($Xs=0 \to 74$).
   - This marks the subroutine boundary for the cyclic scan engine.
