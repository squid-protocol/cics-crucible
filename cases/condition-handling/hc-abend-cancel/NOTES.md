# hc-abend-cancel: HANDLE ABEND CANCEL / RESET, ABEND CANCEL, ABEND NODUMP

## The trap

`HCABCN` (transaction `HCAB`) reads its mode from the terminal input (`HCAB C`, `R`, `K`, `N`), sets `HANDLE ABEND LABEL(MAIN-EXIT)`,
then abends. The exit does `ASSIGN ABCODE`, sends `X ` and the code (6 bytes) and RETURNs.

* **C**: `HANDLE ABEND CANCEL`, then `ABEND ABCODE('HCC1')`.
* **R**: `HANDLE ABEND CANCEL`, `HANDLE ABEND RESET`, then `ABEND ABCODE('HCR1')`.
* **K**: `ABEND ABCODE('HCK1') CANCEL`.
* **N**: `ABEND ABCODE('HCN1') NODUMP`.

## Why a naive translation breaks

* A port that treats `HANDLE ABEND CANCEL` as a no-op still runs the exit in C.
* A port that treats `CANCEL` as permanent never reactivates the exit in R.
* A port that ignores `ABEND CANCEL` runs the exit in K.
* A port that reads `NODUMP` as "no exit" skips the exit in N.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal `T001`, clock `2026-03-02T10:00:00`, one task per scenario, level 1 only.

* **`handle-cancel` (C)**: [HANDLE ABEND] CANCEL cancels the exit established at this program level; with no active exit at any level
  [ABEND-RECOVERY] the task terminates. Events: RECEIVE, ABEND `HCC1` (command, terminated). Task end `abend`; nothing is sent.
* **`handle-reset` (R)**: [HANDLE ABEND] RESET reactivates an exit that was cancelled. ABEND `HCR1` goes to `MAIN-EXIT`; ASSIGN ABCODE
  gives `HCR1`; SEND TEXT `X HCR1`; RETURN. Task end `normal`.
* **`abend-cancel` (K)**: [ABEND] CANCEL: exits established by HANDLE ABEND are ignored, so the exit is not driven and the task
  terminates. Events: RECEIVE, ABEND `HCK1` (terminated). Task end `abend`.
* **`abend-nodump` (N)**: [ABEND] NODUMP suppresses the dump only; the exit gets control. SEND TEXT `X HCN1`; RETURN. Task end `normal`.

## What a correct port must do

* HANDLE ABEND CANCEL removes the exit for the level; RESET brings it back; ABEND CANCEL skips the exit for this abend; NODUMP changes
  nothing observable. A terminated task (end `abend`) sends nothing further.

## Avoided ambiguities

* **Whether a dump is taken**, the dump code, and what a terminated task shows the terminal: not observable, not asserted.
* **RESET without a prior CANCEL** and **a new LABEL after CANCEL**: not used.
* **Exit retained across CANCEL / RESET:** read as the same LABEL (README assumptions table).
* **Levels above 1** (LINK): hc-abend-link covers the upward search; every scenario here is one level.

## Citations

* [HANDLE-ABEND] CICS TS 6.x, EXEC CICS HANDLE ABEND (LABEL, CANCEL, RESET): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-abend
* [ABEND] CICS TS 6.x, EXEC CICS ABEND (ABCODE, CANCEL, NODUMP): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-abend
* [ABEND-RECOVERY] CICS TS 5.6, Abnormal termination recovery: https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=applications-abnormal-termination-recovery
* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (ABCODE): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
