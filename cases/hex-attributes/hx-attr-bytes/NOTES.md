# hx-attr-bytes: raw 3270 attribute bytes in a BMS map

## The trap

`HXATTR` (transaction `HX01`) sends map `HXM1` and fills the attribute (`xxxA`) byte of each
field in a different way:

| Field | How the program sets `A` | Byte |
|---|---|---|
| STAT | `DFHBMPRO` (a DFHBMSCA name) | X'60' |
| BRITE | literal `X'E8'` (= DFHPROTI); data `O` starts with a null | X'E8' |
| SECRET | literal `X'4D'` (= DFHUNNOD) | X'4D' |
| RAW | literal `X'3C'`, a byte that is not an EBCDIC graphic | X'3C' |
| BLINKY | literal `X'F1'`, written as if it meant "blink" | X'F1' |
| TWIDDLE | `DFHBMUNP` + 1 by binary arithmetic (sets the MDT bit) | X'41' |
| LEFTOVR | `DFHBMEOF`: the "field erased" *input* flag | X'80' |
| NULATR | nothing (X'00'), program data only | — |
| NAME, FSETF | nothing, no data | — |

On the next ENTER it receives the map and echoes it with `SEND MAP DATAONLY`. On CLEAR it
resends the bare map with `MAPONLY`.

## Why a naive translation breaks

* **Bytes are not characters.** On z/OS the program's literal `X'F1'` is the EBCDIC byte
  F1, the character '1'. On an ASCII JVM the same literal is `ñ`, and DFHBMSCA's `'1'` is
  0x31. A port that maps attributes through characters, or copies hex literals as ASCII
  bytes, gets the wrong 3270 byte and the wrong meaning.
* **The meaning lives in the bits.** X'F1' in an attribute byte is protected + numeric
  (autoskip) + MDT on. It does not blink. Blink is an *extended highlighting* value (X'F1'
  in the `H` byte of a map with DSATTS=HILIGHT; see hx-extended-cursor). X'41' and X'C1' mean
  the same thing (bits 2-7 are equal), and so do X'3C' and X'7C'. A port that switch-cases on
  the DFHBMSCA values misses X'41' and X'3C'.
* **Some bytes are not attributes at all.** BMS takes the program's attribute byte only when
  it is not X'00', X'80', X'02' or X'82'. Those are the null and the input flags left by a
  RECEIVE MAP. For LEFTOVR, X'80' means "use the map's ATTRB". A port that writes the byte
  it finds sends X'80'.
* **One null byte decides the data source.** BRITEO holds `?GNORED` with a null first byte.
  BMS then sends the map's INITIAL (`INITIAL-TEXT`), not the program's data. A port that
  strips nulls, or checks "all nulls", shows `GNORED`.
* **The MDT bit changes the next task's input.** SECRET (X'4D'), BLINKY (X'F1'), TWIDDLE
  (X'41') and FSETF (map FSET) all have the MDT on. The terminal transmits them on the next
  ENTER even though the operator did not touch them, so they reach RECEIVE MAP and are echoed.
  RAW (X'3C') has MDT off and is not transmitted.
* **DATAONLY omits fields.** A field with null data and no program attribute is not sent at
  all. It is not blanked.

## Expected behaviour

**Attribute bits** (3270 Data Stream Programmer's Reference GA23-0059, "Field attribute";
the CICS summary is [3270-ATTR]): bit 2 (X'20') protected, bit 3 (X'10') numeric (protected +
numeric = autoskip), bits 4-5 (X'0C') display: 00 normal, 01 normal/detectable, 10 bright,
11 nondisplay. Bit 7 (X'01') is the MDT. Bits 0-1 carry no meaning; they are set only to make
the byte a graphic character. Each event's `meaning` is decoded from bits 2-7 only.

**Where each value comes from** [BUILD-SCREEN]:
* Field attribute: from the program when MAPONLY is not given, the field is named, and the
  byte is not X'00', X'80', X'02' or X'82'. Otherwise, without DATAONLY, from the map's
  ATTRB. Under DATAONLY with no program value, BMS sends no attribute.
* Data: from the program when "the first character of the data" is not null. Otherwise,
  without DATAONLY, the map's INITIAL (nulls if none). Under DATAONLY, only program data is
  sent.
* ERASE clears the buffer first.

Map defaults (DFHMDF ATTRB [DFHMDF]): (ASKIP,NORM) → X'F0'; (ASKIP,BRT) → X'F8';
(UNPROT,NORM) → X'40'; (UNPROT,NORM,FSET) → X'C1'. IC only places the cursor [DFHMDF].

