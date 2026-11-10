# hc-counter-rewind-update: REWIND and UPDATE of named counters (COUNTER and DCOUNTER), SUPPRESSED RESP2 102, INVREQ RESP2 406

Follows [`hc-counter-increment-wrap`](../hc-counter-increment-wrap) (the limit, GET WRAP), [`hc-dcounters`](../hc-dcounters) and
[`hc-named-counters`](../hc-named-counters), which all list REWIND / UPDATE as "not used". This case uses them.

## The trap

`HCCRWU` (transaction `HC75`) is typed with a mode after `HC75` and logs each command to TS queue `HCLOG` (the named-counter
commands are not events, SPEC 6.2). Item format, 33 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` V=`, the value as 16
digits. RESP2 is logged only for a failed command; the value only for a GET or QUERY that completed (zeros otherwise). A DCOUNTER
value (`PIC X(8)`) is logged as 16 hex digits, a fullword COUNTER value as 16 decimal digits. Pool `HCPOOL`, counter `HCRWU1`.

* **R** (`rewind`): `DEFINE DCOUNTER VALUE(1) MINIMUM(1) MAXIMUM(3)`. REWIND of a counter that is not there, then of one below its
  limit, three GETs that take it to the maximum, REWIND, GET, REWIND again, REWIND with a bad pool and with a bad name.
* **U** (`update`): `DEFINE DCOUNTER VALUE(10) MINIMUM(10) MAXIMUM(20)`. UPDATE of a counter that is not there; UPDATE VALUE(15),
  QUERY, GET; UPDATE VALUE 9 (below the minimum) and 22 (above the maximum plus 1); VALUE 21 (maximum plus 1) and VALUE 10 (the
  minimum), then a GET; UPDATE with a bad pool and a bad name.
* **C** (`fullword`): the same commands on `COUNTER` (fullword, signed) with the default limits: REWIND and UPDATE of a missing
  counter, REWIND below the limit, `UPDATE COUNTER VALUE(5)` read back by QUERY and GET, bad pool, bad name.

## Why a naive translation breaks

* A port that makes REWIND an unconditional reset logs `R=00` where IBM returns SUPPRESSED, RESP2 102 (R3, R9, C4, C9).
* A port that lets REWIND fail when the counter is at its limit, or does not reset to the *minimum* (1, not 0), logs R7 / R8 wrong.
* A port that treats UPDATE as unchecked stores values IBM refuses (INVREQ 406: U6, U7), or refuses the boundary values IBM allows
  (the maximum plus 1, the minimum: U8, U9).
* A port that answers a missing counter with NOTFND logs `R=13` where IBM lists INVREQ, RESP2 201 (R1, U1, C1, C2).
* A port that has no REWIND / UPDATE at all (they are DFHNC commands, rare in samples) cannot translate the program.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; the region starts with no named counters; each scenario starts at 10:00:00 on
2026-03-02 with `HC75 <mode>` typed on T001. INVREQ is RESP 16 and SUPPRESSED RESP 72 [RESP-CODES]. A counter "reaches its limit" when
its maximum has been assigned, i.e. its current value is the maximum plus 1 [REWIND-COUNTER, GET-COUNTER].

* **`rewind`** (R, limits 1 / 3):
  * R1 REWIND DCOUNTER of a counter not there: INVREQ 201 "Named counter not found" [REWIND-COUNTER]. R2 DEFINE: NORMAL.
  * R3 REWIND with the current value 1: SUPPRESSED RESP2 102, the counter "has not reached its limit" [REWIND-COUNTER]. `R=72 S=102`.
  * R4, R5, R6 GET: 1, 2, 3 (the number assigned before the increment [GET-COUNTER]); the maximum has now been assigned.
  * R7 REWIND: NORMAL, "reset the current value of the named counter to its defined minimum number" [REWIND-COUNTER]. R8 GET returns
    1, the minimum. R9 REWIND with the current value 2: SUPPRESSED 102 again.
  * R10 REWIND with POOL `HC-POOL`: INVREQ 403; R11 with COUNTER `hcrwu1` (lower case): INVREQ 404 [REWIND-COUNTER].
