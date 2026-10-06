# gt-assign-startcode: what ASSIGN says about how a task was started

## The trap

`GTASGN` (transaction `GT31`) and the tasks it starts ask CICS, with `EXEC CICS ASSIGN`, how
they were started (`STARTCODE`), whose they are (`USERID`) and which terminal they have
(`FACILITY`, `SCRNHT`, `SCRNWD`), and log the answers to TS queue `GTLOG`:

* `GT31` (`GTASGN`), a terminal task, logs all five with one ASSIGN.
* `GT32` and `GT33` (both `GTASNT`), started by GT31, log `STARTCODE` and `USERID`, then ask for
  `FACILITY`, `SCRNHT` and `SCRNWD` with `RESP` / `RESP2`. On NORMAL they log the values;
  otherwise they log only the response and read none of the data areas.
* `GT34` (`GTASAB`), started with no terminal, asks for `FACILITY` with no `RESP` and no handler.

Each log item is 38 characters: `<tag> C=<startcode> U=<userid> F=<facility or resp/resp2>
H=<height> W=<width>`. The tag is `T31A`, `P31A` or `P31B` for GT31 and the transaction id for
GT32 / GT33.

| Mode | What GT31 does | Point |
|---|---|---|
| T | logs; START GT32 `INTERVAL(0) FROM`; START GT32 `INTERVAL(10)` (no FROM); START GT33 `INTERVAL(20) TERMID('T001')` (no FROM) | STARTCODE `TD`, `SD`, `S`, `S`; FACILITY on a terminal task, INVREQ RESP2 5 on a task without one |
| P | logs; `RETURN TRANSID('GT31') COMMAREA`; the next ENTER runs GT31 again, which logs | a pseudo-conversational task is `TD` too |
| X | START GT34 `INTERVAL(0)` | INVREQ with no RESP: the default action, an abend |

## Why a naive translation breaks

* A port that has no notion of how a task was started returns a constant for STARTCODE, often
  `TD`. A task started by START is `S` or `SD`, depending on FROM, and programs branch on it
  (a started task RETRIEVEs; a terminal task RECEIVEs).
* A port that maps FACILITY / SCRNHT / SCRNWD to "the terminal, or blanks / zeros" hides the
  INVREQ that CICS raises for a task with no terminal. A program that tests RESP takes the
  other branch, and one that does not test it abends in CICS.
* A port that reads USERID from the operating system, or from a configured service account,
  returns something other than the region's default user.

## Expected behaviour

Model (SPEC sections 2 and 4): nobody signs on, and the region's default user is `CICSUSER`.
T001 is a 24x80 3270 display. Every scenario starts at 10:00:00 with `GT31 <mode>` typed on
T001. ASSIGN is not an event (SPEC 6.2); its results show in the GTLOG items.

* **`terminal-and-started`** (T):
  * GT31 was started by input typed at T001: STARTCODE `TD`, "Terminal input or permanent
    transid" [ASSIGN]. USERID: "If no user is explicitly signed on, CICS returns the default
    user ID" [ASSIGN], which is `CICSUSER` [DFLTUSER]. FACILITY is "a 4-byte identifier of the
    principal facility that initiated the transaction", T001. SCRNHT / SCRNWD are "the height
    / width of the 3270 screen defined for the current task", 24 and 80 (TYPETERM
    `DEVICE(3270) TERMMODEL(2)`, a 24x80 model 2). GTLOG item 1:
    `T31A C=TD U=CICSUSER F=T001  H=24 W=80`.
  * GT31 then issues three STARTs [START]. The first, GT32 `INTERVAL(0) FROM(WS-MSG)
    LENGTH(10)`, expires at once. The second, GT32 `INTERVAL(10)` with no FROM, expires at
    10:00:10. The third, GT33 `INTERVAL(20) TERMID('T001')` with no FROM, expires at 10:00:20.
    GT31 sends `ASSIGN LOGGED` and RETURNs.
  * At 10:00:00 the first GT32 runs with no terminal. It was started by a "START command that
    passed data in the FROM option": `SD` [ASSIGN]. USERID: `CICSUSER`, since nobody signed on.
    FACILITY: "If this option is specified, and no facility is allocated, INVREQ occurs";
    SCRNHT / SCRNWD: "If the task is not initiated from a terminal, INVREQ occurs" [ASSIGN].
    INVREQ is 16 [RESP-CODES], and RESP2 is 5, "The task is not associated with a terminal; or
    the task has no principal facility" [ASSIGN]. RESP is given, so there is no abend. Item 2:
    `GT32 C=SD U=CICSUSER F=16/05 H=00 W=00`. H and W stay at their VALUE 0, because GTASNT
    reads neither area after INVREQ.
  * At 10:00:10 the second GT32: a "START command that did not pass data in the FROM option",
    so `S ` [ASSIGN]. The rest is as for the first. Item 3:
    `GT32 C=S  U=CICSUSER F=16/05 H=00 W=00`.
  * At 10:00:20 GT33 runs at T001 (free since GT31 ended). It was started by a START without
    FROM, so `S `. It does have a terminal: FACILITY T001, 24 x 80, and RESP NORMAL. Item 4:
    `GT33 C=S  U=CICSUSER F=T001  H=24 W=80`.
