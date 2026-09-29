# hx-extended-cursor: extended attributes, the cursor, and NUM fields

## The trap

`HXEXT` (transaction `HX02`) uses map `HXM2`, which has `DSATTS=(COLOR,HILIGHT)`. So every
named field has three program-settable attribute bytes: `A` (the 3270 field attribute), `C`
(extended colour) and `H` (extended highlighting). The same hex value means different things
in each:

* In `H`, X'F1' is **blink** (DFHBLINK). In `C`, X'F1' is **blue** (DFHBLUE), and X'F2' is
  red (DFHRED). In `A`, X'F1' is **autoskip + MDT** (DFHBMASF).
* On a validation error the program re-sends the account field bright with MDT (DFHUNIMD
  X'C9'), red and blinking, and puts the cursor there by moving **-1 to the length field**
  and giving `CURSOR` with no value (symbolic cursor positioning).
* `AMOUNT` is `ATTRB=(UNPROT,NUM,...)` with `JUSTIFY=(RIGHT,ZERO)`. Input typed `125`
  arrives as `0000125`.
* PF5 shows the classic mistake: `MOVE X'F1' TO MSGA`, meant as blink. Next to it is the
  correct `MOVE DFHBLINK TO ACCTH`.

## Why a naive translation breaks

* A port that models "attributes" as one value per field, or maps DFHBMSCA names to UI
  flags by name, cannot tell X'F1'-in-A from X'F1'-in-H. PF5 makes MSG autoskip with the MDT
  on. It does not blink.
* `MOVE -1 TO ACCTL` writes into the *input* length subfield. The same bytes are the output
  structure's FILLER. BMS reads it on output as the symbolic cursor request. A port that
  treats the input and output views as separate objects loses the cursor.
* A port that moves typed text into the input field as-is gets `125    ` for AMOUNT, not
  `0000125`, and the message differs.
* The map's own COLOR/HILIGHT values are sent when the program supplies none, and only then.
  Under DATAONLY, fields with nothing from the program get nothing.

## Expected behaviour

Values [BMS-CONST] (3270 Data Stream Programmer's Reference GA23-0059, extended field
attribute types X'41' highlighting and X'42' colour): colours blue F1, red F2, pink F3,
green F4, turquoise F5, yellow F6, neutral F7. Highlighting: blink F1, reverse F2,
underscore F4. The terminal supports extended attributes (CSD TYPETERM `EXTENDEDDS(YES)
COLOR(YES) HILIGHT(YES)`; SPEC section 2), which [BUILD-SCREEN] requires before BMS sends
them.

**Task 1 (every scenario)**: `HX02` typed, EIBCALEN 0. `MOVE LOW-VALUES TO HXM2O`, MSG data
from the program, SEND MAP ERASE. Per [BUILD-SCREEN]:
* Base attributes come from ATTRB: ACCT (UNPROT,NORM,IC) X'40'; AMOUNT (UNPROT,NUM,NORM)
  X'50'; MSG (ASKIP,NORM) X'F0'.
* Extended attributes come from the field's own COLOR=/HILIGHT=, else the map's, else the
  mapset's, else nothing (the hardware default). ACCT: green F4 and underscore F4. AMOUNT:
  green F4, no highlight. MSG: yellow F6, no highlight.
* The cursor is at ACCT (IC).
* RETURN TRANSID('HX02') COMMAREA LENGTH(1).

**`bad-account`** (ENTER, ACCT `AB12`, AMOUNT `125`): RECEIVE MAP [RECEIVE-MAP]. ACCTL = 4,
so the check fails. The program sets ACCTL = -1, ACCTA = DFHUNIMD (X'C9'), ACCTC = DFHRED
(X'F2'), ACCTH = DFHBLINK (X'F1') and a message, then does SEND MAP DATAONLY CURSOR ALARM.
"Symbolic cursor positioning is assumed" when CURSOR has no value [SEND-MAP]: BMS puts the
cursor on the field whose length subfield is -1, here ACCT. DATAONLY sends only what the
program supplied [BUILD-SCREEN]:
* ACCT: all three attributes plus its received data `AB12` (left-justified, blank-padded).
* AMOUNT: data only, `0000125`. "If JUSTIFY is omitted, but the NUM attribute is
  specified, RIGHT and ZERO are assumed", and here it is explicit [DFHMDF].
* MSG: data only.
The input structure's extended-attribute bytes are FILLER. The program cleared them with
LOW-VALUES before the RECEIVE, so AMOUNT and MSG carry no C or H byte.

**`good-entry`** (ACCT `123456`): the check passes. MSG = `OK 123456 AMOUNT 0000125`. SEND
MAP DATAONLY sends the three fields' data. No attribute is sent, and no cursor is requested.

**`pf5-blink`** (PF5, nothing typed): the program does not RECEIVE. It sets MSGA = X'F1',
MSGO = `BLINK REQUESTED`, ACCTA = DFHBMUNP (X'40') and ACCTH = DFHBLINK, then SEND MAP
DATAONLY.
* MSG goes out with attribute F1: protected + numeric (autoskip), normal, **MDT on**. MSG is
  now transmitted on every later ENTER.
* ACCT goes out with attribute 40 and highlight F1, the real blink.
* AMOUNT is not sent.

## What a correct port must do

* Keep the A, C and H bytes as separate byte-valued properties with their own decoding
  tables.
* Implement symbolic cursor positioning from the length subfield.
* Resolve each extended attribute through the field → map → mapset → hardware-default
  chain.
* Apply JUSTIFY (RIGHT,ZERO for NUM) when building the input structure.

## Avoided ambiguities

* Several fields with -1 in their length subfield (BMS takes the first) are not used: only
  one field ever has -1.
* X'FF' / X'00' "default" extended values (DFHDFT, DFHDFCOL, DFHDFHI), and how BMS encodes
  a request for the hardware default, are not used.
* Under DATAONLY, a field is never given an extended attribute without a base attribute. So
  the case never depends on how BMS writes an extended attribute alone (SA or MF orders vs
  SFE). In pf5-blink, ACCT gets both A and H.
* Whether RECEIVE MAP writes the input structure's FILLER bytes for extended attributes:
  the program pre-fills them with LOW-VALUES, so the result is the same either way.

## Citations

* [BUILD-SCREEN] CICS TS 6.x, Building the output screen (extended attribute hierarchy, DATAONLY, terminal support): https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-building-output-screen
* [SEND-MAP] CICS TS 6.x, EXEC CICS SEND MAP (CURSOR, ALARM, DATAONLY, ERASE): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [DFHMDF] CICS TS 6.x, DFHMDF macro (ATTRB, COLOR, HILIGHT, IC, JUSTIFY defaults for NUM): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
* [BMS-CONST] CICS TS 6.x, BMS constants (DFHUNIMD, DFHBMUNP, DFHRED, DFHBLINK, DFHBMASF): https://www.ibm.com/docs/en/cics-ts/6.x?topic=reference-bms-constants
* 3270 Data Stream Programmer's Reference, GA23-0059: "Field attribute", "Extended highlighting" (type X'41'), "Color" (type X'42').
* CICS TS Application Programming Guide, "Positioning the cursor" (symbolic cursor positioning with -1 in the length subfield).
