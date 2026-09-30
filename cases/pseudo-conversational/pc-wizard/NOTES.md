# pc-wizard: a three-screen pseudo-conversation

## The trap

A three-step wizard (name → amount → confirm) spread over two programs and three
transaction ids. No task survives an operator think-time. Each task ends with `RETURN
TRANSID(next) COMMAREA(state)`, and the next key the operator presses starts a **new task**
that finds its state in the 30-byte COMMAREA (copybook `PCSTATE`: step, name, packed amount,
error count, a "back" flag):

| Transid | Program | Handles |
|---|---|---|
| PC01 | PCWIZ | first entry, EIBCALEN = 0: send the name screen |
| PC02 | PCWIZ | the name screen's answer (ENTER, CLEAR, PF3) |
| PC03 | PCCONF | the amount screen's answer (step 2) and the confirm screen (step 3); PF7 on step 3 XCTLs back to PCWIZ, still under PC03 |

## Why a naive translation breaks

* **The state is the COMMAREA, not a session object.** Between tasks nothing survives except
  the 30 bytes passed on RETURN and the next TRANSID. A port that keeps the wizard in a Java
  session or controller field behaves differently when the COMMAREA says something else,
  for example after PF7.
* **The next program is chosen by the previous task.** The first task's RETURN TRANSID('PC02')
  decides that PCWIZ handles the next input; PCCONF handles PC03. A port that routes by URL
  or screen name, rather than by the pending TRANSID, sends PF3 on the amount screen to the
  wrong handler.
* **XCTL keeps the task's identity.** After PF7, PCWIZ runs with EIBTRNID = PC03, EIBAID =
  PF7 and EIBCALEN = 30. It must dispatch on the COMMAREA's back flag, not on "first entry"
  or the transid.
* **MAPFAIL is normal flow.** ENTER with no field modified gives RECEIVE MAP → MAPFAIL. The
  program tests it with RESP, counts an error, and redisplays.
* **CLEAR sends no data.** The programs test EIBAID for CLEAR before any RECEIVE MAP.
* **BMS input editing.** The amount field is NUM with JUSTIFY=(RIGHT,ZERO): `12550` arrives
  as `0012550`, and `999` as `0000999`, which is what makes `IS NUMERIC` true. A port that
  hands the raw typed string to the program rejects valid input.

## Expected behaviour

Common facts:
* RETURN TRANSID gives "the transaction identifier ... to be used with the next input
  message entered from the terminal", and the COMMAREA length becomes the next task's
  EIBCALEN [RETURN].
* Every SEND MAP here uses ERASE with the symbolic map cleared to LOW-VALUES first. So
  attributes come from the map (NAME X'40', AMT X'50' for UNPROT,NUM; the rest X'F0'). Data
  comes from the program where set, and otherwise from the map's INITIAL (MSG3) or nothing
  [BUILD-SCREEN].
* The cursor goes to the IC field: NAME on PCM1, AMT on PCM2. PCM3 has no IC and the cursor
  is not asserted.

