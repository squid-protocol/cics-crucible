# hc-abend-link: handlers and abend exits across LINK levels

## The trap

`HCMAIN` (transaction `HC02`) sets `HANDLE CONDITION QIDERR(MAIN-QIDERR)` and `HANDLE ABEND
LABEL(MAIN-ABEND)` and then, depending on a mode letter in TS queue `HCMODE`:

* **N, Q, A**: LINKs to `HCSUB` with a 20-byte COMMAREA. HCSUB sets no condition handler of
  its own. In mode N it tests QIDERR with RESP. In mode Q it hits QIDERR with no RESP. In
  mode A it sets its own abend exit, ABENDs with `HCX1`, and recovers with RETURN.
* **O**: `PUSH HANDLE`, `POP HANDLE`, then QIDERR in HCMAIN.
* **P**: `PUSH HANDLE`, then QIDERR in HCMAIN while the handlers are pushed.

In every surviving path HCMAIN then raises QIDERR itself (READQ TS of the absent queue
`HCNONE`) to show which handler is in force. The breadcrumb trail is sent with SEND TEXT.

## Why a naive translation breaks

* In a Java port, handlers are usually a try/catch that wraps a method call, and exceptions
  propagate up the Java stack. That gets two things wrong:
  * CICS does **not** propagate HANDLE CONDITION into a LINKed program. A QIDERR in HCSUB
    with no RESP is not caught by HCMAIN's QIDERR handler. It takes the default action,
    which abends the task with AEYH.
  * An abend is caught by the nearest **active HANDLE ABEND exit**, searched upward through
    the LINK levels. HCMAIN's MAIN-ABEND catches HCSUB's AEYH, and HCSUB is gone.
* `CA-TRAIL(1:1) = 's'` is written by HCSUB before it abends. The COMMAREA of a local LINK is
  the caller's own storage, so HCMAIN's abend exit still sees the write. A port that copies
  the COMMAREA in and back out on normal return loses it.
* PUSH HANDLE suspends HANDLE ABEND as well as HANDLE CONDITION. A port that only saves and
  restores condition handlers still catches the abend in mode P.
* ASSIGN ABCODE in the exit must give the abend code: the CICS condition abend `AEYH`, or
  the program's own `HCX1`.

## Expected behaviour

All scenarios: one task, `HC02` typed on a cleared screen, READQ TS HCMODE item 1 → the mode.

* **`sub-resp` (N)**: HCSUB writes `s`, adds 1 to CA-COUNT, and READQ HCNONE RESP → QIDERR
  (RESP means no handler is involved [HC]). It sets CA-RESULT `QIDR`, writes `n`, and
  RETURNs to HCMAIN. The LINK COMMAREA is the caller's storage: "the address of the area is
  passed to the program that is receiving control", and through it "the linking program can
  both pass data to the program it is invoking and receive results from that program"
  [COMMAREA]. HCMAIN appends `r`, `sn `, `QIDR`. Its READQ HCNONE (no
  RESP) raises QIDERR and goes to MAIN-QIDERR: "the original HANDLE CONDITION commands are
  restored on return to the linking program" [LINK]. Trail `mrsn QIDRq`.
