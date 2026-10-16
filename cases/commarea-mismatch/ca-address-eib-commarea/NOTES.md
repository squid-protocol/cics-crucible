# ca-address-eib-commarea: ADDRESS EIB read after a failed command, ADDRESS COMMAREA written through, no COMMAREA

Extends `ca-address-commarea` (which compares the first five EIB fields and shows the null COMMAREA pointer) with an EIB view
that is read **after** a command has set EIBRESP, and an EIB view and a COMMAREA view used together in one callee.

## The trap

`CAEBCA` (transaction `CA0K`) and its callee `CAEBSB` reach the EIB and the COMMAREA through **pointers** (`ADDRESS EIB`,
`ADDRESS COMMAREA`, `SET ADDRESS OF`); neither names `DFHCOMMAREA`. The mode letter typed after the transaction id picks the
scenario. ADDRESS is not an event (SPEC 6.2), so each result is a breadcrumb in TS queue `CALOG` and in the `SEND TEXT` report.

| Mode | What runs | What it shows |
|---|---|---|
| Q | `ADDRESS EIB`, `SET ADDRESS OF` a view of the whole EIB; then `READQ TD QUEUE('CANQ') RESP(...)`, `CANQ` not defined; then read `EIBRESP` through the view | the view is the live EIB: it holds the failed command's EIBRESP |
| W | `LINK PROGRAM('CAEBSB') COMMAREA(WS-AREA) LENGTH(20)`; the callee does `ADDRESS EIB` and `ADDRESS COMMAREA`, reads EIBCALEN through the EIB view, reads and writes through the COMMAREA view | the COMMAREA pointer is the caller's storage; the callee's write is the caller's |
| N | `ADDRESS EIB` and `ADDRESS COMMAREA` in the terminal task | no COMMAREA: the null value `X'FF000000'`, EIBCALEN 0 through the view, and no error |

## Why a naive translation breaks

* A port that fills an EIB object once at task start and hands out a **copy** for `ADDRESS EIB` shows `EIBRESP` 0 in Q, after
  the READQ TD has failed. The view and `DFHEIBLK` must be one block that every command updates.
* A port that sets EIBRESP only for commands without `RESP`, or leaves it 0 when `RESP` is given, logs `RESP=0000` in Q.
* A port that copies the COMMAREA into the callee (a typed DTO) loses the write: `AD-REPLY` stays blank in W.
* A port that gives the callee a Java `null` or zero for a missing COMMAREA, or throws, differs in N: CICS gives the pointer
  `X'FF000000'` and the program carries on.

## Expected behaviour

Every scenario: `CA0K x` typed on a cleared screen. EIBCALEN is 0 for the terminal task and `RECEIVE INTO(WS-INPUT)
LENGTH(WS-INLEN)` returns the 6 characters typed (the assumption shared by the other cases, listed in the README).

* **`eib-qiderr`** (Q): "This option returns a pointer reference set to the address of the EXEC interface block (EIB)"
  [ADDRESS]. READQ TD "Occurs if the symbolic destination to be used with READQ TD cannot be found" (QIDERR) [READQ-TD]; `CANQ`
  is not in the CSD, so the event is `READQ-TD` with `resp` QIDERR and `data` null (as `hc-readq-td`, scenario `undefined`).
  EIBRESP "Contains a number corresponding to the RESP condition that occurred" [EIB-FIELDS], and QIDERR is 44 [RESP-CODES].
  The view `VE-RESP` is therefore 44, equal to `DFHEIBLK`'s `EIBRESP` and to the `RESP` value (`SAME=Y`). Item 1 is
  `Q1 RESP=0044 SAME=Y`, the report `MODE=Q RESP=0044 SAME=Y`. No RESP2 is asserted: the READQ TD page gives none for QIDERR.
