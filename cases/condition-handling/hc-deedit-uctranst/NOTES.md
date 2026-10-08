# hc-deedit-uctranst: BIF DEEDIT edits a field in place, and a terminal's UCTRANST is a CVDA

## The trap

`HCDEED` (transaction `HC41`) is typed with a mode after the transid and logs what each command did to TS queue `HCLOG`
(BIF DEEDIT, INQUIRE and SET are not events, SPEC 6.2):

* **D** issues `EXEC CICS BIF DEEDIT FIELD(f) LENGTH(n)` on five fields, then once with `LENGTH(0)` and `RESP`. A BMS
  program uses DEEDIT to turn a typed field such as `14-6704/B` or `$25.68` into digits it can test with `NUMERIC`.
  Item format: tag (3), the field after the command (9, blank padded), ` R=`, RESP (2): 17 bytes.
* **U** asks `INQUIRE TERMINAL(EIBTRMID) UCTRANST(area)`, sets it with `SET TERMINAL(EIBTRMID)
  UCTRANST(DFHVALUE(NOUCTRAN))` and `DFHVALUE(TRANIDONLY)`, asks again, then tries an invalid CVDA (999) and a terminal
  that is not defined (`'ZZZZ'`) for both commands. Item format: tag (3), the CVDA the INQUIRE returned (9 digits; zeros
  for a SET or a failure), ` R=`, RESP (2), ` 2=`, RESP2 (2, `--` when the command succeeded): 22 bytes.
* **L** issues the DEEDIT with `LENGTH(0)` and no `RESP`, `NOHANDLE` or handler.

## Why a naive translation breaks

* A port that strips every non-digit and left-aligns, or that keeps the field's length by padding on the right, gets
  `14-6704/B` wrong: CICS right-aligns the digits and pads on the left with zeros, and leaves a rightmost byte whose zone
  is X'A'-X'F' as it is (`00146704B`).
* A port that drops a trailing minus sign loses the sign: CICS puts the negative zone X'D' in the rightmost byte
  (`123-` becomes X'F0F1F2D3').
* A port that treats `DFHVALUE(NOUCTRAN)` as a string, or takes the UCTRANST CVDAs for 0 / 1 / 2, moves the wrong number:
  UCTRAN is 450, NOUCTRAN 451, TRANIDONLY 452.
* A port that answers every `INQUIRE TERMINAL` NORMAL, or never raises INVREQ for a CVDA that is none of the three,
  hides TERMIDERR and INVREQ RESP2 43.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display whose TYPETERM `CRU3278` says `UCTRAN(YES)` (SPEC 2: a case may
state it). Every scenario starts at 10:00:00 with `HC41 <mode>` typed on T001. The code page is EBCDIC CCSID 037, so
the DEEDIT results below are in that page: X'D3' is the letter `L`, X'C2' is `B`, X'C3' is `C`.

