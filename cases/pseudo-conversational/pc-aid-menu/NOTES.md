# pc-aid-menu: a HANDLE AID menu, XCTL vs RETURN TRANSID, and lost state

## The trap

`PCMENU` (transaction `PC11`) is a pseudo-conversational menu. Its 10-byte COMMAREA
(`PCMENUCA`) holds a visit counter and the "last transaction".

* PF keys are handled with `HANDLE AID PF3(MENU-EXIT) PF5(MENU-REFRESH)` followed by
  `RECEIVE MAP` **without RESP**. MENU-REFRESH has no RETURN or GO TO of its own: it
  **falls through** into SHOW-MENU. Any other PF key has no label and falls through to the
  code after the RECEIVE.
* CLEAR is tested on EIBAID **before** the RECEIVE, because CLEAR transmits no data.
* The option field is `FSET`, so ENTER and PF keys always transmit it and RECEIVE MAP never
  raises MAPFAIL here.
* Option 1 XCTLs to `PCDETL` inside the current task. Option 2 sends a line of text and does
  `RETURN TRANSID('PC12') COMMAREA`, so PCDETL runs as the *next* task.
* PCDETL shows the COMMAREA and EIBTRNID, then does `RETURN TRANSID('PC11')` **without a
  COMMAREA**. The next menu task therefore sees EIBCALEN = 0 and starts a new session, even
  in the middle of a conversation.

## Why a naive translation breaks

* **HANDLE AID is not an event listener.** The transfer happens only on the next RECEIVE,
  after the input has been received, and it is a GO TO that falls through the following
  paragraphs (PF5 → MENU-REFRESH → SHOW-MENU).
* **RESP switches HANDLE AID off.** Adding RESP to that RECEIVE (a common "modernisation")
  disables the PF-key routing: "Because the use of RESP implies NOHANDLE ... NOHANDLE
  overrides both the HANDLE AID and the HANDLE CONDITION command, with the result that PF key
  responses are ignored" [RESP]. A port must model this per command.
* **Unhandled keys are not errors.** PF9 has no label, so control simply continues after
  the RECEIVE, and the program's own `IF EIBAID NOT = DFHENTER` rejects it.
* **EIBCALEN = 0 wins over the key.** After PCDETL's RETURN without COMMAREA, pressing PF3
  starts PC11 with EIBCALEN = 0. PCMENU treats that as a new session, shows WELCOME and
  never looks at the key. A port that carries a session object across requests, or handles
  PF3 globally, exits instead.
* **XCTL vs RETURN TRANSID.** Via XCTL, PCDETL runs inside the PC11 task and shows
  `TRAN: PC11`. Via RETURN TRANSID it runs as its own PC12 task and shows `PC12`. Typing
  `PC12` directly gives EIBCALEN = 0, and PCDETL refuses.

## Expected behaviour

Common: SHOW-MENU clears PCMNO, sets VISITS and MSG, does SEND MAP ERASE, and RETURNs
TRANSID('PC11') COMMAREA LENGTH(10). OPT's attribute comes from the map: (UNPROT,NORM,IC,FSET)
→ X'C1', MDT on [DFHMDF]. The cursor is at OPT (IC).

* **`option1-xctl`**
  1. Task 1: `PC11` typed, EIBCALEN 0 → visits 1, WELCOME.
  2. Task 2 (ENTER, OPT `1`): visits 2. HANDLE AID is set. RECEIVE MAP → NORMAL; ENTER has
     no label [HANDLE-AID]. OPTI = `1`, so MN-LAST = PC11 and XCTL PROGRAM('PCDETL')
     COMMAREA LENGTH(10) [XCTL]. PCDETL runs in the same task: EIBCALEN = 10, EIBTRNID =
     PC11. It shows `0002`, `PC11`, `PC11` and RETURNs TRANSID('PC11') with no COMMAREA.
  3. Task 3 (ENTER): PC11 with EIBCALEN = 0 [RETURN] → a new session: visits 1, WELCOME.
