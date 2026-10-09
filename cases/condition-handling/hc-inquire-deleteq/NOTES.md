# hc-inquire-deleteq: INQUIRE ASSOCIATION origin data, DELETEQ TS removes a whole queue, RECEIVE MAP ... TERMINAL

## The trap

`HCINQD` (transactions `HC61`, `HC62`) is typed with a mode after `HC61` and logs what each command did to TS queue `HCLOG`
(INQUIRE and DELETEQ are not events, SPEC 6.2):

* **I** issues `EXEC CICS INQUIRE ASSOCIATION(EIBTASKN) ODAPPLID(..) ODUSERID(..) ODFACILNAME(..) ODNETWORKID(..)
  ODFACILTYPE(..) RESP(..) RESP2(..)` (eight-character areas and a fullword for the facility type), then the same command
  with only `ODNETWORKID` and `ODFACILTYPE` and no `RESP`. Item format: tag (3), applid (8), a blank, userid (8), a blank,
  facility name (8), a blank, network id (8), ` T=`, the facility type (9 digits), ` R=`, RESP (2): 55 bytes.
* **D** writes items `ONE` and `TWO` to queue `HCQ`, reads the first with `READQ TS ... NEXT`, then `DELETEQ TS
  QUEUE('HCQ') RESP(..)`, reads item 1 (`QIDERR`), deletes the queue again, writes `THREE` (a new queue) and reads it with
  `NEXT`, and finally `DELETEQ TS QUEUE(area)` where the 8-byte area holds binary zeros. Item format: tag (3), ` R=`,
  RESP (2): 8 bytes.