* **`deedit`** (D):
  * D1: `14-6704/B`, a 9-byte field, is IBM's own first example: "14-6704/B" returns "00146704B" [DEEDIT]. Characters other
    than digits are removed, the digits are right-aligned and padded on the left with zeros, and "If the zone portion of
    the rightmost byte contains one of the characters X'A' through X'F', the rightmost byte is returned unaltered": the
    rightmost byte `B` is X'C2'. Item: `D1 00146704B R=00`.
  * D2: `$25.68` in a 9-byte field returns `000002568` [DEEDIT] ("A decimal point is an EBCDIC special character and as
    such is removed"). The field is `$25.68` and three blanks; blanks are removed like the other special characters, and the
    rightmost byte, a blank (X'40'), has zone 4. Item: `D2 000002568 R=00`.
  * D3: `123-`: "If the field ends with a minus sign or a carriage-return (CR), a negative zone (X'D') is placed in the
    rightmost (low-order) byte" [DEEDIT]. The digits 1 2 3 are right-aligned in the 4 bytes, `0 1 2 3`, and the
    rightmost gets zone D: X'F0 F1 F2 D3', `012L`. Item: `D3 012L      R=00`.
  * D4: `A`, a 1-byte field: "A 1-byte field is returned unaltered, no matter what the field contains" [DEEDIT]. Item:
    `D4 A         R=00`.
  * D5: `ab12cd3C`: lower-case letters are X'81' X'82' ... zone 8, removed; the rightmost byte `C` is X'C3', zone C:
    returned unaltered, "This permits the application program to operate on a zoned numeric field" [DEEDIT]. The digits
    1 2 3 are right-aligned before it: `0000123C`. Item: `D5 0000123C  R=00`.
  * D6: `LENGTH(0)`: "LENGERR ... This condition occurs if the LENGTH value is less than 1" [DEEDIT]. RESP is given, so no
    abend; LENGERR is 22 [RESP-CODES]. The field is not read afterwards. Item: `D6          R=22`.
  * The program sends `DONE OK` and RETURNs.
* **`uctranst`** (U):
  * U1: INQUIRE TERMINAL UCTRANST returns the CVDA of the terminal's UCTRAN: "UCTRAN: Input is translated to uppercase on
    receipt" [INQUIRE-TERMINAL], and the value "comes from the UCTRAN option of the associated TYPETERM definition":
    `UCTRAN(YES)` is UCTRAN, 450 [CVDA]. Item: `U1 000000450 R=00 2=--`.
  * U2: `SET TERMINAL(EIBTRMID) UCTRANST(DFHVALUE(NOUCTRAN))` (451 [CVDA]) is NORMAL. U3: the INQUIRE now returns 451.
    U4 / U5: `DFHVALUE(TRANIDONLY)` (452), then the INQUIRE returns 452.
  * U6: `UCTRANST(WS-BAD)` with 999, which is no UCTRANST CVDA: INVREQ with RESP2 43, "Invalid UCTRANST CVDA"
    [SET-TERMINAL]. INVREQ is 16 [RESP-CODES]. Item: `U6 000000000 R=16 2=43`.
  * U7: `INQUIRE TERMINAL('ZZZZ')`: the region has the one terminal T001 (SPEC 2), so `ZZZZ` is not defined: TERMIDERR
    (11), RESP2 1, "The named terminal cannot be found" [INQUIRE-TERMINAL]. Item: `U7 000000000 R=11 2=01`.
  * U8: `SET TERMINAL('ZZZZ')`: TERMIDERR, RESP2 23, "The named terminal cannot be found" [SET-TERMINAL]. Item:
    `U8 000000000 R=11 2=23`.
  * The program sends `DONE OK` and RETURNs.
* **`lengerr-abend`** (L): the program writes `L1 BEFORE`, then issues the DEEDIT with `LENGTH(0)` and no RESP, NOHANDLE or
  handler: LENGERR's "Default action: terminate the task abnormally" [DEEDIT], abend code AEIV for LENGERR [AEIA]. The
  item written before it stays (SPEC 2: non-recoverable queues); the second `L1 BEFORE` is never written. The task ends
  `abend`.

## What a correct port must do

* Edit FIELD in place as IBM describes: remove everything but the digits, right-align them with zero fill on the left,
  give the rightmost byte the negative zone D for a trailing minus or CR, return a rightmost byte with zone A-F and a
  1-byte field unaltered, and raise LENGERR (RESP 22) for a LENGTH below 1.
* Know the CVDA numbers: `DFHVALUE(UCTRAN)` 450, `NOUCTRAN` 451, `TRANIDONLY` 452.
* Answer INQUIRE TERMINAL UCTRANST from the terminal's TYPETERM and SET TERMINAL UCTRANST from then on, with INVREQ
  RESP2 43 for another number and TERMIDERR (RESP2 1 for INQUIRE, 23 for SET) for a terminal that is not defined.

## Avoided ambiguities

* **What a field with no digit left becomes** (`abc`): IBM does not say. No field here is without a digit or a rightmost
  zoned byte.
* **A sign followed by blanks**, or a minus sign that is not the last byte: "ends with" is read literally and no field
  here depends on it (D3's field is exactly `123-`).
* **CR together with the zoned-byte rule.** `CR` ends in X'D9', a zoned byte. No field here ends in CR.
* **RESP2 of LENGERR.** The DEEDIT page lists none; the items log RESP only.
* **The field after LENGERR.** Not read.
* **BIF DEEDIT without LENGTH in COBOL.** Every command here gives LENGTH.
* **When a SET TERMINAL UCTRANST takes effect**, and whether it outlives the task: the page says neither. No task here
  RECEIVEs after a SET (HCDEED RECEIVEs first), and each scenario is one task.
* **The UCTRANST of a terminal whose TYPETERM says nothing**: the CSD states `UCTRAN(YES)`.
* **Remote terminals.** T001 is local.

## Citations

* [DEEDIT] CICS TS 6.x, EXEC CICS BIF DEEDIT (description, the examples "14-6704/B" -> "00146704B" and "$25.68" ->
  "000002568", the negative zone, the rightmost byte, the 1-byte field, LENGERR):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-bif-deedit
* [INQUIRE-TERMINAL] CICS TS 6.x, INQUIRE TERMINAL (UCTRANST, TERMINAL, TERMIDERR RESP2 1):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-terminal
* [SET-TERMINAL] CICS TS 6.x, SET TERMINAL (UCTRANST, INVREQ RESP2 43, TERMIDERR RESP2 23):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-set-terminal
* [CVDA] CICS TS 6.x, CVDAs and numeric values in alphabetic sequence (UCTRAN 450, NOUCTRAN 451, TRANIDONLY 452):
  https://www.ibm.com/docs/en/SSJL4D_6.x/pdf/api-reference_pdf.pdf
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, TERMIDERR 11, LENGERR 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [AEIA] CICS TS 6.x, abend codes AEIx (AEIV: LENGERR):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aeia
