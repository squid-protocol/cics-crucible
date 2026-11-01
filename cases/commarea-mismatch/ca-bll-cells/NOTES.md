# ca-bll-cells: OS/VS COBOL BLL cells, SERVICE RELOAD, and a record longer than 4096 bytes

Before COBOL II, a CICS command-level program reached storage outside the task through **base locator for linkage (BLL) cells**.
No `ADDRESS OF`, no `POINTER`: the LINKAGE SECTION starts with a group of `S9(8) COMP` cells, and each cell holds the address of the
following 01-level, in order. `CABLL` (transaction `CA0N`) is written that way and uses no `USING`.

## The trap

The mode letter typed after the transaction id picks the scenario. GETMAIN and the SET option are not events; each result shows in
the `SEND TEXT` report (and in the TS queue for `R`).

| Mode | What runs | What it shows |
|---|---|---|
| R | `WRITEQ TS 'BLLQ'`, then `READQ TS ... SET(QPTR) LENGTH(WS-LEN) ITEM(1)`, then `SERVICE RELOAD Q-REC` | the cell is set by the command, and after the reload the 01 sees the item |
| L | `GETMAIN SET(FRPTR) FLENGTH(5400) INITIMG('*')`, `FRPTR1 = FRPTR + 4096`, `SERVICE RELOAD FILE-REC`, write head and tail, `MOVE FRPTR TO TSPTR`, `SERVICE RELOAD TS-REC` | a record over 4096 bytes takes a second cell, the first plus 4096; a cell moved to another cell makes an alias |

## Why a naive translation breaks

* A port that treats `SET(cell)` as a plain numeric store (the cell is a number, not an address) leaves `Q-REC` blank in R.
* A port that gives a 5400-byte record one cell and a copy for the part past 4096 loses the tail: `FIELD3` (byte 5001 on) is in the
  second cell's span, and the `TAIL` write must land in the same storage the cell addresses.
* A port that copies storage on `MOVE cell TO cell` rather than aliasing it shows no `HEAD` through `TS-REC` in L.

## Expected behaviour

Every scenario: `CA0N x` typed on a cleared screen; `RECEIVE` returns the typed text (assumption shared by the other cases, see the
README).

* **`read-set-cell`** (R): READQ TS SET returns the address of the item in `SET`, and `LENGTH` receives the item length
  [APRM-BLL, APPG-B]. The queue holds `QUEUED-ITEM1` (12 bytes) and is unchanged. Report `MODE=R REC=QUEUED-ITEM1 LEN=12`.
* **`long-record`** (L): "If the record is longer than 4096 bytes, more than one cell is needed; the second is the first plus
  4096" [APRM-BLL Figure 3]; moving a cell to another cell addresses the same storage [APRM-BLL Figure 5]. `INITIMG('*')` fills the
  5400 bytes. After `HEAD` at byte 1 and `TAIL-BYTES` at byte 5001, `TS-REC` (via the copied cell) shows `HEAD******` and `FILE-REC`
  `FIELD3` starts `TAIL-BYTES`. Report `MODE=L VIEW=HEAD****** TAIL=TAIL-BYTES`.

## What a correct port must do

* Model a cell as an address, with `SET`, `ADDRESS OF` equivalents and `SERVICE RELOAD` re-establishing addressability.
* Give a record over 4096 bytes consecutive cells at 4096-byte steps over one block.
* Alias on cell-to-cell `MOVE`.

## Avoided ambiguities

* **READQ TS SET stands in for file READ SET.** File READ SET needs a seeded dataset; READQ TS SET and GETMAIN SET need none and use
  the same cell mechanism.
* **What an unloaded cell addresses.** IBM leaves a 01 whose cell was never loaded undefined; the case never reads one.
* **Storage past the GETMAIN.** Nothing past byte 5400 is touched.
* **`INITIMG`** is used only to make the unwritten bytes known (`*`).
* **Syntax check.** `SERVICE RELOAD` is not GnuCOBOL; `tools/syntax_check.py` stubs it (a statement of its own becomes CONTINUE).

## Citations

* [APRM-BLL] CICS/MVS Version 2 Release 1.2 Application Programmer's Reference, SC33-0512-1, pp. 21-24 (BLL cells, Figure 3 long
  record, Figure 5 MOVE cell to cell).
* [APPG-B] CICS TS for OS/390 R3 Application Programming Guide, SC33-1687-02, Appendix B, pp. 569-574 (Figures 116 and 121).
