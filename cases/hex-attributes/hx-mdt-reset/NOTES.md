# hx-mdt-reset: a field sent with MDT on is transmitted untouched until FRSET or ERASEAUP resets it

## The trap

`HXRST` (transaction `HX03`) sends map `HXM3` (MSG protected; NAME and NOTE unprotected) and then
echoes what it receives with `SEND MAP DATAONLY`. The first screen sets NOTE's attribute to
`DFHBMFSE` (X'C1': unprotected, normal, MDT on) and MSG's to `DFHBMPRO` (X'60': MDT off). After
that the three scenarios differ only in how the echo send treats the terminal's MDT bits:

| Scenario | Key | Echo send | State of the terminal afterwards |
|---|---|---|---|
| `enter-no-frset` | ENTER | `DATAONLY` | NAME and NOTE keep MDT on |
| `pf1-frset` | PF1 | `DATAONLY FRSET` | every MDT reset |
| `pf2-eraseaup` | PF2 | `DATAONLY ERASEAUP`, HXM3O cleared, MSG = `ERASED` | unprotected fields erased, MDT reset |

Every scenario ends with an ENTER where the operator types nothing. What RECEIVE MAP returns
then is the observable difference: both fields again, or MAPFAIL.

## Why a naive translation breaks

* **FRSET and ERASEAUP are not cosmetic.** A port that treats them as ignorable send options
  keeps the MDTs, so the final ENTER of `pf1-frset` and `pf2-eraseaup` receives data instead of
  MAPFAIL, and the program shows `RECEIVED` instead of `NO INPUT`.
* **Receiving untouched fields.** A port that models "the operator typed it" rather than
  "the MDT is on" drops NOTE in `enter-no-frset` (the operator never touched it) and does not
  retransmit NAME and NOTE on the third task.
* **DATAONLY with ERASEAUP.** After `MOVE LOW-VALUES TO HXM3O` only MSG has data and an
  attribute, so only MSG is sent. A port that blanks the other fields in the log would show
  them as sent.
* **MAPFAIL is a RESP, not an abend.** The program handles it with `RESP`; a port that throws
  on it fails the last step.

## Expected behaviour

Model (SPEC sections 2 and 4): one region, one terminal `T001`, clock 2026-03-02T10:00:00, a
task every 10 s. The terminal state the scenarios rely on is stated in each step's `fields`
table and `note`, so no runtime has to guess it.

* **First display** (task 1, `HX03` typed, EIBCALEN 0): `SEND MAP ERASE`. MSG gets the
  program's `DFHBMPRO` and `READY`; NAME takes the map's ATTRB (UNPROT,NORM = X'40'); NOTE gets
  the program's `DFHBMFSE` and `KEEP` [BUILD-SCREEN]. The cursor is at NAME (IC) [DFHMDF].
  RETURN TRANSID('HX03') COMMAREA LENGTH(1) [RETURN].
* **`enter-no-frset`**: the operator types `ANN` into NAME. The terminal transmits modified
  fields: NAME (operator) and NOTE (the program set its MDT) [3270-ATTR]. RECEIVE MAP gives both,
  left-justified and blank-padded [DFHMDF]. The echo is `DATAONLY` without FRSET, so MDT is
  unchanged. The next ENTER, with nothing typed, still transmits NAME and NOTE.
* **`pf1-frset`**: PF1 transmits the modified fields like ENTER. The echo carries `FRSET`: per
  the SEND MAP description, FRSET resets the MDT of every field in the terminal before the
  program's attributes in this send are applied [SEND-MAP]. MSG's `DFHBMPRO` has MDT off, so after
  the send no field has MDT on. The last ENTER transmits nothing: RECEIVE MAP returns
  MAPFAIL [RECEIVE-MAP], and the program shows `NO INPUT`.
* **`pf2-eraseaup`**: the echo clears HXM3O, sets MSG's attribute and text (`ERASED`), and sends
  with `DATAONLY ERASEAUP`. ERASEAUP erases all unprotected fields in the screen and resets their
  MDT [SEND-MAP]. Only MSG is sent. The last ENTER is MAPFAIL as above.

## What a correct port must do

* Keep a per-terminal MDT bit per field, set by the field's attribute byte (bit X'01') or by
  the operator, and transmit exactly the fields whose bit is on.
* Honour `FRSET` (reset all MDT before applying this send's attributes) and `ERASEAUP`
  (erase unprotected fields, reset their MDT).
* Return MAPFAIL from RECEIVE MAP when no field is transmitted, and let RESP handle it.
* Log only the fields that BMS sends under `DATAONLY` (those with program data or a program
  attribute).

## Avoided ambiguities

* MSG uses `DFHBMPRO`, not `DFHBMPRF`: X'61' would set MDT on MSG and make the transmitted set
  depend on the attribute's protected bit, which the scenarios do not need.
* No cursor position is asserted after the echo sends (no `CURSOR` option, and the final cursor
  of `DATAONLY` is release-dependent). The first display has IC.
* The `HXM3I` flag bytes after RECEIVE MAP are not shown, only data. The echoed fields have no
  program attribute, so no attribute byte is logged for them.
* `ERASEAUP` is the only erase option used; combining it with `ERASE` is not exercised.
* The task does not depend on whether an MDT-on field with all blanks is transmitted: the
  operator types real data and NOTE holds `KEEP`.

Lower-confidence points: the wording of the FRSET/ERASEAUP text was read from the SEND MAP page
and the 3270 Data Stream Programmer's Reference (GA23-0059, Erase All Unprotected order); the
reviewer should re-read both against the logs. No quote above is a verbatim copy.

## Citations

* [BUILD-SCREEN] CICS TS 6.x, Building the output screen: https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-building-output-screen
* [DFHMDF] CICS TS 6.x, DFHMDF macro (ATTRB defaults, IC, JUSTIFY): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
* [BMS-CONST] CICS TS 6.x, BMS constants (DFHBMPRO, DFHBMFSE): https://www.ibm.com/docs/en/cics-ts/6.x?topic=reference-bms-constants
* [3270-ATTR] CICS TS 5.4, 3270 field attributes (MDT): https://www.ibm.com/docs/en/cics-ts/5.4.0?topic=terminals-3270-field-attributes
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP (MAPFAIL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [SEND-MAP] CICS TS 6.x, EXEC CICS SEND MAP (DATAONLY, FRSET, ERASEAUP): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map
* [RETURN] CICS TS 6.x, EXEC CICS RETURN: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [RESP-CODES] CICS TS 6.x, RESP and RESP2 values: https://www.ibm.com/docs/en/cics-ts/6.x?topic=application-resp-resp2-values
* GA23-0059, 3270 Data Stream Programmer's Reference (Erase All Unprotected, field attribute MDT).