* **`happy-post`**
  1. Task 1: `PC01` typed, EIBCALEN 0. INITIALIZE the state, step 1. PCM1 with `TYPE YOUR
     NAME`. RETURN TRANSID('PC02') with 30 bytes.
  2. Task 2: PC02 → PCWIZ, EIBCALEN 30, ENTER. RECEIVE MAP PCM1 → NORMAL, NAME = `ADA
     LOVELACE` (blank-padded, JUSTIFY=(LEFT,BLANK) [DFHMDF]). Step 2, PCM2 with the name.
     RETURN TRANSID('PC03').
  3. Task 3: PC03 → PCCONF, step 2. RECEIVE MAP PCM2: `12550` typed into the 7-byte NUM
     field arrives as `0012550` ("If JUSTIFY is omitted, but the NUM attribute is
     specified, RIGHT and ZERO are assumed"; here it is explicit [DFHMDF]). 12550 / 100 =
     125.50 into PC-AMOUNT (COMP-3). Step 3, PCM3 with the name and `    125.50`. MSG3 takes
     its INITIAL. RETURN TRANSID('PC03') again: the same transid with a different step.
  4. Task 4: PC03 → PCCONF, step 3, ENTER → WRITEQ TS PCLEDGER
     `ADA LOVELACE       125.50 E=00`, SEND TEXT `POSTED: ...`, RETURN with no TRANSID. The
     conversation ends.
* **`mapfail-clear-cancel`**
  1. Task 2: ENTER with nothing modified. The inbound data has no field (no SBA), so
     RECEIVE MAP raises MAPFAIL: "the data to be mapped has a length of zero or does not
     contain a set-buffer-address (SBA) sequence" [RECEIVE-MAP]. RESP was given, so there is
     no abend (AEI9 otherwise). Errors = 1, PCM1 is redisplayed with `NAME IS REQUIRED`, and
     the task RETURNs PC02.
  2. Task 3: CLEAR. The pending TRANSID PC02 is still started, with EIBAID = CLEAR (SPEC
     section 4). PCWIZ tests CLEAR, does not RECEIVE, and redisplays with `SCREEN RESTORED`.
     The COMMAREA is unchanged (errors still 1).
  3. Task 4: name `GRACE` → PCM2, RETURN PC03.
  4. Task 5: PF3 → PC03 → **PCCONF** (not PCWIZ) sends `WIZARD CANCELLED` and RETURNs
     without TRANSID.
* **`back-and-fix`**
  1. Name `ALAN`, then amount `999` → `0000999` → 9.99 → PCM3 with `      9.99`.
  2. Task 4: PF7 on step 3. PCCONF sets PC-BACK = 'Y' and does XCTL PROGRAM('PCWIZ')
     COMMAREA LENGTH(30). PCWIZ runs in the same task at the same level [XCTL], with
     EIBCALEN = 30. Its EVALUATE takes the PC-BACK branch (EIBAID is PF7, not PF3). It resets
     the flag to 'N', sets step 2, and redisplays PCM2 with `CHANGE THE AMOUNT` and
     AMT = `0000999` (9.99 × 100). It then RETURNs TRANSID('PC03').
  3. Task 5: the operator erases the field and types `100000` → `0100000` → 1000.00 → PCM3
     with `  1,000.00`.
  4. Task 6: ENTER posts `ALAN             1,000.00 E=00`.
* **`clear-and-bad-amount`**
  1. Tasks 1-2 as in `back-and-fix`: name `ALAN`, PCM2 sent, RETURN TRANSID('PC03').
  2. Task 3: CLEAR on the amount screen. The pending TRANSID PC03 starts **PCCONF** with
     EIBAID = CLEAR (SPEC section 4; EIBAID "contains the attention identifier (AID)
     associated with the last terminal control or basic mapping support (BMS) input
     operation" [EIB]). The CLEAR arm comes before `WHEN PC-STEP = 2`, so there is no
     RECEIVE. PC-STEP is 2, so it performs SEND-STEP2. PC-AMOUNT is 0, so AMTO stays null
     and AMT is sent with no data. MSG2 = `SCREEN RESTORED`. RETURN TRANSID('PC03') with the
     state unchanged.
  3. Task 4: ENTER with nothing typed. AMT is UNPROT,NUM with no FSET and the program wrote
     no attribute, so no field has its MDT on and nothing is transmitted. RECEIVE MAP →
     MAPFAIL: the condition "also arises if a program issues a RECEIVE MAP command to which
     the terminal operator responds by ... pressing ENTER or a function key without entering
     data" [RECEIVE-MAP]. RESP is given, so no AEI9. PC-ERRORS = 1, PCM2 is redisplayed with
     `AMOUNT MUST BE DIGITS` (SEND-STEP2 RETURNs, so TAKE-AMOUNT's following MOVEs never
     run). SEND-STEP2 clears PCM2O first, so nothing depends on what RECEIVE left in PCM2I.
  4. Task 5: `250` → `0000250` (JUSTIFY=(RIGHT,ZERO) [DFHMDF]) → 2.50. PCM3 with
     `      2.50` (edited by `ZZZ,ZZ9.99`: the comma in the suppressed zone becomes a blank).
     WS-MSG is spaces, so MSG3 takes its INITIAL. Step 3, errors 1.
  5. Task 6: CLEAR on the confirm screen. `IF PC-STEP = 3` is true: SEND-STEP3 with WS-MSG =
     `SCREEN RESTORED`, which is not spaces, so MSG3O carries it and the program's data
     replaces the INITIAL ("the first character of the data" is not null [BUILD-SCREEN]).
  6. Task 7: PF5. Not PF3, not CLEAR, step is not 2, not PF7, not ENTER: WHEN OTHER sends PCM3
     with `USE ENTER, PF7 OR PF3`. No RECEIVE is issued (PCM3 has no input field anyway).
  7. Task 8: ENTER posts `ALAN                 2.50 E=01`: the error from task 4 travelled in
     the COMMAREA through four more tasks.
* **`back-clear-keeps-amount`**
  1. Tasks 1-4 as in `back-and-fix` (amount 999, PF7 back to PCWIZ, which sends PCM2 with
     AMT `0000999` and RETURNs TRANSID('PC03')).
  2. Task 5: CLEAR. PC03 → PCCONF (not PCWIZ, which sent the screen). Step 2, so SEND-STEP2;
     PC-AMOUNT = 9.99 > 0, so 999 goes to AMTO as `0000999` (PIC 9(7) moved to X(7)).
     MSG2 = `SCREEN RESTORED`.
  3. Task 6: ENTER without retyping the amount. AMT was written by the program with the
     map's attribute X'50' (MDT off), and the operator did not touch it, so the terminal
     transmits no field [3270-ATTR: the MDT is set when the operator modifies the field] and
     RECEIVE MAP → MAPFAIL [RECEIVE-MAP]. Errors = 1, PCM2 is redisplayed with the amount
     still `0000999` and `AMOUNT MUST BE DIGITS`. A port that treats the displayed value as
     input accepts 9.99 here.
  4. Task 7: PF3 → PCCONF sends `WIZARD CANCELLED` and RETURNs without TRANSID. Nothing is
     posted.
* **`cancel-first-screen`**: task 1 as in `happy-post`. Task 2: PF3 on the name screen starts
  PC02 → PCWIZ with EIBCALEN = 30 [RETURN], so the first-entry IF is skipped. The EVALUATE's
  first arm (PF3) performs CANCEL-WIZARD: SEND TEXT `WIZARD CANCELLED` and RETURN without
  TRANSID, before any RECEIVE MAP.

## What a correct port must do

* Treat each operator interaction as a stateless request.
* Route it by the pending TRANSID recorded by the previous task, not by the key or screen.
* Rebuild state only from the COMMAREA bytes, whose length is EIBCALEN (0 on first entry).
* Let the program see EIBAID for every key, CLEAR included.
* Keep EIBTRNID/EIBAID/EIBCALEN across XCTL.
* Implement MAPFAIL and BMS input justification.

## Avoided ambiguities

* The screen state *between* tasks (what the operator sees) is not asserted beyond the
  events. After ERASE, every step's input is exactly what the step lists.
* CLEAR also erases the physical screen. Here the program immediately redraws with ERASE,
  so the case does not depend on what the terminal shows after CLEAR.
* RETURN IMMEDIATE, and ATI requests competing with the pending TRANSID, are not used.
* A typed amount that is not all digits (for example `12.5`, which a NUM field accepts) is
  not used: the bad-amount path is driven by MAPFAIL, which IBM states outright.

## Citations

* [RETURN] CICS TS 6.x, EXEC CICS RETURN (TRANSID for the next input, COMMAREA, EIBCALEN): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [XCTL] CICS TS 6.x, EXEC CICS XCTL: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-xctl
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP (MAPFAIL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [BUILD-SCREEN] CICS TS 6.x, Building the output screen: https://www.ibm.com/docs/en/cics-ts/6.x?topic=command-building-output-screen
* [DFHMDF] CICS TS 6.x, DFHMDF macro (JUSTIFY, NUM, IC, INITIAL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
* [AEIA] CICS TS 6.x, abend codes AEIA group (MAPFAIL = AEI9): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aeia
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
* [EIB] CICS TS 6.x, EIB fields (EIBAID, EIBCALEN): https://www.ibm.com/docs/en/cics-ts/6.x?topic=reference-eib-fields
* [3270-ATTR] CICS TS 5.4, 3270 field attributes (the MDT, set when the operator changes a field): https://www.ibm.com/docs/en/cics-ts/5.4.0?topic=terminals-3270-field-attributes
* Enterprise COBOL for z/OS Language Reference (SC27-8713): EVALUATE (arms tested in order), editing with Z and insertion characters.
