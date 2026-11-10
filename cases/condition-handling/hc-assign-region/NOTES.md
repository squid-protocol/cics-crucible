# hc-assign-region: ASSIGN PROGRAM / INVOKINGPROG across a LINK

## The trap

`HCASGA` (transaction `HC97`) issues one `EXEC CICS ASSIGN PROGRAM INVOKINGPROG RESP`, logs to TS queue
`HCLOG` (ASSIGN is not an event, SPEC 6.2), LINKs to `HCASGB` with no COMMAREA, ASSIGNs again and logs. `HCASGB` ASSIGNs
`PROGRAM` and `INVOKINGPROG` and logs. Item (31 bytes): tag (2), ` P=`, PROGRAM (8), ` I=[`, INVOKINGPROG (8), `]`, ` R=`,
RESP (2).

* **A1** `HCASGA`, first command. **B1** `HCASGB`, LINKed. **A2** `HCASGA` again after the LINK returned.

## Why a naive translation breaks

* A port that fills PROGRAM from the transaction's program, not the running one, logs `HCASGA` on B1.
* A port that leaves INVOKINGPROG as a stale value or the program's own name at the highest level fails A1 and A2.
* A port that does not restore the caller's INVOKINGPROG (blank) after the LINK returns fails A2.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal task on T001, the clock 2026-03-02T10:00:00.

* **`link-chain`**
  * A1: PROGRAM "returns an 8-character name of the currently running program" [ASSIGN]: `HCASGA`. INVOKINGPROG: "If you
    issue the ASSIGN INVOKINGPROG command in an application program at the highest level, CICS returns eight blanks."
    [ASSIGN]. `HCASGA` is the first program of the task: `I=[        ]`. RESP NORMAL: `R=00`. The area was preset to
    `XXXXXXXX`, so blanks prove the command wrote it.
  * `LINK PROGRAM('HCASGB')` without COMMAREA: a LINK event with length 0 and no commarea.
  * B1: PROGRAM is `HCASGB`. INVOKINGPROG "returns the 8-character name of the application program that used the LINK or
    XCTL command to link or transfer control to the current program" [ASSIGN]: `HCASGA`.
  * `HCASGB` RETURNs to its caller (level 2), no COMMAREA.
  * A2: back in `HCASGA`, the highest level: PROGRAM `HCASGA`, INVOKINGPROG eight blanks again.
  * `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Return the running program's name for PROGRAM, blanks for INVOKINGPROG at the highest level and the linker's name in a
  LINKed program (restored on return), NORMAL on all, in the order
  logged.

## Avoided ambiguities

* **APPLID and SYSID:** left out. IBM fixes no value for either, SPEC section 2 states no region identity (only
  `origin.applid` for INQUIRE ASSOCIATION), and the Java runtime refuses both without a stated region (`withRegion`).
  They need a SPEC region fact first; listed as a sibling gap, not asserted here.
* **INVOKINGPROG other cases:** XCTL, DPL, user exits, global user exits and PLT programs are not exercised (IBM lists
  special rules for them).
* **INVREQ:** ASSIGN raises INVREQ only for the terminal / BTS / ATI options (RESP2 2 to 6), none used here.
* **XRF generic APPLID:** not modelled.

## Citations

* [ASSIGN] CICS TS 6.x, Application Programming Reference, EXEC CICS ASSIGN (options PROGRAM, INVOKINGPROG;
  conditions INVREQ): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign (read 2026-11-10)
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