* **`pseudo-conversational`** (P): GT31 logs `P31A C=TD U=CICSUSER F=T001  H=24 W=80`, sends
  `ASSIGN LOGGED` and issues `RETURN TRANSID('GT31') COMMAREA(WS-CA) LENGTH(4)`. At 10:00:30
  the operator presses ENTER. The terminal input starts GT31, the transaction the RETURN named
  (SPEC 4), with EIBCALEN 4 and COMMAREA `NEXT`. It is still a task started by "Terminal input
  or permanent transid": `TD` [ASSIGN]. It logs `P31B C=TD U=CICSUSER F=T001  H=24 W=80`,
  sends, and RETURNs with no TRANSID.
* **`no-terminal-abend`** (X): GT31 STARTs GT34 `INTERVAL(0)` with no TERMID, sends, and
  RETURNs. GT34 runs with no terminal and writes `GT34 RAN` to GTLOG. Its `ASSIGN
  FACILITY(WS-FAC)` raises INVREQ (RESP2 5, as above). The program has no RESP, no NOHANDLE
  and no HANDLE CONDITION. INVREQ's "Default action: terminate the task abnormally"
  [ASSIGN], with abend code AEIP for INVREQ [AEIA]. The second WRITEQ is never reached. The
  task ends `abend`. The TS item written before the abend stays: the region's queues are
  non-recoverable (SPEC 2).

## What a correct port must do

* Know how each task was started: terminal input, or a pseudo-conversational RETURN TRANSID,
  gives `TD`. A START gives `SD` if it passed FROM data, otherwise `S`.
* Return the region's default user ID for USERID when nobody has signed on.
* Return the terminal's id and screen size for FACILITY / SCRNHT / SCRNWD, and raise INVREQ
  with RESP2 5 for a task with no terminal, through RESP or the condition's handling.

## Avoided ambiguities

* **The other data areas of an ASSIGN that raises INVREQ.** IBM does not say whether an
  ASSIGN that raises INVREQ for one option still sets the others. GTASNT asks for STARTCODE /
  USERID in a separate ASSIGN, and reads none of FACILITY / SCRNHT / SCRNWD after INVREQ.
* **A RUN TRANSID child's STARTCODE.** IBM's code list has no entry for it. No task here is
  a RUN child.
* **Several START requests satisfied by one terminal task** (SPEC 4), some with FROM and some
  without. Which code the task gets is not documented. GT33's START is the only request for
  GT33 at T001.
* **A START that passes RTRANSID / RTERMID / QUEUE but no FROM.** IBM's codes are worded by
  FROM alone ("did not pass data in the FROM option"), so such a START would be `S`. No START
  here passes them.
* **Concurrency.** Every task writes GTLOG, but no two of them can run at the same time. GT31
  ends before any started task is dispatched (they run at 10:00:00 after it, 10:00:10 and
  10:00:20). In mode P the second GT31 runs at 10:00:30.
* **Security.** The region has no security and nobody signs on (SPEC 2), so there is no
  signed-on user, surrogate user or preset terminal security that could change USERID.

## Citations

* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (STARTCODE and its codes S / SD / TD, USERID,
  FACILITY, SCRNHT, SCRNWD; condition INVREQ RESP2 5, default action):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
* [DFLTUSER] CICS TS 5.4, DFLTUSER system initialization parameter
  (`DFLTUSER={CICSUSER|userid}`; terminal users who do not sign on get the default user's
  attributes): https://www.ibm.com/docs/en/cics-ts/5.4?topic=summary-dfltuser
* [START] CICS TS 6.x, EXEC CICS START (INTERVAL, TERMID, FROM):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ = 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [AEIA] CICS TS 6.x, abend codes AEIx (AEIP: INVREQ):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aeia
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
