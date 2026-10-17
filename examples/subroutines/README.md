# Visilogic Subroutines Showcase & Examples

This directory contains pre-generated ladder logic subroutine export packages (`*.vlx`) for Unitronics Vision PLCs, structured according to native Jet 4.0 database specifications with full relational and grid geometry compliance.

## Generated Examples Overview

| File | Subroutine Name | Rungs | Ladder Elements | Application & Features |
| :--- | :--- | :---: | :---: | :--- |
| `PUMP_LEAD_LAG_ALTERNATION.vlx` | `PumpLeadLag` | 4 + Return | 25 | Dual pump duty alternation. Auto permissive interlocking, pulse toggle trigger (`MB21` -> `MB22`), lead/lag contactor output sequencing (`O0`, `O1`) with thermal fault bypass protection (`MB6`, `MB7`). |
| `ANALOG_SCALING_ALARMS.vlx` | `AnalogScaling` | 3 + Return | 16 | 4-20mA sensor scaling and alarm trips. Uses Linearize block (`Opcode 1300`) to convert raw analog reading (`MI0`, 0..4095) to engineering level units (`MI10`, 0..500 cm). Comparator blocks evaluate Low-Low trip (`< 50 cm`) and High-High trip (`> 450 cm`) with Set coils. |
| `BATCH_STEP_SEQUENCER.vlx` | `BatchSequencer` | 3 + Return | 18 | Batch recipe sequencer state machine. Positive transition pulse initialization (`Store 1` to `MI21`), phase dwell advance with Increment (`INC MI21`), and sequence termination comparator (`>= 5`) resetting the active flag. |

---

## Ladder Architecture & Grid Standards

- **Signal Axis:** Fixed at $Ys = 4$ for all rung contacts and functional block `EN` inputs.
- **Element Widths:**
  - Contacts (NO, NC, P, N): $\Delta X = 6$
  - Functional Blocks (Store, Compare, Inc, Dec): $\Delta X = 13$
  - Linearize Block: $\Delta X = 17$
  - Coils (Direct, Inverted, Set, Reset, Toggle): Positioned at $Xs = 74, Xe = 80$
- **Termination:** Every subroutine is terminated with a valid VisiLogic Return strip (`IsReturnStrip = -1`, `ElmntType = 602`).
- **Relational Integrity:** Zero NULL values in `expimp_LdrElmsOprs` and full numeric constant registration in `expimp_LdrOperands` (`Type 37`).

---

## How to Import into VisiLogic

1. In VisiLogic, navigate to the **Ladder** window.
2. In the project navigation tree on the left, right-click on **Subroutines**.
3. Select **Import Subroutine...**
4. Browse to the desired `.vlx` file in this directory and click **Open**.
5. The subroutine will immediately appear under your project tree with all rungs, comments, and operand links properly rendered.

---

## Regenerating the Examples

To regenerate and verify all 3 VLX subroutines:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_subroutine_examples.ps1
```

> [!NOTE]
> The generator requires 32-bit execution due to the Jet 4.0 OLEDB driver (`Microsoft.Jet.OLEDB.4.0`). The script automatically detects 64-bit environments and relaunches itself in 32-bit PowerShell.