* **`sub-unhandled` (Q)**: in HCSUB, READQ HCNONE → QIDERR. "The HANDLE CONDITION options
  are not inherited by the linked-to program" [HC], and HCSUB has no ERROR handler. The
  default action is to abend with AEYH (QIDERR) [AEIA]. "CICS searches for an active abend
  exit, starting at the logical level of the application program in which the abend
  occurred, and proceeding to successively higher levels. The first active abend exit found,
  if any, is given control" [ABEND-RECOVERY]. HCSUB has none; HCMAIN's LABEL exit is found.
  MAIN-ABEND runs ASSIGN ABCODE → `AEYH` [ASSIGN] and appends `X`, `AEYH`, `c`, and
  CA-TRAIL(1:3) = `s  ` (HCSUB's write to the shared COMMAREA). Trail `mXAEYHcs`, then SEND
  TEXT and RETURN.
* **`sub-own-exit` (A)**: HCSUB issues HANDLE ABEND LABEL(SUB-ABEND), writes `h`, and ABEND
  ABCODE('HCX1') [ABEND]. The search starts at HCSUB's own level, so SUB-ABEND gets control
  (the exit is deactivated on entry [ABEND-RECOVERY]). It does ASSIGN ABCODE → `HCX1` into
  CA-RESULT, writes `a`, and RETURNs. In an abend exit, "use a RETURN command to indicate that
  the task continues to run with control passed to the program on the next higher logical
  level" [ABEND-ROUTINE]: HCMAIN resumes after the LINK. HCMAIN appends `r`, `sha`, `HCX1`, then QIDERR → MAIN-QIDERR `q`. Trail
  `mrshaHCX1q`.
* **`push-pop` (O)**: PUSH HANDLE "suspend[s] the current effect of the IGNORE CONDITION,
  HANDLE ABEND, HANDLE AID, and HANDLE CONDITION commands" [PUSH], and POP HANDLE restores
  them [POP]. The QIDERR after POP goes to MAIN-QIDERR. Trail `muoq`.
* **`pushed-abend` (P)**: QIDERR happens while the handlers are pushed. No condition handler
  and no abend exit is in effect, and HCMAIN is the highest level. The task terminates with
  AEYH. Nothing is sent. (The DFHAC2206 message CICS writes to the terminal is not an event,
  per SPEC 6.2.)

Condition → abend code mapping: QIDERR → AEYH [AEIA].

## What a correct port must do

* Keep condition handlers and abend exits **per LINK level**. A LINKed program starts with
  none, and the caller's are restored when it returns.
* Search abend exits upward through the LINK levels, give control to the first active one
  (at its label, in its own program), and discard the levels below it.
* Deactivate an exit when it is entered.
* Make PUSH/POP HANDLE save and restore all four kinds of handler state as one stack
  element.
* Pass a local LINK COMMAREA by reference, so that callee writes are visible even when the
  callee abends.

## Avoided ambiguities

* **By-reference storage depends on addressing mode.** For XCTL, CICS creates the COMMAREA
  "in an area that conforms to the addressing mode of the receiving program" [COMMAREA]. All
  programs here are AMODE(31), so HCSUB's write before its abend lands in HCMAIN's own
  WS-CA. An AMODE(24) callee is not used.

* Whether HANDLE ABEND is in force inside a LINKed program is not exercised. The HCSUB
  paths that abend either have their own exit (A) or show that the **caller's** exit is
  found by the upward search (Q). The upward search is documented.
* A second abend inside an exit (after deactivation) is not exercised.
* How the translator makes the COBOL LABEL branch leaves any PERFORM in a pending state. The
  exits here run only straight-line code and end the task or the program (RETURN), so no
  pending PERFORM matters.
* ASRA / program checks are never raised: their codes and dumps are environment-dependent.

## Citations

* [HC] CICS TS 6.x, EXEC CICS HANDLE CONDITION ("not inherited by the linked-to program"; RESP/NOHANDLE deactivate it): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [LINK] CICS TS 6.x, EXEC CICS LINK (COMMAREA, EIBCALEN, handlers restored on return): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-link
* [HANDLE-ABEND] CICS TS 6.x, EXEC CICS HANDLE ABEND: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-abend
* [ABEND-RECOVERY] CICS TS 5.6, Abnormal termination recovery (upward search, deactivation on entry): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=applications-abnormal-termination-recovery
* [ABEND-ROUTINE] CICS TS 5.6, Creating a program-level abend program or routine (RETURN passes control to the next higher logical level): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=recovery-creating-program-level-abend-program-routine
* [COMMAREA] CICS TS 6.x, COMMAREA in LINK and XCTL commands (the address is passed; results come back through it; addressing mode): https://www.ibm.com/docs/en/cics-ts/6.x?topic=transaction-commarea-in-link-xctl-commands
* [ABEND] CICS TS 6.x, EXEC CICS ABEND: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-abend
* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (ABCODE): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
* [PUSH] CICS TS 6.x, EXEC CICS PUSH HANDLE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-push-handle
* [POP] CICS TS 6.x, EXEC CICS POP HANDLE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-pop-handle
* [AEIA] CICS TS 6.x, abend codes AEIA group (condition → abend code table; QIDERR = AEYH): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aeia