* **`option2-next-transid`**
  1. Task 2 (OPT `2`): SEND TEXT `DETAIL ON NEXT ENTER`, then RETURN TRANSID('PC12') with the
     COMMAREA (visits 2, last PC11).
  2. Task 3 (ENTER): transaction PC12 → PCDETL, EIBCALEN 10, EIBTRNID PC12. It shows `0002`,
     `PC11`, `PC12` and RETURNs TRANSID('PC11') with no COMMAREA.
  3. Task 4 (PF3): PC11, EIBCALEN 0 → WELCOME, visits 1. PF3 does not exit: the program
     tests EIBCALEN before anything else and never issues HANDLE AID or RECEIVE on this
     path.
* **`aid-keys`**
  1. Task 2 (PF5, OPT transmitted empty because of FSET): visits 2. RECEIVE MAP → NORMAL.
     The OPT field arrives with length 0: an SBA is present, so there is no MAPFAIL
     [RECEIVE-MAP]. Then, because "control is passed after the input command is completed",
     PF5 goes to MENU-REFRESH [HANDLE-AID], which sets `REFRESHED` and falls into SHOW-MENU.
  2. Task 3 (PF9): visits 3. RECEIVE → NORMAL. No PF9 label, so control continues; EIBAID is
     not ENTER, giving `KEY NOT ACTIVE`.
  3. Task 4 (CLEAR): visits 4. CLEAR is tested before any RECEIVE, giving `CLEARED`.
  4. Task 5 (PF3): visits 5 (not shown). RECEIVE → NORMAL, then MENU-EXIT: SEND TEXT
     `MENU ENDED`, RETURN with no TRANSID.
  5. Task 6: the operator clears the screen (no TRANSID is pending) and types `PC12`
     (SPEC section 5). EIBCALEN = 0, so PCDETL sends `NO
     CONTEXT - START FROM PC11` and RETURNs.
* **`invalid-option`**
  1. Task 1: `PC11` typed → visits 1, WELCOME.
  2. Task 2 (ENTER, OPT `9`): visits 2, not CLEAR. HANDLE AID is set; RECEIVE MAP → NORMAL
     (OPT is transmitted). ENTER has no label, so control continues after the RECEIVE
     [HANDLE-AID]. EIBAID is ENTER. OPTI = `9` matches neither WHEN, so WHEN OTHER sets
     `INVALID OPTION` and SHOW-MENU redisplays the menu (visits `0002`) and RETURNs
     TRANSID('PC11') with visits 2.

## What a correct port must do

* Keep HANDLE AID as per-program state consulted by input commands. Implement its GO TO
  with fall-through, and its suppression by RESP/NOHANDLE.
* Leave keys without a label to the program.
* Dispatch every request on EIBCALEN and the COMMAREA the previous task passed, and on
  nothing else. A RETURN TRANSID without COMMAREA means EIBCALEN = 0.
* Keep EIBTRNID across XCTL.

## Avoided ambiguities

* **HANDLE AID vs a condition on the same RECEIVE** (for example MAPFAIL together with a
  PF-key label). The precedence is not clearly documented, so every RECEIVE here succeeds:
  the FSET field is always transmitted, and CLEAR, the only key that sends no data, never
  reaches the RECEIVE.
* **ANYKEY** together with specific keys (precedence) is not used.
* The PERFORMs left pending when SHOW-MENU RETURNs from inside a PERFORM do not matter: the
  task ends.

## Citations

* [HANDLE-AID] CICS TS 6.x, EXEC CICS HANDLE AID ("Control is passed after the input command is completed"; keys without a label): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-aid
* [RESP] CICS TS 5.6, RESP and RESP2 options (RESP implies NOHANDLE, which overrides HANDLE AID): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=format-resp-resp2-options
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP (MAPFAIL definition): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [RETURN] CICS TS 6.x, EXEC CICS RETURN (TRANSID, COMMAREA, EIBCALEN): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [XCTL] CICS TS 6.x, EXEC CICS XCTL: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-xctl
* [DFHMDF] CICS TS 6.x, DFHMDF macro (FSET, IC): https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdf
