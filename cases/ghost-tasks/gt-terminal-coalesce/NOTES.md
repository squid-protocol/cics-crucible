# gt-terminal-coalesce: STARTs aimed at a terminal

## The trap

`GTTERM` (transaction `GT11`) starts transaction `GT12` (program `GTSHOW`) **on its own
terminal** (`TERMID(EIBTRMID)`). GTSHOW RETRIEVEs until the response is not NORMAL and shows
what it got. The mode letter typed after the transaction id picks what GTTERM does:

| Mode | GTTERM does |
|---|---|
| 3 | three STARTs (ALPHA, BRAVO, CHARLIE), all INTERVAL(0) |
| S | ALPHA with INTERVAL(0), BRAVO with INTERVAL(10) |
| C | ALPHA with INTERVAL(30) and REQID('GTREQ001') |
| K | CANCEL REQID('GTREQ001') |

## Why a naive translation breaks

* **"One START = one async job" is wrong for terminal starts.** CICS starts *one* GT12 task
  for all three requests, because they share a transaction and terminal and expired before
  the terminal was free. That task RETRIEVEs the three data records one after another. A
  port that submits three jobs produces three screens (`SHOW:ALPHA`, `SHOW:BRAVO`,
  `SHOW:CHARLIE`) instead of one (`SHOW:ALPHA,BRAVO,CHARLIE`).
* **RETRIEVE only sees expired requests.** In `staggered`, BRAVO's request (INTERVAL(10))
  is not yet expired when the first GT12 runs. RETRIEVE therefore ends with ENDDATA after
  ALPHA, and BRAVO arrives in a second task 10 seconds later. A port that hands the task
  "all queued data" merges them.
* **Terminal tasks wait for the terminal.** GT12 cannot start while GT11 holds T001. A port
  that runs it concurrently interleaves the screens.
* **CANCEL is conditional.** It succeeds only for an **unexpired** request. After the
  request has expired (and run), CANCEL gets NOTFND. A port that cancels a scheduled future
  by id and ignores the result hides the difference.

## Expected behaviour

Model (SPEC section 4): a request with TERMID is dispatched once it has expired and the
terminal is free. All expired requests for the same TRANSID and TERMID are satisfied by one
task.

* **`three-in-one`**: at 10:00:00 GT11 issues three START TRANSID('GT12') TERMID('T001')
  INTERVAL(0) FROM(10 bytes) [START]. It sends `QUEUED 3` and RETURNs. "Only one task is
  started if several START commands, each specifying the same transaction and terminal,
  expire at the same time or before the terminal is available" [START]. That one GT12 task
  can "access all data records associated with all expired START commands having the same
  transaction identifier and terminal identifier as this task", presented "in
  expiration-time sequence" [RETRIEVE]: ALPHA, BRAVO, CHARLIE (issued, and so expiring, in
  that order), then ENDDATA ("no more data" [RETRIEVE]). GT12 sends
  `SHOW:ALPHA,BRAVO,CHARLIE`.
* **`staggered`**: ALPHA expires at 10:00:00 and BRAVO at 10:00:10. When GT11 ends, T001 is
  free and ALPHA's request has expired, so GT12 runs at 10:00:00. Its RETRIEVE gets ALPHA
  and then ENDDATA: BRAVO's request is not expired, and RETRIEVE without WAIT does not wait
  for it [RETRIEVE]. It sends `SHOW:ALPHA`. At 10:00:10 BRAVO's request expires and a second
  GT12 task runs, sending `SHOW:BRAVO`.
* **`cancel-in-time`**: at 10:00:00 START INTERVAL(30) REQID('GTREQ001') → expires 10:00:30.
  At 10:00:10 the operator runs `GT11 K`: CANCEL REQID('GTREQ001') → NORMAL [CANCEL]. The
  report shows `CANCEL RESP=00`. The request is gone, so no GT12 ever runs (the scenario
  runs until 10:02:00).
* **`cancel-too-late`**: same START. Nothing happens until 10:00:30, when the request
  expires; T001 is free, so GT12 runs and sends `SHOW:ALPHA`. At 10:00:40 the operator runs
  `GT11 K`: CANCEL → NOTFND, which "occurs if the request identifier specified fails to
  match an unexpired interval control command" [CANCEL]. DFHRESP(NOTFND) = 13
  [RESP-CODES], so the report shows `CANCEL RESP=13`.

## What a correct port must do

* Queue START requests per (TRANSID, TERMID).
* When a terminal becomes free, start one task for all of that terminal's expired requests
  for a transaction. RETRIEVE then drains only the expired ones, in expiry order, and ends
  with ENDDATA.
* Serialise terminal tasks on their terminal.
* Implement CANCEL REQID against unexpired requests only (NOTFND otherwise).

## Avoided ambiguities

* **The terminal must accept ATI.** A terminal gets START-initiated tasks only if its
  TYPETERM says `ATI(YES)`; with the RDO default `ATI(NO)` every START here still returns
  NORMAL but GT12 never runs (and `cancel-too-late` would get NORMAL, not NOTFND). The case
  CSD therefore defines `TYPETERM ... ATI(YES) TTI(YES)` and `TERMINAL(T001)` (SPEC section 2;
  [ATI]).
* **Typed input after output.** An unformatted read returns the screen buffer from position 0
  [UNFORMATTED], so `GT11 K` is exactly what RECEIVE returns only because the operator clears
  the screen before typing it (SPEC section 5; the steps say so).

* **ATI vs a pending RETURN TRANSID.** RETURN's IMMEDIATE option exists because an ATI
  request queued for the terminal can otherwise run before the next input's transaction
  [RETURN]. What that does to the pending TRANSID and COMMAREA is not exercised: GT11
  always RETURNs *without* TRANSID.
* **Operator input and expiry in the same second** never happen (SPEC section 4). In
  `cancel-too-late`, expiry is at +30 s and the operator types at +40 s.
* The order of equal-looking expiry times in `three-in-one` comes from issue order. The
  three STARTs are issued one after the other in one task, so their real expiry times
  increase.

## Citations

* [START] CICS TS 6.x, EXEC CICS START (TERMID, INTERVAL, REQID; one task for several STARTs of the same transaction and terminal): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RETRIEVE] CICS TS 6.x, EXEC CICS RETRIEVE (all expired START data for the same transaction and terminal, expiry order, ENDDATA, WAIT): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-retrieve
* [CANCEL] CICS TS 6.x, EXEC CICS CANCEL (REQID, NOTFND): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-cancel
* [RETURN] CICS TS 6.x, EXEC CICS RETURN (IMMEDIATE vs ATI requests queued for the terminal): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [ATI] CICS TS 5.6, Automatic transaction initiation (ATI); TYPETERM attribute `ATI`: https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=control-automatic-transaction-initiation-ati
* [UNFORMATTED] CICS TS 6.x, Unformatted mode: https://www.ibm.com/docs/en/cics-ts/6.x?topic=terminals-unformatted-mode
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NOTFND = 13): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
