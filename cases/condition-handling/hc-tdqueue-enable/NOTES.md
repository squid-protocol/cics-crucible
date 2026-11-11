# hc-tdqueue-enable: INQUIRE TDQUEUE and SET TDQUEUE ENABLESTATUS on an intrapartition queue

## The trap

`HCTDEN` (transaction `HCTD`) is typed with a mode after `HCTD`. INQUIRE and SET are not events (SPEC 6.2), so each result is
a breadcrumb in TS queue `HCLOG`:

* **I** issues `EXEC CICS INQUIRE TDQUEUE('HCQ1') TYPE(..) ENABLESTATUS(..) RECOVSTATUS(..) RESP(..)` on the
  queue the CSD defines, then `INQUIRE TDQUEUE('HCNQ') ENABLESTATUS(..)` on one it does not. Item formats: tag (3), ` R=`, RESP
  (2), ` T=`, ` E=`, ` V=` and nine digits each (44 bytes); a failed command logs tag (3), ` R=`, RESP (2), ` R2=`,
  RESP2 (2) (14 bytes).
* **S** issues `SET TDQUEUE('HCQ1') ENABLESTATUS(DFHVALUE(DISABLED))`, an INQUIRE of the status, `SET ... ENABLESTATUS(
  DFHVALUE(ENABLED))`, and an INQUIRE again. A SET logs tag (3), ` R=`, RESP (2) (8 bytes); an INQUIRE logs tag (3), ` R=`,
  RESP (2), ` E=` and nine digits (20 bytes).
* **U** issues `SET TDQUEUE('HCNQ') ENABLESTATUS(DFHVALUE(ENABLED))` on the undefined queue.
* **V** issues `SET TDQUEUE('HCQ1') ENABLESTATUS(DFHVALUE(OPEN))`, a value ENABLESTATUS does not take, then INQUIRE.

## Why a naive translation breaks

* A port that cannot translate `INQUIRE TDQUEUE` / `SET TDQUEUE` at all fails to build the program.
* A port that returns the CVDAs as text, or a different number, or fills an area the command did not name, stores the wrong
  fullword.
* A port that keeps no run-time enable status, so a `SET ... DISABLED` is not read back by the following INQUIRE.
* A port that accepts any CVDA for ENABLESTATUS (a SET of `OPEN` changing the queue, or answering NORMAL).
* A port that answers NORMAL for a queue the CSD does not define.

## Expected behaviour

Model (SPEC section 2): `HCQ1` is `TYPE(INTRA) RECOVSTATUS(NO)`, with no `TRANSID`, so no automatic task initiation. `HCNQ` is not defined. Every scenario starts at 10:00:00 on 2026-03-02 with `HCTD <mode>` typed on T001. The
queue is not touched by a task before a SET DISABLED, so IBM's "in use" restriction (a queue cannot be disabled while a task
uses it) is not exercised.

* **`inquire`** (I):
  * I1: the queue is intrapartition: TYPE returns the CVDA `INTRA`, 222. A queue that is defined and not disabled is `ENABLED`,
    23. `RECOVSTATUS(NO)` returns `NOTRECOVABLE`, 30. NORMAL. Item: `I1  R=00 T=000000222 E=000000023 V=000000030`.
  * I2: `INQUIRE TDQUEUE('HCNQ')`: QIDERR, RESP2 1, "the queue cannot be found" [INQUIRE-TDQUEUE]. RESP QIDERR is 44
    [RESP-CODES]. Item: `I2  R=44 R2=01`.
* **`toggle`** (S):
  * S1: `SET TDQUEUE ENABLESTATUS(DISABLED)`: ENABLESTATUS "takes ENABLED or DISABLED" [SET-TDQUEUE]. NORMAL. Item: `S1  R=00`.
  * S2: INQUIRE reads the status the SET established, DISABLED, 24 [CVDA]. Item: `S2  R=00 E=000000024`.
  * S3: `SET ... ENABLESTATUS(ENABLED)`: NORMAL. Item: `S3  R=00`.
  * S4: INQUIRE reads ENABLED, 23. Item: `S4  R=00 E=000000023`.
* **`undefined`** (U): `SET TDQUEUE('HCNQ')`: QIDERR, RESP2 1 [SET-TDQUEUE]. Item: `U1  R=44 R2=01`.
* **`badcvda`** (V):
  * V1: `ENABLESTATUS(DFHVALUE(OPEN))`: OPEN is a valid CVDA (18) but not one ENABLESTATUS accepts. INVREQ, RESP2 10, "an invalid
    CVDA value" [SET-TDQUEUE]. INVREQ is 16 [RESP-CODES]. Item: `V1  R=16 R2=10`.
  * V2: a command that failed changed nothing: the queue is still ENABLED, 23. Item: `V2  R=00 E=000000023`.

## What a correct port must do

* Translate `INQUIRE TDQUEUE` with TYPE, ENABLESTATUS and RECOVSTATUS, and `SET TDQUEUE ENABLESTATUS`.
* Keep a run-time enable status per queue that a SET changes and an INQUIRE reads.
* Answer QIDERR (RESP2 1) for an undefined queue, and INVREQ (RESP2 10) for a CVDA ENABLESTATUS does not take, leaving the
  state as it was.

## Avoided ambiguities

* **The response of WRITEQ / READQ / DELETEQ TD on a disabled queue** (its RESP2 and, here, the page's wording): the case
  never writes to the queue, so it claims nothing about it.
* **Whether a SET of a queue a task has used is refused**: IBM says a queue cannot be disabled while it is in use. No task
  touches HCQ1 before a SET.
* **Output areas of a failed INQUIRE**: IBM does not say what they hold; the program logs only RESP and RESP2 for a failure.
* **RESP2 of a command that succeeded**: not logged.
* **TRIGGERLEVEL of a queue the CSD states none for**: the case does not INQUIRE it (IBM's default for a definition with no
  TRANSID is not asserted here). NUMITEMS, OPENSTATUS of an intrapartition queue and TRANSID are not used either.

## Citations

* [INQUIRE-TDQUEUE] CICS TS 6.x, CICS SPI command INQUIRE TDQUEUE (TYPE, ENABLESTATUS, RECOVSTATUS; QIDERR RESP2 1):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-tdqueue
* [SET-TDQUEUE] CICS TS 6.x, CICS SPI command SET TDQUEUE (ENABLESTATUS ENABLED / DISABLED; INVREQ RESP2 10, QIDERR RESP2 1):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-set-tdqueue
* [CVDA] CICS TS 6.x, API Reference, CVDAs and numeric values (ENABLED 23, DISABLED 24, INTRA 222, NOTRECOVABLE 30, OPEN 18):
  https://www.ibm.com/docs/en/SSJL4D_6.x/pdf/api-reference_pdf.pdf
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, QIDERR 44):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
