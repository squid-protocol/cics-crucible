# hx-cursor-offset: SEND MAP CURSOR(n) is a zero-based screen offset that beats the map's IC field and works under DATAONLY

## The trap

`HXCUR` (transaction `HX05`) sends map `HXM5` of mapset `HXSET5`, whose `ACCT` field carries `IC`. The first send has no
`CURSOR` option, so the cursor goes to `ACCT`. PF1 sends `DATAONLY CURSOR(WS-POS)` with 165, PF2 sends the whole map
with `CURSOR(WS-POS)` set to 81, and ENTER computes `(6 - 1) * 80 + (8 - 1)` = 407 into `WS-POS` and sends `DATAONLY`.
`WS-POS` is `PIC S9(4) COMP`, a halfword. The log's `cursor` is the offset BMS was told.

## Why a naive translation breaks

* A port that ignores the value and keeps the IC field (the PF2 send has one) logs `ACCT` where the log says offset 81.
* A port that reads `CURSOR` as symbolic positioning (a field whose length is -1) finds none and logs no cursor.
* A port that counts positions from 1 (row 1 column 1 as 1) is one off: 165 is row 3 column 6, and 407 is row 6
  column 8, only when counted from 0.
* A port that drops `CURSOR` under `DATAONLY` loses PF1 and ENTER's cursor.

## Expected behaviour

Model (SPEC sections 2 and 4): terminal `T001` (3270 model 2, 24 x 80), clock 2026-03-02T10:00:00.

* **`dataonly-offset`** (ENTER, then PF1). First send (`ERASE`): attributes from the map, cursor at `ACCT` (the IC
  field). PF1: `MSG` carries the program's text; nothing else is in the stream (`DATAONLY`); the cursor is at offset
  165. `CURSOR(data-value)` is a halfword offset from position 0 (row 1 column 1) and is honoured with `DATAONLY`
  [SEND-MAP].
* **`beats-ic`** (ENTER, then PF2). A full send with `CURSOR(81)`: the explicit value takes the place of the IC
  position [SEND-MAP] [DFHMDF]; the cursor is at offset 81 (row 2 column 2), the map's fields are as in the first send
  with `MSG` text `IC OVERRIDE`.
* **`computed-offset`** (ENTER, then ENTER). The program computes 407 from a row and a column (zero-based, 80 columns a
  row); `DATAONLY` send, cursor at offset 407.

## What a correct port must do

* Take `CURSOR(n)` as a halfword screen offset from 0, 80 positions a row on this terminal, and let it replace the IC
  field's position.
* Honour it under `DATAONLY` as well as on a full send.
* Keep the field-name cursor (IC, or symbolic `-1`) for sends with no value.

## Avoided ambiguities

* The program never sends `DATAONLY` without `CURSOR`: where the cursor goes then (IC, the old position or 0) is not
  asserted.
* No `RECEIVE MAP`: the cursor position the terminal returns (`EIBCPOSN`) is zero on both runtimes, so it is not used.
* The offsets point at positions inside the map's fields only by coincidence; the log asserts the offset, not a field.
* No `CURSOR` on `SEND CONTROL` (covered by `hc-terminal-receive`).

Lower-confidence points: that an explicit `CURSOR(n)` beats `IC` is read from the SEND MAP and DFHMDF pages (the former
puts the cursor where the option says, the latter describes IC as the default); the reviewer should re-read both
against `beats-ic`. No quote above is a verbatim copy.

## Citations

* [SEND-MAP] CICS TS 6.x, EXEC CICS SEND MAP (CURSOR, DATAONLY): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map
* [DFHMDF] CICS TS 6.x, DFHMDF macro (ATTRB=IC): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
* [BUILD-SCREEN] CICS TS 6.x, Building the output screen: https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-building-output-screen
* [RETURN] CICS TS 6.x, EXEC CICS RETURN: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* GA23-0059, 3270 Data Stream Programmer's Reference (buffer addresses, Insert Cursor).
