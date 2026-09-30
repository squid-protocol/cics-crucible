# gt-start-retrieve: background tasks started with START

## The trap

`GTSTART` (transaction `GT01`) starts background tasks of transaction `GT02` (program
`GTWORK`, no terminal) with `EXEC CICS START`. GTWORK RETRIEVEs the data it was started with
until the response is neither NORMAL nor LENGERR, and logs every response to TS queue
`GTLOG`. The mode letter typed after the transaction id picks the START(s):

| Mode | START(s) | Point |
|---|---|---|
| A | `INTERVAL(0) FROM(20 bytes)` | the basic hand-off; the second RETRIEVE is ENDDATA |
| N | `INTERVAL(0)`, no FROM | the *first* RETRIEVE is ENDDATA |
| T | `TIME(103000)`, then `TIME(093000)`, at 10:00:00 | 09:30 is in the past but within six hours, so it runs *now*, before the 10:30 one |
| L | `INTERVAL(0) FROM(30 bytes)`, RETRIEVE into 20 | truncation, LENGERR, LENGTH set to 30 |
| X | a START, a START PROTECT, then `ABEND ABCODE('GTAB')` | the plain START survives the abend; the PROTECTed one is discarded |

## Why a naive translation breaks

* In Java, START is usually mapped to "submit to an executor / send a message". What goes
  wrong:
  * **Scheduling**: `TIME(hhmmss)` is a time of day, not a delay, and a time up to six
    hours in the past means "now". A port that computes `time - now` either schedules it for
    tomorrow or throws on a negative delay.
  * **Transactionality**: a START without PROTECT takes effect even if the starter abends
    afterwards. With PROTECT it takes effect only at the starter's syncpoint (here, normal
    task end). A port that enqueues inside the starter's transaction and rolls back on
    failure loses the unprotected task. A port that enqueues immediately runs the protected
    one.
* **RETRIEVE is a pull with conditions**: ENDDATA when there is no (more) data, including a
  START without FROM. LENGERR when the area is too short, with truncation and the true
  length returned. A port that passes the data as a method argument has no way to express
  either, or the second RETRIEVE.
* The started task has no terminal, and no COMMAREA (EIBCALEN 0).

## Expected behaviour

Model (SPEC section 4): a request expires at issue time + INTERVAL, or at TIME. A
non-terminal request is dispatched once it has expired and its issuing task has ended.

* **`interval-data`**: at 10:00:00, START INTERVAL(0) FROM `ORDER 0001 READY` (20 bytes)
  → expires 10:00:00 [START]. GT01 sends `STARTS ISSUED` and RETURNs. GT02 runs with no
  terminal:
  * RETRIEVE INTO(20) → NORMAL, LENGTH 20, the data [RETRIEVE]. Logged
    `R=00 L=0020 D=ORDER 0001 READY`.
  * RETRIEVE again → ENDDATA: "No more data is stored for the task issuing a RETRIEVE
    command" [RETRIEVE]. Logged `R=29 L=0000 D=` (DFHRESP(ENDDATA) = 29 [RESP-CODES]; the
    program logs length 0 itself and does not rely on LENGTH after ENDDATA).
* **`no-data`**: START INTERVAL(0) with no FROM. GT02's first RETRIEVE → ENDDATA: "The
  RETRIEVE command is issued by a task that is started by a START command that did not
  specify any of the data options FROM, RTRANSID, RTERMID, or QUEUE" [RETRIEVE].
* **`time-six-hours`**: at 10:00:00, START TIME(103000) (event 1) and START TIME(093000)
  (event 2). TIME "specifies ... the time when a new task is started", and "if the START
  gets triggered at any time within 6 hours after the time specified on the START, it runs
  immediately" [START]. So event 2 expires at 10:00:00 and its GT02 task runs right after
  GT01 (task 2: `ORDER 0002 LATE`). Event 1's task runs at 10:30:00 (task 3:
  `ORDER 0001 READY`). Each non-terminal GT02 task retrieves only the data of the START that
  created it, then ENDDATA. GTLOG ends with 4 items in that order.
* **`retrieve-lengerr`**: FROM 30 bytes (`THIRTY BYTE PAYLOAD 0123456789`), RETRIEVE
  LENGTH(20): "If the length of the data exceeds the value specified, the data is truncated to
  that value and the LENGERR condition occurs. On completion ..., the data area is set to
  the original length of the data" [RETRIEVE]. WS-DATA = `THIRTY BYTE PAYLOAD ` and WS-LEN =
  30. RESP means no abend. Logged `R=22 L=0030 D=THIRTY BYTE PAYLOAD `. The next RETRIEVE →
  ENDDATA.
* **`protect-abend`**: START (event 1, no PROTECT), START PROTECT (event 2), then ABEND GTAB
  with no exit, so the task terminates and nothing is sent. PROTECT "Specifies that the new
  task is not started until the starting task has taken a sync point. If the starting task
  abends before the sync point is taken, the request to start the new task is canceled"
  [START]. So event 2 never runs. Event 1 carries no such condition and is not undone by the
  abend: its GT02 task runs and logs `R=00 L=0020 D=UNPROTECTED START`.
* **`unknown-mode`**: `GT01 Z`. RECEIVE returns the 6 bytes. `Z` matches no WHEN and the
  EVALUATE has no WHEN OTHER, so no START is issued: an EVALUATE with no matching WHEN and no
  WHEN OTHER passes control to the end of the statement (Enterprise COBOL LR, EVALUATE).
  GTSTART still sends `STARTS ISSUED` and RETURNs. No interval-control request exists, so
  no GT02 task runs before `until`, and GTLOG is never written. A port that maps the modes
  to a lookup that throws on a missing key, or schedules a default task, diverges.

## What a correct port must do

* Keep a scheduler of interval-control requests with expiry times computed per CICS rules,
  including the six-hour rule for TIME.
* Store FROM data with each request, and implement RETRIEVE per task: NORMAL, LENGERR with
  truncation and true length, ENDDATA.
* Make a PROTECT request visible only at the starter's syncpoint and drop it on abend.
  Make a non-PROTECT request survive the starter's abend.

## Avoided ambiguities

* **Concurrency.** In real CICS a non-terminal task started with INTERVAL(0) can begin while
  GT01 is still running. Nothing here depends on it: GT01 and GT02 share no observable
  resource (GT01 never touches GTLOG), and each scenario's GT02 tasks either run alone or at
  different times (10:00 vs 10:30).
* **TIME more than six hours in the past** (next day or not) is not used.
* LENGTH after ENDDATA is never read.
* RTRANSID/RTERMID/QUEUE, REQID and CANCEL are not used here (see gt-terminal-coalesce).

## Citations

* [START] CICS TS 6.x, EXEC CICS START (INTERVAL, TIME and the six-hour rule, FROM/LENGTH, PROTECT, TERMID): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RETRIEVE] CICS TS 6.x, EXEC CICS RETRIEVE (LENGTH, truncation, ENDDATA cases, LENGERR): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-retrieve
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (ENDDATA = 29, LENGERR = 22): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
* [ABEND] CICS TS 6.x, EXEC CICS ABEND: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-abend
* Enterprise COBOL for z/OS Language Reference (SC27-8713): EVALUATE (no WHEN selected and no WHEN OTHER: execution continues after END-EVALUATE).