**`first-display`** (task 1, `HX01` typed, EIBCALEN 0): SEND MAP ERASE. Every field as in
the `fields` table of the expected log. The cursor is at NAME (IC). The task then does RETURN
TRANSID('HX01') COMMAREA LENGTH(1) [RETURN].

**`echo-dataonly`** (task 2 at +30s, ENTER, EIBCALEN 1 [RETURN]):
* The operator typed `JONES` into NAME and pressed ERASE EOF in LEFTOVR. The terminal
  transmits every field whose MDT is on: NAME, LEFTOVR (with no data), SECRET, BLINKY,
  TWIDDLE and FSETF (the last four keep the MDT the program or map set). The 3270 sends no
  nulls; the blanks after `BLINK?` were sent by the program as data, so they come back.
* `MOVE LOW-VALUES TO HXM1I`, then RECEIVE MAP [RECEIVE-MAP]. Received fields hold their
  data, left-justified and blank-padded (JUSTIFY=(LEFT,BLANK) [DFHMDF]); NAME = `JONES     `.
  LEFTOVR has length 0, and its flag byte shows the field was erased (DFHBMEOF "Field erased"
  [BMS-CONST]). Fields not received stay as the program left them: nulls.
* STAT gets `DFHBMPRF` (X'61') and `RECEIVED`. SEND MAP DATAONLY sends STAT (program attr and
  data), plus NAME, SECRET, BLINKY, TWIDDLE and FSETF with data only (their A bytes are X'00',
  so no attribute is sent). BRITE, RAW and NULATR (nulls, attr X'00') and LEFTOVR (nulls,
  flag X'80' or X'00') are not sent. The task then RETURNs with no TRANSID.

**`clear-maponly`** (task 2, CLEAR): no data is transmitted with CLEAR. The program tests
EIBAID first and never issues RECEIVE MAP, so there is no MAPFAIL. SEND MAP MAPONLY ERASE
takes everything from the map. The ATTRB bytes are as listed above, and the data is INITIAL
where one exists (nulls otherwise). The cursor is at NAME (IC). RETURN TRANSID('HX01')
continues the conversation.

## What a correct port must do

* Keep attribute bytes as **EBCDIC byte values**, 0x00-0xFF, end to end. Never route them
  through characters.
* Decide program vs map vs nothing per BMS's rules: the four excluded byte values, the
  first-byte-null rule for data, and MAPONLY/DATAONLY. Emit the byte unchanged, including
  X'3C' and X'41'.
* Derive protection, display and MDT from bits 2-7, and carry the MDT into what the next
  RECEIVE MAP returns.

## Avoided ambiguities

* **What the terminal does with a non-graphic attribute byte** (RAW, X'3C'). The expected
  log asserts only the byte BMS sends and its meaning by bits 2-7. That the 3270 ignores
  bits 0-1 is the reading of GA23-0059 used here. No later step depends on how RAW is
  displayed: it is not transmitted, because its MDT bit is off.
* **Whether BMS passes X'3C' and X'41' through unchanged.** [BUILD-SCREEN] takes any
  program value outside the four excluded bytes. No documentation says BMS normalises it.
  Listed as a lower-confidence point in the README.
* **Flag byte of an erased field.** X'80' is inferred from DFHBMEOF ("Field erased"). The
  case does not depend on it: X'80' and X'00' are both "not present" to BMS on output.
* **INITIAL shorter than the field**, and whether BMS pads it, is avoided: every INITIAL is
  exactly the field length.

## Citations

* [BUILD-SCREEN] CICS TS 6.x, Building the output screen ("Where the values come from"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-building-output-screen
* [DFHMDF] CICS TS 6.x, DFHMDF macro (ATTRB defaults, FSET, IC, DRK, JUSTIFY, INITIAL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
* [BMS-CONST] CICS TS 6.x, BMS constants (DFHBMSCA: DFHBMPRO, DFHBMPRF, DFHBMUNP, DFHBMEOF, DFHUNNOD, DFHPROTI ...): https://www.ibm.com/docs/en/cics-ts/6.x?topic=reference-bms-constants
* [3270-ATTR] CICS TS 5.4, 3270 field attributes (protection, MDT, intensity): https://www.ibm.com/docs/en/cics-ts/5.4.0?topic=terminals-3270-field-attributes
* 3270 Data Stream Programmer's Reference, GA23-0059, chapter "Field attribute" (bit definitions, graphic-converter bits 0-1).
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [SEND-MAP] CICS TS 6.x, EXEC CICS SEND MAP (ERASE, MAPONLY, DATAONLY): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map
* [RETURN] CICS TS 6.x, EXEC CICS RETURN (TRANSID, COMMAREA, EIBCALEN of the next task): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
