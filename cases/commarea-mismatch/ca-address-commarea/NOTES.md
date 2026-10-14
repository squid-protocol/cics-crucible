# ca-address-commarea: ADDRESS COMMAREA / ADDRESS EIB and SET ADDRESS OF

## The trap

`CAADDR` (transaction `CA02`) and its callee `CAADSB` reach storage through **pointers** that
CICS hands out, not through `DFHCOMMAREA` or a copied parameter. The mode letter typed after
the transaction id picks the scenario:

| Mode | What runs | What it shows |
|---|---|---|
| L | `LINK PROGRAM('CAADSB') COMMAREA(WS-AREA) LENGTH(20)`; the callee issues `ADDRESS COMMAREA(ptr)`, then `SET ADDRESS OF LS-VIEW TO ptr` | the pointer is the caller's own 20 bytes: the callee reads them and its write lands in the caller's `AD-REPLY` |
| N | `ADDRESS COMMAREA(ptr)` in the terminal task (EIBCALEN 0), then a LINK with no COMMAREA whose callee does the same | no COMMAREA: the pointer is the null value `X'FF000000'` |
| E | `ADDRESS EIB(ptr)`, `SET ADDRESS OF LS-EIB TO ptr` | the view equals the `DFHEIBLK` fields the program already has |

ADDRESS is not an event (SPEC 6.2), so each result is a breadcrumb in TS queue `CALOG` and in the
`SEND TEXT` report.

## Why a naive translation breaks

* A port that models a COMMAREA as a typed DTO copied in and out has no pointer to hand
  out. `ADDRESS COMMAREA` must yield a **view of the caller's storage** (as for LINK, see
  `ca-link-lengths`), so that a write through `SET ADDRESS OF` is the caller's write.
* A port that returns a Java `null` or a zero for a missing COMMAREA is wrong at the
  boundary: CICS sets the pointer to `X'FF000000'`. A COBOL program that tests the
  documented value (as `CAADSB` does) takes the "absent" branch only if the port produces
  exactly that value. A port that returns zero sends such a program down the "present"
  branch and into `SET ADDRESS OF` an invalid address.
* `ADDRESS EIB` must give a view of the **same** EIB the task is running with, not a
  snapshot: the view and `DFHEIBLK` must agree field for field.

## Expected behaviour

Every scenario: `CA02 x` typed on a cleared screen. EIBCALEN is 0 for the terminal task, and
`RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)` returns the 6 characters typed (the assumption
shared by the other cases, listed in the README).

* **`link-view`**: the caller builds `WS-AREA` (EYE `CADR`, REQUEST `PING`, REPLY blanks) and
  LINKs with `COMMAREA(WS-AREA) LENGTH(20)`. IBM: "the
  address of the area is passed to the program that is receiving control" and "the linking
  program can both pass data to the program it is invoking and receive results from that
  program" [COMMAREA]. The callee's pointer is therefore the caller's `WS-AREA`. It sees
  EIBCALEN 20, EYE `CADR` and REQUEST `PING` (breadcrumb item 1 `C1  P=PRESENT CALEN=0020
  EYE=CADR REQ=PING    `), moves `PONG` into `VW-REPLY`, and RETURNs. The caller's
  `AD-REPLY` is now `PONG` and the report is `MODE=L REPLY=PONG`.
* **`no-commarea`**: a task started from a terminal has no COMMAREA. EIBCALEN "contains the
  length of the communication area that has been passed to the application program from
  the last program ... If no communication area is passed, this field contains binary
  zeros" [EIB-FIELDS], so EIBCALEN is 0. "If the COMMAREA does not exist, the pointer
  reference is set to the null value, X'FF000000'" [ADDRESS]. `CAADDR` therefore logs item 1
  `N1  P=ABSENT  CALEN=0000 EYE=     REQ=        ` (the same layout, `ABSENT` padded to 7).
  The LINK without COMMAREA gives the callee EIBCALEN 0 (LINK `length` 0, `commarea` null
  in SPEC 6.2) and the same null value, so item 2 is `C1  P=ABSENT  CALEN=0000 EYE=     REQ=        `;
  the callee does not SET ADDRESS OF. The report is `MODE=N P=ABSENT CALEN=0000`.
* **`eib-view`**: "This option returns a pointer reference set to the address of the EXEC
  interface block (EIB)" [ADDRESS]. The view `LS-EIB` is declared over the first five EIB
  fields in IBM's documented order and types (EIBTIME, EIBDATE, EIBTRNID, EIBTASKN, EIBTRMID
  [EIB-FIELDS]). The program compares each with the `DFHEIBLK` field of the same name: all
  agree, `SAME=Y`. Item 1 is `E1 TRN=CA02 TRM=T001 SAME=Y`, the report `MODE=E TRN=CA02
  TRM=T001 SAME=Y`.

The breadcrumb TS items are numbered from 1 in each scenario's own task (a new queue; the
numbering convention as in the other cases).

## What a correct port must do

* Return, for `ADDRESS COMMAREA`, a **view of the caller's bytes** (no copy) when a COMMAREA was
  passed, and the null value `X'FF000000'` when none was; EIBCALEN 0 then.
* Make `SET ADDRESS OF x TO ptr` alias `x` onto that storage, so that writes through it are
  visible to the caller.
* Return, for `ADDRESS EIB`, a view of the running task's EIB, field for field.

## Avoided ambiguities

* **COBOL `NULL` against the CICS null value.** `X'FF000000'` is IBM's value for CICS pointers.
  What a COBOL `IF ptr = NULL` makes of it is not stated by the ADDRESS page, so the programs
  test the documented bytes through a REDEFINES and no scenario depends on `NULL`.
* **EIB fields after EIBTRMID.** The IBM list omits the bytes that follow EIBTRMID in the
  real block, so the view stops at EIBTRMID. EIBCALEN is observed through `DFHEIBLK` only.
* **Which task's EIB.** The EIB view is taken only in the terminal task. Whether a callee's
  `ADDRESS EIB` returns the same address as its caller's is not asserted. TASKDATALOC
  (data above / below 16 MB) is not used; the options are AMODE(31) default.
* **DFHCOMMAREA in the callee.** The programs name no `DFHCOMMAREA`; nothing depends on any
  storage the translator adds for it.
* **EIBTIME / EIBDATE values**: compared with each other only, never logged.

## Citations

* [ADDRESS] CICS TS, EXEC CICS ADDRESS (COMMAREA, EIB; null value X'FF000000'; no conditions):
  https://www.ibm.com/docs/en/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_address.html
  (opened; the CICS TS 5.6 page, same text:
  https://www.ibm.com/support/knowledgecenter/SSGMCP_5.6.0/reference-applications/commands-api/dfhp4_address.html).
  The page states no release; `6.1.0` is only in the URL, and no page naming CICS TS 6.x
  for ADDRESS was found (find exact cite).
* [COMMAREA] CICS TS 6.x, Communication areas (COMMAREAs), COMMAREA in LINK and XCTL commands:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=transaction-commarea-in-link-xctl-commands
* [EIB-FIELDS] CICS TS 5.3, EXEC interface block fields (order and types; EIBCALEN):
  https://www.ibm.com/docs/en/SSGMCP_5.3.0/com.ibm.cics.ts.applicationprogramming.doc/topics/dfhp4_eibfields.html
  (a 5.3 page: no 6.x page for this was opened).
* WRITEQ TS item numbering and RECEIVE of unformatted input follow the conventions of
  `ca-link-lengths` (cites there); not re-quoted here.
