# hx-ext-precedence: a field's colour and highlight come from the program's byte, then the field, the map, the mapset; DATAONLY applies none of the map's

## The trap

`HXPRC` (transaction `HX04`) sends map `HXM4` of mapset `HXSET4`, which has `DSATTS=(COLOR,HILIGHT)`. The mapset says
`COLOR=GREEN,HILIGHT=UNDERLINE`, the map says `COLOR=BLUE`, and three fields differ: `FA` has its own
`COLOR=RED,HILIGHT=BLINK`, `FB` has none, `FC` has only `HILIGHT=REVERSE`. The first ENTER sends every default. PF1 re-sends
with program bytes in the symbolic map (`FAC`=`DFHYELLO`, `FBC`=`DFHDFCOL`, `FCH`=`DFHBLINK`). PF2 re-sends `DATAONLY`
with `FAC`=`DFHPINK`, `FBC`=`DFHDFCOL` and text for `FB` only. The log shows, per field, the colour and highlight byte
BMS wrote and where it came from.

## Why a naive translation breaks

* A port that keeps one default per field (or per map) misses the three-level fallback: `FB` gets its colour from the
  map (BLUE) and its highlight from the mapset (UNDERLINE), two different levels in one field.
* A port that reads `DFHDFCOL` (X'00') as "paint this field in the default colour" instead of "the program set
  nothing" loses the map's BLUE on `FB` in PF1.
* A port that applies the map's colours to a `DATAONLY` send sends bytes the program never supplied; under `DATAONLY`
  only what the program put in the symbolic map is sent, so `FC` is absent from the stream altogether.

## Expected behaviour

Model (SPEC sections 2 and 4): terminal `T001` (3270, colour and highlight capable), clock 2026-03-02T10:00:00. Colour
and highlight bytes are the DFHBMSCA values (BLUE F1, RED F2, PINK F3, GREEN F4, YELLOW F6; BLINK F1, REVERSE F2,
UNDERLINE F4).

* **`full-send`** (ENTER, then PF1). First send (`ERASE`, nothing from the program but text): `FA` RED/BLINK (its own
  operands), `FB` BLUE (map) / UNDERLINE (mapset), `FC` BLUE (map) / REVERSE (its own). PF1 sends the whole map
  again: `FA` colour is the program's YELLOW and its highlight (byte X'00') stays BLINK; `FB` colour is BLUE again,
  because X'00' is not a colour; `FC` highlight is the program's BLINK, replacing REVERSE. Each value follows the
  rule that a non-null program byte wins, else the map's definition applies from the most specific level
  [BUILD-SCREEN] [DFHMDF] [DFHMSD].
* **`dataonly`** (ENTER, then PF2). With `DATAONLY` only data and attributes from the program are sent [SEND-MAP]:
  `FA` is sent for the program's PINK alone, `FB` for its text alone (no colour: X'00' sends none and the map's BLUE
  is not applied), `FC` has nothing to send and is not in the stream.

## What a correct port must do

* Resolve colour and highlight separately, program byte (not X'00') first, then DFHMDF, DFHMDI, DFHMSD.
* Treat the X'00' byte exactly like an untouched symbolic-map byte.
* Under `DATAONLY`, apply none of the map's defaults (attribute, data, colour or highlight) and omit a field that
  has nothing from the program.

## Avoided ambiguities

* No `COLOR=DEFAULT` or `HILIGHT=OFF` operand, whose meaning on a given terminal is a device matter.
* No cursor position is asserted (no `IC`, no `CURSOR`).
* The program sets no attribute byte, so every attribute is the map's (ASKIP,NORM, X'F0'); attributes are covered by
  `hx-attr-bytes`.
* No RECEIVE MAP; the scenarios send only AID keys.

Lower-confidence points: whether an explicit `DFHDFCOL` means "the map's colour" or "the terminal's default" cannot be
told apart from an untouched byte (both are X'00' on the wire), so the case asserts only that the byte alone does not
override the map; the reviewer should re-read [BUILD-SCREEN] on that sentence. The `DFHMSD`/`DFHMDI` level fallback was
read from the macro pages, not from a worked example. No quote above is a verbatim copy.

## Citations

* [BUILD-SCREEN] CICS TS 6.x, Building the output screen: https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-building-output-screen
* [DFHMDF] CICS TS 6.x, DFHMDF macro (COLOR, HILIGHT): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
* [DFHMSD] CICS TS 6.x, DFHMSD and DFHMDI macros (COLOR, HILIGHT, DSATTS, MAPATTS): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmsd
* [BMS-CONST] CICS TS 6.x, BMS constants (DFHBMSCA colour and highlight values): https://www.ibm.com/docs/en/cics-ts/6.x?topic=reference-bms-constants
* [SEND-MAP] CICS TS 6.x, EXEC CICS SEND MAP (DATAONLY): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map
* [RETURN] CICS TS 6.x, EXEC CICS RETURN: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* GA23-0059, 3270 Data Stream Programmer's Reference (extended field attributes: colour, highlighting).
