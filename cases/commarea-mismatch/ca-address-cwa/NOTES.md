# ca-address-cwa: ADDRESS CWA

## The trap

`CACWAD` reaches the **common work area** through a pointer (`ADDRESS CWA`) and `SET ADDRESS OF`.
The mode letter after the transaction id picks the scenario; ADDRESS is not an event (SPEC 6.2), so
each result is a breadcrumb in TS queue `CALOG` and in the `SEND TEXT` report. The case states
`"wrkarea": 32` (the SIT `WRKAREA`, SPEC section 2).

| Transaction / mode | What runs | What it shows |
|---|---|---|
| `CA0K W` | `ADDRESS CWA`, stamp `CWAMARK1`, LINK to `CACWSB` with no COMMAREA; the callee does `ADDRESS CWA` too | both programs reach one CWA |
| `CA0K S`, then `CA0L R` | task 1 stamps `CWASTAMP`; task 2, a new task of **another transaction**, reads it | the CWA belongs to the region, not to a task or a transaction |

## Why a naive translation breaks

* A port that models the CWA as a per-task or per-program field loses the stamp at task end (or
  at the LINK): the CWA is how unrelated tasks share data in one region.
* A port that makes it per transaction (as a TWA is per task) fails `CA0L R`.

## Expected behaviour

Every step types `<transid> <mode>` on a cleared screen; EIBCALEN is 0 and `RECEIVE` returns the 6
characters typed (the assumption shared by the other cases). Breadcrumbs are 37 bytes.

* **`cwa-shared`**: "This option returns a pointer reference, set to the address of the common work
  area (CWA). This area makes information available to applications that are running in a single
  CICS system" [ADDRESS]. The caller stamps `CWAMARK1`, LINKs (length 0, no COMMAREA); the callee's
  `ADDRESS CWA` is the same area: item 1 `W2  P=PRESENT V1=CWAMARK1 V2=        `, then it writes
  `CWAECHO`; back in the caller, item 2 `W1  P=PRESENT V1=CWAMARK1 V2=CWAECHO ` and the report
  `MODE=W STAMP=CWAMARK1 REPLY=CWAECHO`.
* **`cwa-two-tasks`**: task 1 (`CA0K S`) writes `CWASTAMP`: item 1 `S1  P=PRESENT V1=CWASTAMP
  V2=        `. Task 2 (`CA0L R`, a new task at +1 s, another transaction) reads it back: item 2
  `R1  P=PRESENT V1=CWASTAMP V2=        `, report `MODE=R P=PRESENT SEEN=CWASTAMP`. The queue is
  not deleted between the tasks, so task 2's item is 2.

## What a correct port must do

* Allocate one CWA of `wrkarea` bytes for the region and hand every program, task, LINK level and
  transaction a view of the same storage.

## Avoided ambiguities

* **Initial content.** No opened IBM page states what the CWA holds before the first write, so every
  scenario writes first and reads only what it wrote.
* **No CWA.** The ADDRESS page gives X'FF000000' "if a CWA does not exist", but nothing opened says
  that `WRKAREA(0)` or an unstated WRKAREA means none (the SIT default was not read), so no scenario
  addresses a CWA without a stated `wrkarea`; `validate.py` requires one.
* **The `WRKAREA` range.** The SIT page was not read; `validate.py` accepts any positive integer.
  The view is 16 bytes of 32; nothing reads the rest.
* **Scenario independence.** A scenario starts from the case's stated initial state (SPEC 5, `initial`), which has no CWA content,
  so no scenario relies on a CWA left by another.
* **Other regions / ISC and initial program-load use of the CWA** are not exercised.

## Citations

* [ADDRESS] CICS TS, EXEC CICS ADDRESS (CWA: pointer reference "set to the address of the common
  work area (CWA)"; "makes information available to applications that are running in a single CICS
  system"; null value X'FF000000' when none exists), opened:
  https://www.ibm.com/docs/en/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_address.html
  The page states no release; `6.1.0` is only in the URL.
* [WRKAREA] the SIT `WRKAREA` parameter as the size: **find exact cite** (not opened).
* Persistence of the CWA across tasks follows from "available to applications ... in a single CICS
  system"; no sentence states it for a task that ended: **find exact cite** (README lower-confidence table).
* WRITEQ TS item numbering and RECEIVE of unformatted input follow `ca-link-lengths`.
