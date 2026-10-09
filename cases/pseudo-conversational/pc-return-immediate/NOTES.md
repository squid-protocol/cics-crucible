# pc-return-immediate: RETURN ... IMMEDIATE starts the next task at once, and SYNCONRETURN means nothing on a local LINK

## The trap

`PCIMMA` (transaction `PC51`) is typed with a mode after the transid and logs what happened to TS queue `PCLOG`
(item: a 3-byte tag, 7 bytes of text, ` R=`, RESP in 2 digits: 15 bytes; the failure items of `PCIMML` / `PCIMMS` are
tag, ` R=`, RESP, ` 2=`, RESP2: 13 bytes):

* **I** `RETURN TRANSID('PC52') COMMAREA(WS-CA) LENGTH(8) IMMEDIATE RESP(..) RESP2(..)`. `PC52` (`PCIMMB`) is the next
  task *at once*, with the 8-byte COMMAREA (`1MENU-A1`: a stage byte and 7 bytes of text). Stage 1 logs `B1`, sets the
  stage to `2` and RETURNs `TRANSID('PC52')` with the COMMAREA, *not* immediate: the next operator step (a bare ENTER)
  starts stage 2, which logs `B2` and RETURNs.
* **L** `LINK PROGRAM('PCIMML') COMMAREA(WS-CA) LENGTH(8) SYNCONRETURN RESP(..) RESP2(..)`: `PCIMML` rewrites the text
  to `LINKED!` and RETURNs; `PCIMMA` logs `A2` with what the COMMAREA now holds.
* **N** `LINK PROGRAM('PCIMML')` without a COMMAREA: `PCIMML` sees `EIBCALEN` 0 and issues `RETURN TRANSID('PC52')
  IMMEDIATE` with RESP / RESP2, in a program below the highest logical level; it logs the outcome (`L1`) and RETURNs;
  `PCIMMA` logs `A3`.
* **S** `START TRANSID('PC54') INTERVAL(0)`: `PC54` (`PCIMMS`) has no terminal and issues `RETURN TRANSID('PC52')
  IMMEDIATE` with RESP / RESP2; it logs the outcome (`S1`) and RETURNs.

## Why a naive translation breaks

* A port that reads IMMEDIATE as nothing (as the translators did: the option was "ignored") hands `PC52` to the *next
  operator step*: in `immediate` the second task would be started by the ENTER at step 1, there would be no third task,
  and `PC52`'s stage 1 would be dispatched after the operator pressed a key.
* A port that starts `PC52` at once but also uses up the next step (or loses the COMMAREA) runs stage 1 without its 8
  bytes (EIBCALEN 0, `B1` with a blank text), or stage 2 never runs.
* A port that gives a `SYNCONRETURN` link a unit of work of its own, or fails it, differs from IBM in `synconreturn`:
  the option "is ignored if the link is local".
* A port that lets a RETURN IMMEDIATE below the highest logical level, or in a task with no terminal, end the task
  (and drop the COMMAREA the caller keeps) misses INVREQ, and the `L1` / `S1` items.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is the one terminal; every program is local. Every scenario starts at 10:00:00 with
`PC51 <mode>` typed on T001.

* **`immediate`** (I, steps at 0 and 10): task 1 (`PC51`) RECEIVEs `PC51 I`, logs `A1 MENU-A1 R=00` and RETURNs
  `TRANSID(PC52)` with `1MENU-A1` and IMMEDIATE. IMMEDIATE "ensures that the transaction specified in the TRANSID option
  is attached as the next transaction regardless of any other transactions enqueued by ATI for this terminal. The next
  transaction starts immediately and appears to the operator as having been started by terminal data" [RETURN]: task 2
  (`PC52`, `PCIMMB`) runs at the same virtual time (a task takes zero time, SPEC 4), on T001, with "the communication
  area specified ... passed to the next program that runs at the terminal" [RETURN]: EIBCALEN 8, COMMAREA `1MENU-A1`.
  Its trigger is `immediate` (task 1, event 2, the RETURN) and its `eibaid` is null (see below). It logs
  `B1 MENU-A1 C=08` and RETURNs `TRANSID(PC52)` with `2MENU-A1`, without IMMEDIATE: "TRANSID specifies the transaction
  identifier to be used with the next input message entered from the terminal" [RETURN], so the ENTER at step 1 (10
  seconds) starts task 3: `PC52` again, EIBCALEN 8, `2MENU-A1`, `B2 MENU-A1 C=08`, and a plain RETURN.
* **`synconreturn`** (L): the LINK passes `1LINK-A1` (8 bytes). SYNCONRETURN "is only applicable to remote links, it is
  ignored if the link is local" [LINK]: the LINK is as without it, NORMAL (`resp2` omitted: none documented). `PCIMML`
  moves `LINKED!` into the text and RETURNs (level 2: the caller sees `1LINKED!`). `PCIMMA` logs `A2 LINKED! R=00`.
* **`link-level2`** (N): the LINK has no COMMAREA (`length` 0, `commarea` null). `PCIMML` issues the RETURN with
  IMMEDIATE at level 2: INVREQ RESP2 2, "A RETURN command with the CHANNEL, COMMAREA, or IMMEDIATE option is issued by
  a program that is not at the highest logical level" [RETURN]. INVREQ is 16 [RESP-CODES]. The command returns to the
  program (RESP given), which logs `L1  R=16 2=02`; its plain RETURN goes back to `PCIMMA` (level 2, `caller_commarea`
  null), which logs `A3 BACK    R=00`. The failed RETURN is an event with `immediate`, `transid`, `resp` and `resp2`
  and no area.
* **`no-terminal`** (S): `PC54` is started with no TERMID, so it runs with no terminal (SPEC 4, started tasks). Its
  RETURN IMMEDIATE is INVREQ RESP2 1, "A RETURN command with the TRANSID option is issued in a program that is not
  associated with a terminal" [RETURN]: logged `S1  R=16 2=01`, then the plain RETURN ends the task.

## What a correct port must do

* Treat IMMEDIATE as the next task: attach TRANSID at once, with the COMMAREA, ahead of the terminal's next input, and
  leave the next operator step for whatever the new task RETURNs.
* Accept SYNCONRETURN on a local LINK and do nothing with it.
* Raise INVREQ RESP2 2 for IMMEDIATE below the highest logical level and INVREQ RESP2 1 for a task with no terminal,
  and let the program go on (it did not end).

## Avoided ambiguities

* **EIBAID of the immediate task**, and what a terminal RECEIVE in it returns: IBM says only that it "appears to the
  operator as having been started by terminal data". `PC52` reads neither, and the log's `eibaid` is null (SPEC 4).
* **Order against START requests**: no scenario has a START request pending when a RETURN IMMEDIATE succeeds.
* **STARTCODE** of the immediate task: not read.
* **Both INVREQs at once** (no terminal *and* below the highest level): IBM lists both RESP2 values and no precedence;
  `PCIMMS` is a level-1 program, `PCIMML` runs on a terminal task.
* **RETURN IMMEDIATE without TRANSID**: not used.
* **The COMMAREA's LENGTH past 32763** (LENGERR RESP2 11): not used.
* **Remote links.** Every program is local; SYSID, DPL and the sync point a remote SYNCONRETURN takes are not modelled.

## Citations

* [RETURN] CICS TS 6.x, EXEC CICS RETURN (IMMEDIATE, TRANSID, COMMAREA; INVREQ RESP2 1 and 2, LENGERR RESP2 11):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [LINK] CICS TS 6.x, EXEC CICS LINK (SYNCONRETURN, SYSID, the remote-only conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-link
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, LENGERR 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
