# hc-perform-range: HANDLE CONDITION labels inside a PERFORM range

## The trap

`HCQREAD` (transaction `HC01`) reads a TS queue in an inline `PERFORM VARYING` loop inside the
paragraph `READ-ITEMS`, which `MAIN-PARA` runs with `PERFORM READ-ITEMS THRU READ-ITEMS-EXIT`.
The conditions go to labels set once at the top by `HANDLE CONDITION`:

* `QIDERR(NO-QUEUE)` and `ITEMERR(PAST-END)` are paragraphs **inside** the PERFORM range.
  They have no `GO TO` of their own, so NO-QUEUE falls into PAST-END, PAST-END falls into
  READ-ITEMS-EXIT, and reaching the end of READ-ITEMS-EXIT returns from the PERFORM to
  `MAIN-PARA`. A loop that ends normally also falls through both handler paragraphs.
* `ERROR(ANY-ERROR)` is **outside** the range. Any other error condition goes there.
* After the loop, the same condition (ITEMERR) is raised three more times, each handled
  differently: `RESP` on the command (no transfer), `IGNORE CONDITION` (no transfer, EIB
  set), and a fresh `HANDLE CONDITION ITEMERR(LATE-ITEM)` that overrides the IGNORE.
* `LENGTH(WS-ILEN)` is set once, before the loop. READQ TS overwrites it with each item's
  length, so a longer item after a shorter one raises LENGERR.

The program leaves a breadcrumb in `WS-TRAIL` on every path and sends it at the end, so the
flow is observable in the SEND TEXT event.

## Why a naive translation breaks

* A handler becomes a `catch` around the call that raised it. But HANDLE CONDITION is a
  `GO TO`: control does not come back to the statement after the failing command. It goes to
  the label, and in COBOL it then **falls through** the following paragraphs. Only the COBOL
  PERFORM-range rule brings it back to `MAIN-PARA`. If a port runs `noQueue()` and returns, it
  misses the `p` from PAST-END. If it runs the handler and then resumes the loop, it adds
  items that were never read.
* The `five-items` scenario raises no condition at all, yet the handler code runs ('q', 'p').
  A port that treats NO-QUEUE and PAST-END as exception handlers only drops them.
* A port that turns every HANDLE CONDITION into one try/catch per program cannot tell the
  three post-loop ITEMERRs apart. The first has RESP (no transfer), the second is IGNOREd,
  and the third goes to LATE-ITEM.
* LENGTH is an in/out argument. A port that passes it by value never raises LENGERR.

## Expected behaviour

Common to all scenarios: one task, `HC01` typed on a cleared screen (EIBCALEN = 0). The trail
starts with `m`.

