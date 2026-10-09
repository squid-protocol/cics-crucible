# hc-named-counters: DEFINE / DELETE / GET / QUERY COUNTER, a missing counter is INVREQ RESP2 201, and names outside IBM's rules

## The trap

`HCCNTR` (transaction `HC71`) is typed with a mode after `HC71` and logs what each named-counter command did to TS queue
`HCLOG` (the named-counter commands are not events, SPEC 6.2). Item format, 26 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3),
` V=`, the value (9 digits). RESP2 is logged only for a command that failed; the value only for a GET or QUERY that completed
(zeros otherwise).

* **L** (the life of a counter, pool `HCPOOL`): `GET COUNTER` and `DELETE COUNTER` of a counter that is not there; `DEFINE COUNTER
  VALUE(field = 5)`; a second `DEFINE COUNTER ... VALUE(7)`; `GET COUNTER` twice; `QUERY COUNTER`; `GET COUNTER` again;
  `DEFINE COUNTER` with no `VALUE` and a `GET` of it; `DELETE COUNTER` and a `GET` of the deleted counter; the same name defined
  with no `POOL` (value 9) and read, then read in `HCPOOL` again.
* **N** (names): `DEFINE COUNTER` with a name in lower case, one starting with a digit, one with an embedded space; `DEFINE` with
  a pool containing a hyphen; `GET COUNTER` with a pool containing a space; a counter and a pool that use every kind of allowed
  character (`A_1$#@`, `P_1$#@`), defined and read; `DELETE COUNTER` with the bad pool and then the right one.

## Why a naive translation breaks

* A port that answers a missing counter with NOTFND (RESP 13) logs `R=13`
  where IBM's GET COUNTER lists no NOTFND at all: the condition is INVREQ, RESP2 201.
