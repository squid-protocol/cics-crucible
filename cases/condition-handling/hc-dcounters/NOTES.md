# hc-dcounters: DEFINE / GET / QUERY / DELETE DCOUNTER, an 8-byte unsigned VALUE logged as hex, values past 2**31 and 2**32, a deleted counter is INVREQ RESP2 201

This is the DCOUNTER (doubleword) lane of the named-counter commands; the COUNTER (fullword) lane is
[`hc-named-counters`](../hc-named-counters), which this case does not repeat (names, pools, duplicate DEFINE).

## The trap

`HCDCNT` (transaction `HC72`) is typed with a mode after `HC72` and logs what each DCOUNTER command did to TS queue `HCLOG` (the
named-counter commands are not events, SPEC 6.2). Item format, 33 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` V=`, the
value as 16 hexadecimal digits (the 8 bytes of the doubleword, high byte first). RESP2 is logged only for a failed command; the value
only for a GET or QUERY that completed (zeros otherwise). The pool is `HCPOOL`, counters `HCDCN1` / `HCDCN2` / `HCDCN3`.

* **L** (life): GET and DELETE of a DCOUNTER that is not there; `DEFINE DCOUNTER VALUE(5)`; GET, GET, QUERY, GET, QUERY; DELETE;
  GET and QUERY of the deleted counter.
* **B** (big values): a counter defined at 2**31 - 1, one at 2**32 - 1, and one at 5 stepped by `INCREMENT` 2**32.

## Why a naive translation breaks

* A port that keeps the value in a 32-bit signed int (the COUNTER lane's fullword) wraps or goes negative past 2**31 - 1 and
  truncates at 2**32: B3, B7, B8, B11, B12 differ.
* A port that treats DCOUNTER as COUNTER raises LENGERR for a value that does not fit a fullword; IBM says LENGERR does not apply
  to DCOUNTER.
* A port that answers a deleted counter with NOTFND (RESP 13) logs `R=13`; IBM lists INVREQ 201.
* A port that lets QUERY advance the counter, or GET return the value after the increment, shifts every later value.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; the region starts with no named counters and each scenario starts at
10:00:00 on 2026-03-02 with `HC72 <mode>` typed on T001. INVREQ is RESP 16 [RESP-CODES].

* **`life`** (L):
  * L1: GET DCOUNTER of a counter not defined: INVREQ, RESP2 201 "Named counter not found." [GET-COUNTER] (no NOTFND is listed).
    `R=16 S=201`; the value area is not written by a failed command (the program logs zeros).
  * L2: DELETE DCOUNTER of a counter not there: INVREQ 201 "Named counter not found." [DELETE-COUNTER]. `R=16 S=201`.
  * L3: `DEFINE DCOUNTER ... VALUE(5)`: "Specifies the initial number at which the new named counter is to start, using ... a
    doubleword unsigned value for DCOUNTER." [DEFINE-COUNTER] NORMAL.
  * L4, L5: GET: "The counter is incremented after the current number has been assigned" and "The default increment is 1."
    [GET-COUNTER]: the first GET returns 5, the second 6.
  * L6: QUERY returns the current value ("Specifies the data area in which CICS is to return the current value for the named
    counter." [QUERY-COUNTER]): 7 (see the README lower-confidence table: that QUERY leaves it unchanged is a reading).
  * L7: a GET returns 7, L8: QUERY returns 8 (the GET of L7 advanced it by 1).
  * L9: "Delete the named counter from the specified pool." [DELETE-COUNTER]. NORMAL.
  * L10, L11: GET and QUERY of the deleted counter: INVREQ 201 "Named counter not found." [GET-COUNTER] [QUERY-COUNTER]. The
    step this case was written from expected INVREQ 201 for GET after DELETE; IBM's page agrees (RESP2 201, no NOTFND).
* **`big`** (B): the DCOUNTER value is a "doubleword unsigned data-area" [GET-COUNTER]; INCREMENT is a "doubleword unsigned binary
  value for DCOUNTER" [GET-COUNTER]; the default maximum is "a doubleword filled with X'FF'" [DEFINE-COUNTER], far above every
  value used. "LENGERR occurs for COUNTER commands only and does not apply to DCOUNTER requests." [GET-COUNTER]
  * B1-B4: defined at 2147483647 (X'7FFFFFFF'): GET returns `7FFFFFFF`, then `80000000` (2**31, which a signed fullword cannot hold),
    QUERY `80000001`.
  * B5-B8: defined at 4294967295 (X'FFFFFFFF'): GET returns `FFFFFFFF`, then `100000000` (2**32), QUERY `100000001`.
  * B9-B12: defined at 5; GET with INCREMENT 4294967296 returns 5, the next GET returns `100000005` (5 + 2**32), QUERY
    `200000005` (5 + 2 * 2**32). The increment is within the counter's range, so INVREQ 406 does not arise
    ("The INCREMENT value ... cannot be greater than the total range of the counter" [GET-COUNTER]).
  * The program sends `DONE OK` and RETURNs.

## What a correct port must do

* Hold a DCOUNTER value as an unsigned 64-bit quantity: exact at and past 2**31 and 2**32.
* GET returns the value before the increment (default 1, or INCREMENT) and advances the counter; QUERY returns it and does not.
* Answer GET / QUERY / DELETE of a counter that is not there (including a deleted one) with INVREQ RESP2 201, never NOTFND.

## Avoided ambiguities

* **RESP2 of a command that completed** and **VALUE of a failed GET / QUERY**: IBM states neither; no item carries a RESP2 for a
  NORMAL command, and the program logs zeros for the value of a failed one.
* **Values at or near the maximum**, the counter-at-limit condition (SUPPRESSED 101; QUERY returns maximum + 1), WRAP, REDUCE,
  COMPAREMIN / COMPAREMAX, MINIMUM / MAXIMUM, NOSUSPEND, REWIND / UPDATE: not used. Every value stays below 10**18, so the 8-byte
  field is an ordinary `PIC 9(18) COMP` whatever the compiler's binary-truncation option.
* **Names, pools, duplicate DEFINE (202), INVREQ 403 / 404 / 406**: covered by hc-named-counters, not repeated.
* **Pool-server errors** (RESP2 301-311), **BUSY** (rebuild): the region has no counter server.
* **Counters across tasks and regions**: each scenario is one task.

## Citations

* [DEFINE-COUNTER] CICS TS 6.x, EXEC CICS DEFINE COUNTER and DEFINE DCOUNTER (VALUE, default maximum):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-define-counter-define-dcounter
* [DELETE-COUNTER] CICS TS 6.x, EXEC CICS DELETE COUNTER and DELETE DCOUNTER (INVREQ RESP2 201):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delete-counter-delete-dcounter
* [GET-COUNTER] CICS TS 6.x, EXEC CICS GET COUNTER and GET DCOUNTER (VALUE, INCREMENT, INVREQ 201 / 406, LENGERR):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-counter-get-dcounter
* [QUERY-COUNTER] CICS TS 6.x, EXEC CICS QUERY COUNTER and QUERY DCOUNTER (VALUE; INVREQ RESP2 201):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-query-counter-query-dcounter
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
