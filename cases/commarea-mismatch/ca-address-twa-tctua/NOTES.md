# ca-address-twa-tctua: ADDRESS TWA and ADDRESS TCTUA

## The trap

`CATWAD` reaches two CICS-owned work areas through **pointers** (`ADDRESS TWA`, `ADDRESS TCTUA`)
and `SET ADDRESS OF`. The mode letter after the transaction id picks the scenario; ADDRESS is
not an event (SPEC 6.2), so each result is a breadcrumb in TS queue `CALOG` and in the
`SEND TEXT` report.

| Transaction / mode | What runs | What it shows |
|---|---|---|
| `CA0H W` (`TWASIZE(32)`) | `ADDRESS TWA`, stamp `TWAMARK1`, LINK to `CATWSB` with no COMMAREA; the callee does `ADDRESS TWA` too | both programs of the task see one TWA |
| `CA0I Z` (`TWASIZE(0)`) | `ADDRESS TWA` | the null value `X'FF000000'` |
| `CA0J S`, then `CA0J R` (TYPETERM `USERAREALEN(16)`) | task 1 stamps `TCTUASTP` through `ADDRESS TCTUA`; task 2, a new task on the same terminal, reads it | the TCTUA belongs to the terminal, not the task |

## Why a naive translation breaks

* A port that models the TWA as a per-program field has no storage the callee can share. The
  TWA is the way programs of one task pass data **without a COMMAREA**.
* A port that always allocates a TWA (or hands out a Java `null`/zero) breaks the
  `TWASIZE(0)` branch: the documented value is `X'FF000000'`, and a program that tests it takes
  the "absent" branch only if the port produces exactly that.
* A port that keeps terminal-user data in task state loses it when the task ends. The TCTUA is
  sized by the terminal's TYPETERM and is reached from a later task on the same terminal.

## Expected behaviour

Every scenario step types `<transid> <mode>` on a cleared screen; EIBCALEN is 0 and `RECEIVE
INTO(WS-INPUT) LENGTH(WS-INLEN)` returns the 6 characters typed (the assumption shared by the
other cases, listed in the README). Breadcrumbs are 37 bytes: tag, ` P=` + 7, ` V1=` + 8, ` V2=` + 8.

* **`twa-sized`** (`CA0H`, `TWASIZE(32)`): the TWA is "the size in bytes of the transaction work
  area to be acquired for this transaction" [TWASIZE], so the task has one. "This option returns
  a pointer reference, set to the address of the transaction work area (TWA). This area is used
  for passing information between application programs, but only if they are in the same task"
  [ADDRESS]. `CATWAD` stamps `TWAMARK1` through its view and LINKs to `CATWSB` (length 0, no
  COMMAREA). The callee's `ADDRESS TWA` is the same area: item 1 `W2  P=PRESENT V1=TWAMARK1
  V2=        `, then it writes `TWAECHO`. Back in the caller, item 2 is `W1  P=PRESENT
  V1=TWAMARK1 V2=TWAECHO ` and the report `MODE=W STAMP=TWAMARK1 REPLY=TWAECHO`.
* **`twasize-zero`** (`CA0I`, `TWASIZE(0)`): "If a TWA does not exist, the pointer reference is
  set to the null value, X'FF000000'" [ADDRESS]. With `TWASIZE(0)` none is acquired (a reading,
  see below), so item 1 is `Z1  P=ABSENT  V1=         V2=        ` and the report `MODE=Z P=ABSENT`.
  The program does not `SET ADDRESS OF`.
* **`tctua-two-tasks`** (`CA0J`, TYPETERM `USERAREALEN(16)`): "For SNA LUs, you specify that you
  want a TCTUA by means of the USERAREALEN attribute on the TYPETERM resource definition"
  [TCTUA-AREAS]; `T001` is a 3270 logical unit (SPEC 2). `ADDRESS TCTUA` returns the address of
  the TCTUA "for the principal facility" [ADDRESS]. Task 1 (`S`) writes `TCTUASTP`: item 1
  `S1  P=PRESENT V1=TCTUASTP V2=        `, report `MODE=S P=PRESENT WROTE=TCTUASTP`. Task 2
  (`R`, a new task at +1 s, EIBCALEN 0) reads it back: item 2 `R1  P=PRESENT V1=TCTUASTP
  V2=        `, report `MODE=R P=PRESENT SEEN=TCTUASTP`. The queue is not deleted between the
  tasks, so task 2's item is 2.

## What a correct port must do

* Give every task of a transaction with `TWASIZE` > 0 one TWA of that size, the same storage for
  every program of the task (view, not copy); give a `TWASIZE(0)` transaction the pointer
  `X'FF000000'`.
* Give every terminal of a TYPETERM with `USERAREALEN` > 0 one TCTUA of that size, kept across
  tasks, reached by `ADDRESS TCTUA` as a view.

## Avoided ambiguities

* **Initial content.** No opened IBM page states what the TWA or the TCTUA holds before the first
  write, so every scenario writes first and reads only what it wrote.
* **CWA.** `ADDRESS CWA` needs a SIT `WRKAREA` fact the SPEC does not state: left out.
* **Alternate facilities and a TCTUA of a non-SNA terminal** are not exercised.
* **COBOL `NULL`** against `X'FF000000'`: the programs test the documented bytes through a
  REDEFINES, as in `ca-address-commarea`.
* **A `TWASIZE` above the area used**: the view is 16 bytes of a 32-byte TWA; nothing reads the rest.

## Citations

* [ADDRESS] CICS TS, EXEC CICS ADDRESS (TWA, TCTUA; null value X'FF000000'), opened:
  https://www.ibm.com/docs/en/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_address.html
  The page states no release; `6.1.0` is only in the URL (find exact cite for a page naming 6.x).
* [TWASIZE] CICS TS 5.3, TRANSACTION attributes (TWASIZE: size in bytes, range 0 - 32767; "Your
  storage might be corrupted if your TWASIZE is too small"), opened:
  https://www.ibm.com/docs/en/cics-ts/5.3.0?topic=resources-transaction-attributes
  The page does not say what 0 means: **find exact cite** for "TWASIZE(0) acquires no TWA".
* [TCTUA-AREAS] CICS TS 5.6, The terminal control table user areas (USERAREALEN on the TYPETERM
  gives the TCTUA size of all terminals that reference it), opened:
  https://www.ibm.com/docs/SSGMCP_5.6.0/tuning/dfht3_terminal_ctrltable_userareas.html
  The page names no release and states nothing about the TCTUA being kept between tasks:
  **find exact cite** for `tctua-two-tasks` task 2.
* An IBM 6.x page for the TYPETERM USERAREALEN and TRANSACTION TWASIZE attributes was not opened.
* WRITEQ TS item numbering and RECEIVE of unformatted input follow `ca-link-lengths`.
* cics-crucible commarea-mismatch / ca-address-twa-tctua
