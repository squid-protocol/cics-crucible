# gt-urimap-browse: a browse of the installed URIMAPs (INQUIRE URIMAP START / NEXT / END) and a console message

## The trap

`GTUBROW` (transaction `GT61`) browses the URIMAP definitions installed in the region, the way a "start
one task per matching definition" utility does: `INQUIRE URIMAP START`, then `INQUIRE URIMAP(name) PATH(path)
TRANSACTION(tran) NEXT` until the response is not NORMAL, then `INQUIRE URIMAP END`, then
`WRITE OPERATOR TEXT(...)`. The CSD defines four URIMAPs, each with an alias transaction, and `GTUBROW` counts
them in ways that do not depend on the order of the browse, and starts the alias transaction (`GT62`, program
`GTUNEXT`, which RETRIEVEs it and logs it to `GTUGO`) of the one definition whose name starts `ZC` and whose path
starts `/zecs/`. It logs three items to TS queue `GTUBLOG`:

| Item | Text | What it shows |
|---|---|---|
| 1 | `START 1/2=00/21:0001` | the first START is NORMAL (0); a second START while the browse is open is ILLOGIC (21), RESP2 1 |
| 2 | `DEFS=04 ZC=02 PATH=02 BOTH=01 ST=00` | the browse returned all four definitions; two are named `ZC*` (ZCONE, ZCOTHER), two have a path under `/zecs/` (ZCONE, AAPLAIN), one is both (ZCONE) and its START was NORMAL |
| 3 | `END=83:0002 CLOSE=00 WTO=00` | the NEXT after the last definition is END (83), RESP2 2; the END command and the WRITE OPERATOR are NORMAL |

| Definition | PATH | TRANSACTION | name `ZC*` | path `/zecs/*` |
|---|---|---|---|---|
| `ZCONE` | `/zecs/one` | `GT62` | yes | yes (started) |
| `ZCOTHER` | `/other/x` | `GT62` | yes | no |
| `AAPLAIN` | `/zecs/plain` | `GT62` | no | yes |
| `BBTHREE` | `/three` | `GT62` | no | no |

Scenario `browse` runs `GT61` once; `browse-twice` runs it at 10:00:00 and again at 10:00:10.

## Why a naive translation breaks

* A port that reads `INQUIRE URIMAP` as a lookup (a map from name to attributes) has nothing to answer a nameless
  `START`, and no notion of a cursor: it cannot say END after the last definition, or ILLOGIC for a second START.
* A port that returns the definitions for `NEXT` but forgets that `END` closes the browse leaves the second run's
  START ILLOGIC (`browse-twice`); one that never resets the cursor on END returns END at once on the second run.
* A port that writes the data areas on END (blanks, zeros) changes nothing this case reads, but a port that fails
  to hand back PATH (255 characters) into a longer program area, or hands back only the name, loses the
  `/zecs/` test.
* `WRITE OPERATOR` has no screen and no data effect: a port that treats it as "no operation" with no RESP leaves the
  program's `RESP(WS-WTO)` at its initial `99`, item 3 shows `WTO=99`, and the console event is missing.

## Expected behaviour

Model (SPEC sections 2 and 4): the CSD's resources are installed; one terminal, `T001`; the clock is
2026-03-02T10:00:00; a task takes no time. The order in which a browse returns the definitions is not stated by IBM
(nothing in "INQUIRE URIMAP" or "Browsing resource definitions" says), so the case never uses it: everything the
programs log is a count, and exactly one definition qualifies for the one START.

* **`browse`**: step 0 starts `GT61`.
  * `INQUIRE URIMAP START`: "START ... does not produce any information; it just tells CICS what you are going to do"
    [BROWSE]. RESP NORMAL (00). Then a second `START`: ILLOGIC, RESP2 1, "You have issued a START command when a
    browse of this resource type is already in progress" [URIMAP]. ILLOGIC is RESP 21 [RESP-CODES]. Item 1 is written
    (`START 1/2=00/21:0001`, RESP2 shown as 0001).
  * `NEXT` four times: "browse through all the URIMAP definitions installed in the region, using the browse options
    (START, NEXT, and END)" [URIMAP]; each NEXT "returns one resource definition" [BROWSE]. URIMAP returns "the
    8-character name of a URIMAP definition", PATH "a 255-character data area containing the path component of the
    URL", TRANSACTION "the 4-character name of an alias transaction" [URIMAP]. The areas are `WS-URIMAP` (8 bytes, whose
    first two are `WS-PREFIX`), `WS-PATH` (255) and `WS-TRAN` (4), so every definition is seen whole whatever the order:
    DEFS 4; names `ZCONE`, `ZCOTHER` start `ZC` (ZC 2); paths `/zecs/one`, `/zecs/plain` start `/zecs/` (PATH 2); only
    ZCONE is both (BOTH 1): one `START TRANSID('GT62') INTERVAL(0) FROM(WS-TRAN) LENGTH(4)` with `WS-TRAN` = the
    TRANSACTION of ZCONE, `GT62`. Its RESP is NORMAL (00), so `ST=00` (it is `99` if no START was issued). The START
    event expires at the issue time, 10:00:00 [START].
  * The fifth `NEXT`: END, RESP2 2, "There are no more resource definitions of this type" [URIMAP]. END is RESP 83
    [RESP-CODES]. The loop stops; `END=83:0002`. `INQUIRE URIMAP END` ends the browse: NORMAL (`CLOSE=00`).
    `WRITE OPERATOR TEXT(WS-OPMSG)` sends the 24-byte area `GTUBROW browse finished` (23 characters and a blank) to the console: a WRITE-OPERATOR event (data = the area, resp NORMAL); no
    condition applies to it, NORMAL (`WTO=00`) [WTO]. IBM's text rules ("If the data value begins with DFHnnnn or
    DFHaannnn, the message is treated as a CICS message and is reformatted"; "If the length of the text is greater than
    113 ... multi-line") do not apply: the text starts `GTUB` and is 24 bytes. Items 2 and 3 are written, GTUBROW RETURNs.
  * `GT62` runs once the starter has ended, with no terminal: RETRIEVE returns the 4 bytes `GT62` (NORMAL, LENGTH 4)
    [RETRIEVE], logged to `GTUGO`. `GTUBLOG` ends with 3 items, `GTUGO` with 1.
* **`browse-twice`**: the same at 10:00:00 and at 10:00:10 (step 1). The second run's first START is NORMAL, not ILLOGIC:
  the browse of the first run was ended by its `INQUIRE URIMAP END` [BROWSE]. `GTUBLOG` ends with the three items twice (items 1-3 and 4-6); `GTUGO` with `GT62` twice
  (items 1 and 2: each GT62 task is dispatched after its own starter, at its own second).

## What a correct port must do

* Keep, per task, a browse cursor over the region's installed URIMAP definitions: START opens it (ILLOGIC RESP2 1
  when one is open), NEXT hands back the next definition's name, PATH and TRANSACTION and END with RESP2 2 after the
  last, END closes it.
* Fill the program's areas with what IBM's lengths say (8, 255, 4 characters) and touch nothing past them.
* Give `WRITE OPERATOR` a RESP of NORMAL and send the TEXT area to the console, as a WRITE-OPERATOR event
  (SPEC 6.2, new with this case: an additive event type).

## Avoided ambiguities

* **The browse order.** IBM does not say in which order a browse returns the definitions, so the programs only count
  and exactly one definition passes both tests: no log depends on the order.
* **A NEXT or END with no browse started** is ILLOGIC too, but IBM's page gives it no RESP2 of its own: never issued.
* **What a data area holds after END** (or after ILLOGIC): the program never reads the areas after the loop.
* **A short value's padding** (a transaction shorter than 4, a name shorter than 8): every definition here has a
  4-character TRANSACTION and a name of 5 to 7 characters, and the program tests only the first two characters of the
  name (`ZC`), which no padding changes.
* **A URIMAP with no TRANSACTION** (what TRANSACTION returns then): every definition names one.
* **The console**: the event is the message sent, not what an operator sees; the text is a plain one (no `DFHnnnn` /
  `DFHaannnn` prefix, under 113 characters), so IBM's reformatting rules do not apply.

## Citations

* [URIMAP] IBM CICS TS 6.x, INQUIRE URIMAP (conditions END RESP2 2, ILLOGIC RESP2 1; URIMAP, PATH, TRANSACTION):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-urimap
* [BROWSE] IBM CICS TS 6.x, Browsing resource definitions (START, NEXT, END): https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-browsing-resource-definitions
* [WTO] IBM CICS TS 6.x, EXEC CICS WRITE OPERATOR (TEXT, TEXTLENGTH, the DFHnnnn and 113-character rules): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-write-operator
* [START] IBM CICS TS 6.x, EXEC CICS START (INTERVAL, FROM, LENGTH): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RETRIEVE] IBM CICS TS 6.x, EXEC CICS RETRIEVE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-retrieve
* [RESP-CODES] IBM CICS TS 6.x, Response codes of EXEC CICS commands (ILLOGIC = 21, END = 83): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
