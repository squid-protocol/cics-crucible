# hc-assign-prinsysid: ASSIGN PRINSYSID on a terminal task is INVREQ RESP2 5

## The trap

`HCPSA` (transaction `HCPS`, terminal T001) issues `EXEC CICS ASSIGN PRINSYSID(area) RESP RESP2` and logs both to TS
queue `HCLOG` (ASSIGN is not an event, SPEC 6.2). It LINKs to `HCPSB` with no COMMAREA, then ASSIGNs `SYSID` and logs RESP.
`HCPSB` repeats the PRINSYSID ASSIGN, logs, ASSIGNs `SYSID`, logs, and RETURNs. Items: `A1 R=16 R2=05` (HCPSA PRINSYSID),
`B1 R=16 R2=05` (HCPSB PRINSYSID), `B2 R=00` (HCPSB SYSID), `A2 R=00` (HCPSA SYSID). The PRINSYSID area is never read.

## Why a naive translation breaks

* Returning NORMAL with blanks or the terminal id in the area (a port that treats PRINSYSID like SYSID or FACILITY): the
  log shows `R=00` where IBM says INVREQ.
* Raising INVREQ but with a RESP2 other than 5 (RESP2 2 to 6 are other ASSIGN INVREQ rows), or none: `R2` is wrong.
* Abending the task on INVREQ although RESP is coded (the page's default action is the abend): the task never reaches A2.
* Letting the failed ASSIGN poison later commands (the next ASSIGN SYSID must still be NORMAL).
* Treating the LINKed program differently: it shares the task's principal facility, so the answer is the same.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal task on T001 (a 3270 in the CSD, not an MRO, LU6.1 or APPC session), the
clock 2026-03-02T10:00:00, a stated region (APPLID `CRUCAPP1`, SYSID `CRU1`; only RESP of SYSID is logged).

* **`principal`**
  * A1: "If the principal facility is not an MRO, LU6.1, or APPC session, or if the task has no principal facility,
    INVREQ occurs." [ASSIGN, PRINSYSID] INVREQ is RESP 16; the Conditions table gives it RESP2 5: "The task is not
    associated with a terminal; or the task has no principal facility; or the principal facility is not an MRO, LU6.1, or
    APPC session." [ASSIGN, INVREQ]. RESP is coded, so the task goes on: `A1 R=16 R2=05`.
  * `LINK PROGRAM('HCPSB')`: a LINK event, length 0, no commarea.
  * B1: the linked program's principal facility is the task's: `B1 R=16 R2=05`.
  * B2: `ASSIGN SYSID` is valid on a terminal task and NORMAL: `B2 R=00`. A2 likewise after the return: `A2 R=00`.
  * `RETURN` of HCPSB (level 2), `SEND TEXT ... ERASE`, `RETURN` of HCPSA.

## What a correct port must do

* Answer INVREQ with RESP2 5 to PRINSYSID for a task whose principal facility is a terminal, in every program of the task,
  without abending when RESP is coded, and leave other ASSIGNs unaffected.

## Avoided ambiguities

* **The PRINSYSID area after INVREQ:** the page says only that other options "are still populated"; it does not say what the
  failing option's own area holds, so the program never reads it.
* **Mixed options:** PRINSYSID together with other options is not used (see `hc-assign-identity`).
* **RESP2 on NORMAL:** not documented; only the INVREQ rows log RESP2.
* **A task with no terminal** (START without TERMID, RUN TRANSID): the same RESP2 5 row covers it but is not exercised.
* **The success path** (an MRO, LU6.1 or APPC principal facility): the crucible has no such session.

## Citations

* [ASSIGN] IBM CICS TS 6.x, EXEC CICS ASSIGN (PRINSYSID; Conditions, INVREQ RESP2 5; default action abend):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign (read 2026-11-11)
* [RESP-CODES] IBM CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