* **M** (`HC61 M`) sends map `HCM2` and RETURNs `TRANSID('HC62')`; the operator types `Mixed cAsE` in the field `NAME`;
  `HC62` issues `RECEIVE MAP('HCM2') MAPSET('HCSET2') INTO(..) TERMINAL ASIS RESP(..)` (the form CBSA's screen programs use)
  and logs the field. Item: tag (3), the field (12), ` R=`, RESP (2): 20 bytes.

## Why a naive translation breaks

* A port that does not know `INQUIRE ASSOCIATION` cannot translate the program at all; one that returns the facility type as a
  string, or as a number other than the CVDA (`TERMINAL` is 213), stores the wrong fullword; one that fills the areas the
  command did not name (`I2`) overwrites the program's own data.
* A port that keeps a deleted queue's items, or its `NEXT` position, answers `READQ TS` after `DELETEQ TS` as if the queue were
  still there, and does not raise `QIDERR` for the second `DELETEQ TS`.
* A port that treats a queue name of binary zeros as a queue like any other deletes nothing and answers NORMAL.
* A port that does not accept `TERMINAL` after `INTO(..)` cannot translate the program.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display (`CRU3278`, no UCTRAN stated: this case reads no `UCTRANST`). The case
states the origin of the tasks terminal input starts (SPEC 2, `origin` in case.json): applid `CRUAPPL1`, user `CICSUSER` (the
default user: nobody signs on), facility name `T001`, network id `CRUNET01`, facility type `TERMINAL`. Every scenario starts at
10:00:00 on 2026-03-02 with `HC61 <mode>` typed on T001. The code page is EBCDIC CCSID 037.

* **`origin`** (I):
  * I1: `INQUIRE ASSOCIATION` "Specifies the 4-byte number of the task for which you want to retrieve association data"
    [INQUIRE-ASSOCIATION]; `EIBTASKN` is the task's own number. ODAPPLID "Returns the 8-character APPLID taken from the
    origin descriptor associated with this task", ODUSERID "the 8-character user ID under which the originating task ran",
    ODFACILNAME "the 8-character name of the facility", ODNETWORKID "the 8-character network qualifier for the origin region
    APPLID", ODFACILTYPE "a CVDA value identifying the type of facility" [INQUIRE-ASSOCIATION]. The pages do not say what a
    terminal-started task's origin holds, so the case states it (SPEC 2); the log therefore proves that each value reaches
    its own area, in its width, and the facility type as the CVDA of `TERMINAL`, 213 [CVDA]. NORMAL. Item:
    `I1 CRUAPPL1 CICSUSER T001     CRUNET01 T=000000213 R=00`.
  * I2: only `ODNETWORKID` and `ODFACILTYPE` are named, so the other three areas, cleared to blanks by the program, stay
    blank (each option returns "to" its own area). No `RESP`, `RESP2` or `NOHANDLE`: no condition is raised. Item:
    `I2` + 25 blanks + ` CRUNET01 T=000000213 R=00` (three blank areas and their separators).
  * The program sends `DONE OK` and RETURNs.
* **`deleteq`** (D): "Every condition below has the default action of terminating the task abnormally" [DELETEQ-TS].
  * `HCQ` gets `ONE` (item 1) and `TWO` (item 2); `READQ TS ... NEXT` returns `ONE` (3 bytes into the 5-byte area, NORMAL).
  * D1: `DELETEQ TS QUEUE('HCQ')` is NORMAL: the queue exists. The queue is gone with its items. Item: `D1  R=00`.
  * `READQ TS QUEUE('HCQ') ITEM(1)`: QIDERR, "The queue can't be found" [DELETEQ-TS lists it for DELETEQ; READQ TS: QIDERR when
    the queue does not exist, [READQ-TS]]. RESP is QIDERR, 44 [RESP-CODES]. Event `READQ-TS` item 1, QIDERR, no data. Item:
    `D2  R=44`.
  * D3: `DELETEQ TS QUEUE('HCQ')` again: QIDERR (44), "The queue can't be found in main or auxiliary storage" [DELETEQ-TS].
    Item: `D3  R=44`.
  * `WRITEQ TS QUEUE('HCQ') FROM('THREE')` creates a queue: its first item is item 1 [WRITEQ-TS]. `READQ TS ... NEXT` reads
    the first item, `THREE`: a queue deleted and written again is a new queue, with no item read yet. Item: `D4  R=00`.
  * D5: `DELETEQ TS QUEUE(area)` with the 8-byte area all binary zeros: INVREQ "The queue name is all binary zeroes"
    [DELETEQ-TS]. INVREQ is 16 [RESP-CODES]. Item: `D5  R=16`. IBM lists no RESP2 for DELETEQ TS, and the case logs none.
  * The final TS state: `HCQ` holds `THREE`; `HCLOG` the five breadcrumbs.
* **`receive-terminal`** (M): task 1 sends `HCM2` (the field `NAME` is `ATTRB=(UNPROT,NORM,IC,FSET)`: attribute X'C1', SPEC 6.3)
  and RETURNs `TRANSID('HC62')`. At 10 s the operator types `Mixed cAsE` and presses ENTER. Task 2 (`HC62`) RECEIVEs the map
  with `TERMINAL`: it "specifies that input data is to be read from the terminal that originated the transaction"
  [RECEIVE-MAP], which is T001, the one terminal the region has; `ASIS`: "lowercase characters in the 3270 input data stream are
  not translated to uppercase" [RECEIVE-MAP]. The field is `Mixed cAsE`. NORMAL. Item: `M1 Mixed cAsE   R=00`.

## What a correct port must do

* Accept `INQUIRE ASSOCIATION(EIBTASKN)` with the origin options, writing each named area only, the facility type as its CVDA.
* Delete a TS queue as a whole with `DELETEQ TS`: QIDERR for a queue that is not there, INVREQ for a name of binary zeros; a
  queue written afterwards is new.
* Accept `TERMINAL` in `RECEIVE MAP`, reading the task's terminal.

## Avoided ambiguities

* **What the origin data of a terminal-started task holds** (applid, network id, user, facility): IBM's pages describe the
  fields but not their values for a terminal task. The case states them (SPEC 2); no log claims a value IBM would choose.
* **INVREQ RESP2 2** ("The command was specified with no arguments") of INQUIRE ASSOCIATION: it does not say whether
  `ASSOCIATION` alone counts as none. Every command here names at least one origin option.
* **TASKIDERR / NOTAUTH** of INQUIRE ASSOCIATION: the task asks for its own number, and the region has no security.
* **RESP2 of DELETEQ TS**: the page lists none, so no log item carries it.
* **ISCINVREQ, SYSIDERR, LOCKED, NOTAUTH** of DELETEQ TS: no SYSID, local non-recoverable queues, no security.
* **What a RECEIVE MAP without ASIS does** on a UCTRAN terminal: this terminal states no UCTRAN and every RECEIVE MAP has ASIS.
* **The NEXT position of a queue written again after DELETEQ TS** is a reading, listed in the README's lower-confidence table.

## Citations

* [INQUIRE-ASSOCIATION] CICS TS 6.x, CICS SPI command INQUIRE ASSOCIATION (ASSOCIATION, ODAPPLID, ODUSERID, ODFACILNAME,
  ODNETWORKID, ODFACILTYPE; INVREQ RESP2 2, NOTAUTH RESP2 100, TASKIDERR RESP2 1):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-association
* [DELETEQ-TS] CICS TS 6.x, EXEC CICS DELETEQ TS (QUEUE, INVREQ 16, QIDERR 44):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-deleteq-ts
* [READQ-TS] CICS TS 6.x, EXEC CICS READQ TS (NEXT, ITEM, QIDERR): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-readq-ts
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS (ITEM numbered from 1): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP (TERMINAL, ASIS):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [CVDA] CICS TS 6.x, API Reference, CVDAs and numeric values (TERMINAL 213):
  https://www.ibm.com/docs/en/SSJL4D_6.x/pdf/api-reference_pdf.pdf
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, QIDERR 44):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