* **`commarea-writethru`** (W): "the address of the area is passed to the program that is receiving control" and "the linking
  program can both pass data to the program it is invoking and receive results from that program" [COMMAREA]. The callee's
  EIBCALEN, read through its EIB view, is 20 [EIB-FIELDS] and equals `DFHEIBLK`'s. Its pointer is the caller's `WS-AREA`
  (`CAEB` / `PING` / blanks): item 1 `C1  P=PRESENT CALEN=0020 SAME=Y EYE=CAEB REQ=PING    `. It moves `PONG` into
  `VW-REPLY`; the caller's `AD-REPLY` is now `PONG`, the report `MODE=W REPLY=PONG`.
* **`no-commarea`** (N): "If the COMMAREA does not exist, the pointer reference is set to the null value, X'FF000000'"
  [ADDRESS]; EIBCALEN "contains the length of the communication area that has been passed to the application program"
  [EIB-FIELDS], 0 for a task started from a terminal. Item 1 is `N1  P=ABSENT  CALEN=0000 SAME=Y EYE=     REQ=        `,
  the report `MODE=N P=ABSENT CALEN=0000`.

## What a correct port must do

* Give `ADDRESS EIB` a view of the **running task's EIB**, not a copy: a command that sets EIBRESP is seen through the view.
* Set EIBRESP for a command that has `RESP` too (QIDERR is 44).
* Give `ADDRESS COMMAREA` a view of the caller's bytes (writes visible to the caller), or `X'FF000000'` when there is none.
* Treat `ADDRESS COMMAREA` in a program with no COMMAREA, and a program that names no `DFHCOMMAREA`, as ordinary.

## Avoided ambiguities

* **"Refused".** The task brief expected `ADDRESS COMMAREA` in a program with no `DFHCOMMAREA` to be refused. The ADDRESS page
  [ADDRESS] states no condition and no refusal; it says the pointer is the null value when the COMMAREA does not exist. The
  case therefore asserts the null value only (`no-commarea`) and never an error, abend or RESP for the ADDRESS.
* **EIB layout.** [EIB-FIELDS] lists the fields in alphabetical order and gives no layout. The views declare the fields in the
  order and types of the translator-supplied `DFHEIBLK` (the stand-in in `tools/stubs/DFHEIBLK.cpy`), a reading with no opened
  IBM page: README lower-confidence table. Only `EIBRESP` and `EIBCALEN` are read through a view.
* **EIBRESP2** of the QIDERR is not read or logged.
* **EIBRESP before the READQ TD.** Whether a command without RESP or NOHANDLE sets EIBRESP is not relied on: the breadcrumb is
  written after the READQ TD only.
* **Which task's EIB.** The EIB view is taken in the task that uses it; whether two programs' `ADDRESS EIB` return one address is
  not asserted. COBOL `NULL` is not used (the programs test the documented bytes through a REDEFINES).

## Citations

* [ADDRESS] CICS TS, EXEC CICS ADDRESS (EIB, COMMAREA; null value X'FF000000'; no conditions listed), opened 2026-10-16:
  https://www.ibm.com/docs/en/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_address.html
  The page names no release; `6.1.0` is only in the URL (find exact cite for a page naming 6.x).
* [EIB-FIELDS] CICS TS 5.3, EXEC interface block fields (EIBRESP, EIBRESP2, EIBCALEN; "Fields are listed in alphabetic order"),
  opened 2026-10-16:
  https://www.ibm.com/docs/en/SSGMCP_5.3.0/com.ibm.cics.ts.applicationprogramming.doc/topics/dfhp4_eibfields.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (row "QIDERR 44 2C AEYH"), opened 2026-10-16:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [READQ-TD] EXEC CICS READQ TD (CICS TS 5.5; QIDERR, no RESP2 given), opened 2026-10-16:
  https://www.ibm.com/docs/SSGMCP_5.5.0/reference/commands-api/dfhp4_readqtd.html
* [COMMAREA] CICS TS 6.x, COMMAREA in LINK and XCTL commands:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=transaction-commarea-in-link-xctl-commands (as cited in `ca-address-commarea`)
* WRITEQ TS item numbering and RECEIVE of unformatted input follow `ca-link-lengths`.
