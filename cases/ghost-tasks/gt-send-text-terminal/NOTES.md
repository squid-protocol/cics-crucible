# gt-send-text-terminal: where SEND TEXT ... TERMINAL sends its text

## The trap

`GTSTXT` (transaction `GT41`) and the task it starts send text with `EXEC CICS SEND TEXT`,
written the way programs in the field write it (`SEND TEXT FROM(...) TERMINAL WAIT FREEKB
ERASE`):

* `GT41` (`GTSTXT`), a terminal task, sends a 30-byte line with `TERMINAL WAIT FREEKB ERASE`
  and `RESP`, logs the RESP to TS queue `GTLOG` (`GT41 R=<resp>`), and sends a second line with
  `LENGTH(30) WAIT FREEKB ERASE` and no `TERMINAL`. It then STARTs `GT42` at terminal `T001`
  after 10 seconds, and `GT42` with no terminal at once, and RETURNs.
* `GT42` (`GTSTXS`) asks `ASSIGN FACILITY` (with `RESP`) for its principal facility. With one,
  it sends `GT42 SENT TO <facility>` with `SEND TEXT FROM(WS-LINE) TERMINAL WAIT FREEKB ERASE`.
  With none, it writes `GT42 NO TERMINAL` to GTLOG and sends nothing.

## Why a naive translation breaks

* A translator that does not know `TERMINAL` refuses the command, or treats it as a routing
  option and sends the text somewhere else (a print queue, a log, a "terminal" other than the
  task's own).
* `TERMINAL` is the default disposition: a port that records it, or sends differently with
  it, makes `SEND TEXT ... TERMINAL` and `SEND TEXT` differ where CICS does not.
* A port that sends to "the terminal that typed the transaction" rather than to the task's
  principal facility has no terminal to send to for a task started by `START ... TERMID`.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 24x80 3270 display. The scenario starts at 10:00:00
with `GT41` typed on T001.

* **`terminal-and-started`**:
  * GT41 starts from typed input at T001. Its `RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)`
    returns `GT41`, length 4, NORMAL (as in the other gt-* cases).
  * `SEND TEXT FROM(WS-LINE1) TERMINAL WAIT FREEKB ERASE RESP(WS-RESP)`. TERMINAL: "The
    disposition option TERMINAL sends the output to the principal facility of your task", and
    "TERMINAL is the default value that you get if you do not specify another disposition"
    [DISPOSITION]. So the text goes to T001, as a SEND TEXT without TERMINAL would. No LENGTH is
    written: "In COBOL, PL/I, and Assembler language, the translator defaults certain lengths"
    [LENGTH], here the length of WS-LINE1, 30. The event is SEND-TEXT with the FROM data
    `GT41 SENT WITH TERMINAL` (padded to 30), length 30, options `ERASE FREEKB WAIT`. TERMINAL is
    not an option of the event (SPEC 6.2). None of SEND TEXT's conditions applies [SEND-TEXT]:
    the terminal is a 3270 display with no partitions or LDCs, no logical message is active, the
    task is no DPL server, and nobody presses ATTN. RESP is NORMAL, 0 [RESP-CODES]. WS-RESP
    starts at -1, so `GT41 R=00` in GTLOG item 1 shows RESP was written.
  * `SEND TEXT FROM(WS-LINE2) LENGTH(30) WAIT FREEKB ERASE`, without TERMINAL: the same kind of
    event, `GT41 SENT WITHOUT TERMINAL`, length 30, options `ERASE FREEKB WAIT`.
  * `START TRANSID('GT42') INTERVAL(10) TERMID('T001')` expires at 10:00:10;
    `START TRANSID('GT42') INTERVAL(0)` expires at once [START]. GT41 RETURNs.
  * At 10:00:00 the second GT42 runs with no terminal. `ASSIGN FACILITY`: "If this option is
    specified, and no facility is allocated, INVREQ occurs" [ASSIGN]; RESP is given, so WS-RESP
    is 16 and GTSTXS takes the ELSE branch: GTLOG item 2 `GT42 NO TERMINAL`. It issues no SEND
    TEXT.
  * At 10:00:10 the first GT42 runs at T001 (free since GT41 ended). Its principal facility is
    T001 (`ASSIGN FACILITY` NORMAL, as for gt-assign-startcode's GT33), so its `SEND TEXT ...
    TERMINAL` sends `GT42 SENT TO T001` (length 30, the translator's default) to T001: the
    terminal the START named, which is now the task's principal facility, not the terminal
    of the task that started it (that task has ended).

## What a correct port must do

* Accept `TERMINAL` on SEND TEXT as the default disposition: the text goes to the task's
  principal facility, exactly as without it, and the recorded event is the same.
* Send a started task's text to the terminal its START named.
* Keep `WAIT`, `FREEKB` and `ERASE` as the program wrote them, and write RESP NORMAL.

## Avoided ambiguities

* **SEND TEXT in a task with no principal facility.** The SEND TEXT page lists no condition
  for it (its INVREQ cases are a DPL server and logical-message mix-ups). GTSTXS tests for a
  terminal with ASSIGN FACILITY first, as programs in the field do, and the task with none
  sends nothing.
* **RESP2 after a NORMAL SEND TEXT.** GTSTXT asks for RESP only.
* **WAIT and LAST** have no effect a program or this log can see on a 3270 display beyond
  their being written; WAIT is recorded as an option, as SPEC 6.2 allows, and LAST is not used.
* **The other dispositions and full-BMS options** (ACCUM, PAGING, SET, HEADER, TRAILER,
  JUSTIFY): a logical message ends with SEND PAGE, which no case models. None is used.
* **Concurrency.** GT41 ends before either GT42 runs (10:00:00 after it, and 10:00:10).

## Citations

* [SEND-TEXT] CICS TS 6.x, EXEC CICS SEND TEXT (TERMINAL "specifies that data is to be sent
  to the terminal that originated the transaction"; WAIT, FREEKB, ERASE; the conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-text
* [DISPOSITION] CICS TS 6.x, Output disposition options: TERMINAL, SET, and PAGING ("The
  disposition option TERMINAL sends the output to the principal facility of your task";
  "TERMINAL is the default value that you get if you do not specify another disposition";
  "TERMINAL is the only disposition available in minimum and standard BMS"):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-output-disposition-options-terminal-set-paging
* [LENGTH] CICS TS, LENGTH options in CICS commands ("In COBOL, PL/I, and Assembler language,
  the translator defaults certain lengths, if the NOLENGTH translator option is not
  specified"): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=format-length-options-in-cics-commands
* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (FACILITY; INVREQ):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
* [START] CICS TS 6.x, EXEC CICS START (INTERVAL, TERMID):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL = 0, INVREQ = 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