1. **Handlers.** HANDLE CONDITION "specif[ies] the label to which control is to be passed if
   a condition occurs" [HC]. For COBOL, the translator implements this as a `GO TO ...
   DEPENDING ON` after the command (the EIB field DFHEIGDI), so the transfer is an ordinary
   COBOL GO TO.
2. **PERFORM range.** A GO TO to a paragraph inside the active range leaves the PERFORM
   active. Control returns to the statement after the PERFORM when the last statement of
   READ-ITEMS-EXIT has run [COBOL-PERFORM].
3. **`three-items`** (HCQ1 = `AAA`,`BBB`,`CCC`): items 1-3 NORMAL. LENGTH is set to each
   item's length [READQ-TS]: 3, and every item fits. Item 4 is ITEMERR ("the item number
   specified is invalid (outside the range ...)" [READQ-TS]), so control goes to PAST-END
   (`p`), then READ-ITEMS-EXIT, then back to MAIN-PARA (`b`).
4. **`no-queue`** (no HCQ1): item 1 raises QIDERR ("the queue specified cannot be found"
   [READQ-TS]), so control goes to NO-QUEUE (`q`), falls into PAST-END (`p`), and returns (`b`).
5. **`five-items`**: the loop ends normally after item 5 (`l`) and falls through NO-QUEUE
   (`q`) and PAST-END (`p`) before returning (`b`).
6. **After the loop** (scenarios 3-5): WRITEQ TS HCWORK creates the queue with item 1
   [WRITEQ-TS].
   * `ITEM(2) RESP(WS-RESP)`: ITEMERR. "The HANDLE CONDITION command is temporarily
     deactivated by the NOHANDLE or RESP option on a command" [HC], so there is no transfer.
     WS-RESP = DFHRESP(ITEMERR) = 26 [RESP-CODES], giving `r26`.
   * `IGNORE CONDITION ITEMERR`, then `ITEM(3)`: ITEMERR is ignored: "control returns to the
     instruction following the command ..., and the EIB is set" [IGNORE]. EIBRESP = 26,
     giving `i26`.
   * `HANDLE CONDITION ITEMERR(LATE-ITEM)`, then `ITEM(4)`: the IGNORE "remains active ...
     until a HANDLE CONDITION command for the same condition is encountered, in which case the
     IGNORE CONDITION command is overridden" [IGNORE]. So control goes to LATE-ITEM (`t`),
     which does GO TO SEND-TRAIL. The `x` after the READQ is never written.
7. **`length-trap`** (HCQ1 = `A`,`BBBBB`): item 1 sets WS-ILEN to 1. Item 2 is 5 bytes, so
   LENGERR: "the length of the stored data is greater than the value specified by the LENGTH
   option". The data is truncated to 1 byte ('B' into WS-ITEM(1:1)) and LENGTH is set to the
   stored length, 5 [READQ-TS]. No HANDLE is active for LENGERR, but one is for ERROR: "If no
   HANDLE CONDITION command is active for a condition, but one is active for ERROR, control
   passes to the label for ERROR" [DEFAULT-HANDLING]. So control goes to ANY-ERROR (`e`,
   EIBRESP = 22 LENGERR [RESP-CODES]) and then falls into SEND-TRAIL. The PERFORM stays
   pending, but control never reaches the end of READ-ITEMS-EXIT again, and the task
   RETURNs.

Trails: `three-items` `mABCpbr26i26t`, `no-queue` `mqpbr26i26t`, `five-items`
`mABCDElqpbr26i26t`, `length-trap` `mAe22`. The trail is sent with SEND TEXT FROM(WS-TRAIL)
LENGTH(40) ERASE; the event records the 40-byte FROM area (the rest of it is blanks).

## What a correct port must do

* Model HANDLE CONDITION as a per-program table of condition to label that changes at run
  time, and model the transfer as a jump to that label with COBOL fall-through and
  PERFORM-range return semantics. A `catch` around the call site is not enough.
* Honour, per command, RESP/NOHANDLE (no transfer), IGNORE CONDITION (no transfer, EIB set),
  and "last HANDLE or IGNORE for this condition wins".
* Route a condition with no specific handler to the ERROR label when one is active. Abend
  (AEIx) only when neither is active.
* Treat LENGTH on READQ TS as in/out.

## Avoided ambiguities

* `HANDLE CONDITION ITEMERR` with **no label** deactivates the handler "and the default
  action is taken" [HC]. Whether an active ERROR label then catches it is not stated clearly
  enough, so the case never names a condition without a label.
* LENGTH after ITEMERR/QIDERR is not documented, so those events carry no `length`, and the
  program never uses WS-ILEN after them (a later READQ that succeeded would reset it).
* The PERFORM left pending in `length-trap` is never reached again (the task RETURNs), so
  the case does not depend on what Enterprise COBOL does with overlapping PERFORM ranges.

## Citations

* [HC] CICS TS 6.x, EXEC CICS HANDLE CONDITION: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [IGNORE] CICS TS 6.x, EXEC CICS IGNORE CONDITION: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-ignore-condition
* [DEFAULT-HANDLING] CICS TS 6.x, Modifying default CICS exception handling: https://www.ibm.com/docs/en/cics-ts/6.x?topic=conditions-modifying-default-cics-exception-handling
* [RESP] CICS TS 6.1, How to use the RESP and RESP2 options: https://www.ibm.com/docs/en/cics-ts/6.1?topic=code-how-use-resp-resp2-options
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (DFHRESP values): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [READQ-TS] CICS TS 6.x, EXEC CICS READQ TS (LENGTH, ITEMERR, QIDERR, LENGERR): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-readq-ts
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
* [COBOL-PERFORM] Enterprise COBOL for z/OS Language Reference (SC27-8713), "PERFORM statement": the return mechanism of an out-of-line PERFORM ... THRU and the GO TO rules within a PERFORM range.