* A port that cannot translate `DEFINE COUNTER` / `DELETE COUNTER` (GenApp's LGSETUP) cannot translate the program.
* A port that lets a second `DEFINE COUNTER` overwrite the first, or does not start a counter without `VALUE` at zero, or reads a
  counter of another pool, logs different values.
* A port that treats `QUERY COUNTER` like `GET COUNTER` advances the counter (L7 / L8).
* A port that accepts any name or pool (no INVREQ 403 / 404) stores counters IBM would refuse.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; the region starts with no named counters and each scenario starts at
10:00:00 on 2026-03-02 with `HC71 <mode>` typed on T001. The counters a scenario uses are the ones its program defines. INVREQ is
RESP 16 [RESP-CODES].

* **`lifecycle`** (L):
  * L1: `GET COUNTER` of a counter that has not been defined. IBM's GET COUNTER page lists no NOTFND; its INVREQ conditions
    include "RESP2 201: Named counter not found" [GET-COUNTER]. `R=16 S=201`. The value area is not written by a failed command
    (the program logs zero for it).
  * L2: `DELETE COUNTER` of a counter that is not there: INVREQ, RESP2 201 "Named counter not found" [DELETE-COUNTER] (the page
    lists no NOTFND either). `R=16 S=201`.
  * L3: `DEFINE COUNTER ... VALUE(5)`: "VALUE ... The initial value ..." [DEFINE-COUNTER]; the value 5 lies within the default limits
    (minimum "low-values", maximum "high values" [DEFINE-COUNTER]). NORMAL.
  * L4: a second `DEFINE COUNTER` of the same name and pool: INVREQ "RESP2 202: Duplicate counter name. A named counter of this
    name already exists" [DEFINE-COUNTER] (the page lists no DUPREC). The first counter is unchanged.
  * L5, L6: `GET COUNTER` "Receives the current number obtained from the server. This is the number assigned before the increment
    is applied" [GET-COUNTER], the increment defaulting to 1: the first GET returns 5, the second 6.
  * L7: `QUERY COUNTER` "Returns the current value" [QUERY-COUNTER] and does not change it: 7 (the counter after two GETs).
  * L8: a GET returns 7: QUERY did not advance it.
  * L9, L10: `DEFINE COUNTER` with neither `VALUE` nor `MINIMUM`: "the named counter is created with an initial value of zero"
    [DEFINE-COUNTER]. The first GET returns 0.
  * L11, L12: `DELETE COUNTER` removes `HCCNT1` (NORMAL); a GET of it is INVREQ 201 again.
  * L13, L14, L15: with no `POOL`, "a pool selector value of 8 blanks is assumed" [DEFINE-COUNTER]: `HCCNT1` is a different counter
    from the one in `HCPOOL`, so the DEFINE (VALUE 9) is not a duplicate and a GET returns 9, while a GET in `HCPOOL` is still
    INVREQ 201.
  * The program sends `DONE OK` and RETURNs.
* **`names`** (N): IBM: COUNTER "Use uppercase letters, digits, underscores, and $, #, @ ... The name cannot start with a number or
  underscore"; INVREQ "RESP2 404: COUNTER contains invalid characters or embedded spaces"; "RESP2 403: POOL contains invalid
  characters or embedded spaces" [DEFINE-COUNTER] [GET-COUNTER]; the pool's valid characters are A-Z, 0-9, `$`, `@`, `#` and `_`.
  * N1 `hccnt1` (lower case), N2 `1HCCNT` (starts with a digit), N3 `HC CNT` (embedded space): INVREQ 404.
  * N4 DEFINE with POOL `HC-POOL` (a hyphen), N5 GET with POOL `HC POOL` (embedded space): INVREQ 403.
  * N6, N7: a counter `A_1$#@` in pool `P_1$#@` uses only allowed characters (a letter first, then underscore, digit, `$`, `#`, `@`):
    DEFINE VALUE(1) is NORMAL and a GET returns 1.
  * N8: `DELETE COUNTER` with POOL `HC-POOL`: INVREQ 403 [DELETE-COUNTER lists 403, and no 404]. N9: with the right pool, NORMAL.

## What a correct port must do

* Answer a GET / DELETE / QUERY of a counter that is not there with INVREQ and RESP2 201, never NOTFND.
* Accept `DEFINE COUNTER` (VALUE or none) and `DELETE COUNTER`: a duplicate DEFINE is INVREQ 202; a counter is identified by its
  pool and name; no POOL is 8 blanks.
* Return INVREQ 403 / 404 for a pool / counter name outside IBM's character rules.

## Avoided ambiguities

* **RESP2 of a command that completed**: IBM states none, so no item carries it for a NORMAL command.
* **VALUE of a failed GET / QUERY**: not stated; the program logs zero for it.
* **MINIMUM, MAXIMUM, NOSUSPEND, DCOUNTER, INCREMENT, WRAP, REDUCE, COMPAREMIN / COMPAREMAX, REWIND / UPDATE COUNTER**: not used.
* **A VALUE below zero, or beyond the default maximum, and a counter name of blanks**: the pages' limits ("low-values", "high
  values") do not say how they read as signed values; INVREQ 406 is not provoked.
* **Pool-server errors** (RESP2 301-311), **BUSY** (coupling facility rebuild): the region has no counter server.
* **Counters across tasks and regions**: each scenario is one task; a counter lives in the region's named-counter pool.

## Citations

* [DEFINE-COUNTER] CICS TS 6.x, EXEC CICS DEFINE COUNTER and DEFINE DCOUNTER (VALUE, MINIMUM, MAXIMUM, POOL; INVREQ RESP2
  202 / 403 / 404 / 406): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-define-counter-define-dcounter
* [DELETE-COUNTER] CICS TS 6.x, EXEC CICS DELETE COUNTER and DELETE DCOUNTER (INVREQ RESP2 201 / 403):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delete-counter-delete-dcounter
* [GET-COUNTER] CICS TS 6.x, EXEC CICS GET COUNTER and GET DCOUNTER (VALUE, INCREMENT; INVREQ RESP2 201 / 403 / 404):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-counter-get-dcounter
* [QUERY-COUNTER] CICS TS 6.x, EXEC CICS QUERY COUNTER and QUERY DCOUNTER (VALUE; INVREQ RESP2 201):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-query-counter-query-dcounter
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