* **`update`** (U, limits 10 / 20): "set a new current value for the named counter" [UPDATE-COUNTER].
  * U1 UPDATE of a missing counter: 201. U2 DEFINE: NORMAL. U3 UPDATE VALUE(15): NORMAL; U4 QUERY returns 15 and U5 GET returns 15.
  * U6 VALUE 9, U7 VALUE 22: INVREQ 406, "You cannot set the current value to less than the minimum value, or greater than the maximum
    value plus 1" [UPDATE-COUNTER] (below 10; above 21). `R=16 S=406`.
  * U8 VALUE 21 (maximum plus 1) and U9 VALUE 10 (the minimum): NORMAL, both inside the stated range. U10 GET returns 10.
  * U11 bad pool: 403. U12 bad counter name: 404.
* **`fullword`** (C): REWIND COUNTER / UPDATE COUNTER take a fullword signed value; the counter has the default limits.
  * C1 REWIND, C2 UPDATE of a missing counter: 201. C3 `DEFINE COUNTER VALUE(1)`: NORMAL.
  * C4 REWIND (current 1): SUPPRESSED 102. C5 UPDATE VALUE(5): NORMAL; C6 QUERY returns 5; C7 GET returns 5; C8 QUERY returns 6.
  * C9 REWIND (current 6, far below the default maximum): SUPPRESSED 102. C10 UPDATE with a bad pool: 403; C11 REWIND with a bad
    name: 404.
  * The program sends `DONE OK` and RETURNs in every scenario.

## What a correct port must do

* REWIND resets to the minimum only a counter that has reached its limit; any other counter gets SUPPRESSED, RESP2 102 and no change.
* UPDATE sets the current value for any VALUE from the minimum to the maximum plus 1, and refuses a VALUE outside it with INVREQ 406.
* Answer a missing counter with INVREQ 201 and a bad pool / name with INVREQ 403 / 404, for both commands and both forms.

## Avoided ambiguities

* **INCREMENT on REWIND**: the page ties it to a failed GET of the same increment; not used (the default of 1 applies).
* **COMPAREMIN / COMPAREMAX on UPDATE**: the page's range test names "the current value" (SUPPRESSED RESP2 103) while the option text
  speaks of the new value; not used.
* **The counter after a failed REWIND / UPDATE**: IBM states no side effect, so no scenario reads a counter back after a failure
  except through the next successful command (R8 follows a good REWIND, U10 a good UPDATE).
* **Value of QUERY at the limit, and a GET at maximum plus 1 set by UPDATE**: not issued; U8 is followed by another UPDATE.
* **Default minimum / maximum of a fullword COUNTER as a signed value**: mode C never gets near them.
* **NOSUSPEND / BUSY, pool-server errors (RESP2 301-311), other tasks and regions**: none; each scenario is one task.
* **RESP2 of a completed command / VALUE of a failed GET or QUERY**: not stated; not logged / zeros, as in hc-named-counters.

## Citations

* [REWIND-COUNTER] CICS TS 6.x, EXEC CICS REWIND COUNTER and REWIND DCOUNTER: "These counter commands reset the current value of
  the named counter to its defined minimum number"; INVREQ RESP2 201 / 403 / 404 / 406; SUPPRESSED RESP2 102, the counter has not
  reached its limit even after applying any INCREMENT:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-rewind-counter-rewind-dcounter
* [UPDATE-COUNTER] CICS TS 6.x, EXEC CICS UPDATE COUNTER and UPDATE DCOUNTER: "These counter commands set a new current value for the
  named counter"; VALUE "Specifies the new number to set as the current value"; INVREQ RESP2 406 "You cannot set the current value to
  less than the minimum value, or greater than the maximum value plus 1"; RESP2 201 / 403 / 404 as REWIND; SUPPRESSED RESP2 103 is
  COMPAREMIN / COMPAREMAX only: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-update-counter-update-dcounter
* [GET-COUNTER] CICS TS 6.x, EXEC CICS GET COUNTER and GET DCOUNTER (the number assigned before the increment; counter-at-limit):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-counter-get-dcounter
* [DEFINE-COUNTER] CICS TS 6.x, EXEC CICS DEFINE COUNTER and DEFINE DCOUNTER (VALUE, MINIMUM, MAXIMUM, POOL):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-define-counter-define-dcounter
* [QUERY-COUNTER] CICS TS 6.x, EXEC CICS QUERY COUNTER and QUERY DCOUNTER (VALUE):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-query-counter-query-dcounter
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, SUPPRESSED 72):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* The expected logs were derived by hand from these pages and the program text, not from any tool's output.
