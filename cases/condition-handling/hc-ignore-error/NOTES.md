# hc-ignore-error: IGNORE CONDITION, HANDLE CONDITION ERROR, PUSH / POP HANDLE

## The trap

One condition, raised the same way each time, meets different handler states. A terminal
`RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)` with WS-INLEN = 4 reads the 8 bytes typed
(`IExx XYZ`). That raises **LENGERR**, whose default action abends the task (AEIV).
`HCIGN` runs under nine transactions, which it tells apart by EIBTRNID. Each one sets its
handlers before the RECEIVE:

| Transaction | Handlers at the condition | Outcome |
|---|---|---|
| `IE01` | `IGNORE CONDITION LENGERR` | ignored: `i22 08 IE01` |
| `IE02` | `HANDLE CONDITION ERROR(GOT-ERROR)` | ERROR's label: `e22` |
| `IE03` | `HANDLE CONDITION ERROR(GOT-ERROR) LENGERR(GOT-LEN)` | LENGERR's label: `l22` |
| `IE04` | `HANDLE CONDITION ERROR(GOT-ERROR)`, `IGNORE CONDITION LENGERR` | ignored: `i22 08 IE04` |
| `IE05` | `IGNORE CONDITION LENGERR`, `PUSH HANDLE` | default action: abend AEIV |
| `IE06` | `IGNORE CONDITION LENGERR`, `PUSH HANDLE`, `POP HANDLE` | ignored: `i22 08 IE06` |
| `IE07` | `HANDLE CONDITION ERROR(GOT-ERROR)`, then `POP HANDLE` with nothing pushed | INVREQ to ERROR's label: `e16` |
| `IE08` | `HANDLE CONDITION LENGERR(GOT-LEN)`, then `IGNORE CONDITION LENGERR` | ignored: `i22 08 IE08` |
| `IE09` | `HANDLE CONDITION ERROR(GOT-ERROR)`, `PUSH HANDLE` | default action: abend AEIV |

## Why a naive translation breaks

* A port that ignores ERROR's label abends `IE02` and `IE07`. A port that takes ERROR's
  label before a condition's own label or IGNORE writes `e22` in `IE03` and `IE04`.
* A port that maps IGNORE CONDITION to "no handler" abends `IE01`. One that lets a
  HANDLE CONDITION outrank a later IGNORE takes GOT-LEN in `IE08`.
* A port whose PUSH HANDLE does not suspend IGNORE or HANDLE CONDITION state goes on in
  `IE05` and `IE09`. One that does not restore that state at POP HANDLE abends `IE06`.
* A port whose POP HANDLE with nothing pushed raises nothing writes `x` in `IE07`.

## Expected behaviour

Each scenario has one task: the typed text `IExx XYZ` (8 bytes) with ENTER, and EIBCALEN 0.

1. **RECEIVE.** LENGTH(4) "specifies the maximum length that the program accepts" [RECEIVE].
   The input is longer, so "the data is truncated ... the data area specified in the LENGTH
   option is set to the original length of data" and LENGERR occurs [RECEIVE]. The event has
   resp LENGERR, length 8, and the first 4 bytes (`IExx`). DFHRESP(LENGERR) = 22
   [RESP-CODES].
2. **IGNORE CONDITION** (`ignored`, IE01): "control returns to the instruction following the
   command that failed to execute, and the EIB is set" [IGNORE]. EIBRESP is 22 and
   WS-INLEN 8. Trail `i22 08 IE01`.
3. **ERROR** (`error-label`, IE02): LENGERR is in no HANDLE CONDITION or IGNORE CONDITION
   command. "If a condition occurs that is not specified in a HANDLE CONDITION or IGNORE
   CONDITION command, the default action is taken" — but "if the default action for such a
   condition terminates the task abnormally, and the condition ERROR has been specified, the
   action for ERROR is taken" [HC]. LENGERR's default action is to abend. GOT-ERROR writes
   `e` and EIBRESP: trail `e22`.
4. **A condition's own label first** (`own-before-error`, IE03): LENGERR is specified, so
   its own label applies. ERROR covers only conditions that are not specified. Trail `l22`.
5. **An IGNORE before ERROR** (`ignore-before-error`, IE04): LENGERR is specified in an
   IGNORE CONDITION, so ERROR does not apply. Trail `i22 08 IE04`.
6. **PUSH HANDLE suspends IGNORE** (`push-suspends-ignore`, IE05): PUSH HANDLE suspends "the
   current effect of the IGNORE CONDITION, HANDLE ABEND, HANDLE AID, and HANDLE CONDITION
   commands" [PUSH]. LENGERR therefore takes its default action. There is no HANDLE ABEND
   exit, so the task is terminated with AEIV [RESP-CODES]. The event is ABEND with
   cause condition, condition LENGERR, outcome terminated (SPEC 6.2). There is no SEND TEXT
   and no RETURN, and the task ends with `abend`.
7. **POP HANDLE restores** (`pop-restores-ignore`, IE06): POP HANDLE restores "the effect of
   IGNORE CONDITION, HANDLE ABEND, HANDLE AID, and HANDLE CONDITION commands to the state they
   were in before a PUSH HANDLE command was executed" [POP]. Trail `i22 08 IE06`.
8. **POP HANDLE with nothing pushed** (`pop-nothing-pushed`, IE07): INVREQ "Occurs if no
   matching PUSH HANDLE command has been executed at the current link level" [POP]. The
   default action is to abend, and INVREQ has no label of its own, so the action for ERROR
   is taken [HC]. INVREQ = 16 [RESP-CODES]. No RECEIVE is issued, and the `x` after the POP
   is never written. Trail `e16`.
9. **IGNORE overrides HANDLE** (`ignore-overrides-handle`, IE08): a HANDLE CONDITION
   "remains active ... until ... An IGNORE CONDITION command for the same condition is
   encountered" [HC], and IGNORE CONDITION "remains active ... until a HANDLE CONDITION
   command for the same condition is encountered" [IGNORE]. The last one wins. Trail
   `i22 08 IE08`. (hc-perform-range has the reverse order.)
10. **PUSH HANDLE suspends ERROR** (`push-suspends-error`, IE09): ERROR's label is a HANDLE
    CONDITION, so it is suspended too [PUSH]. LENGERR therefore takes its default action:
    abend AEIV, terminated, as in IE05.

Every task that does not abend sends the trail with SEND TEXT ... LENGTH(40) ERASE and
RETURNs (level 1, no TRANSID).

## What a correct port must do

* Take a condition's own HANDLE or IGNORE first, whichever came last. Next, take the default
  action. When that default action is an abend and ERROR has a label, go to the ERROR label
  instead.
* Make IGNORE CONDITION continue after the command, with the EIB set.
* Stack the whole HANDLE / IGNORE CONDITION state with PUSH HANDLE, and restore it with POP
  HANDLE. Raise INVREQ for a POP HANDLE with nothing pushed, and route it like any condition.

## Avoided ambiguities

* **IGNORE CONDITION ERROR** is not used. IBM's "the action for ERROR is taken" does not say
  whether an IGNORE of ERROR is such an action.
* **Where IGNORE leaves INTO and LENGTH.** IGNORE and the default flow do read INTO and
  LENGTH after the command, since the RECEIVE completed and moved the truncated data
  [RECEIVE]. The labels (GOT-ERROR, GOT-LEN) do not: whether INTO and LENGTH are set before a
  HANDLE CONDITION transfer is not stated.
* **The AEIV abend code**, and no HANDLE ABEND exit: the default action terminates the task.

## Citations

* [RECEIVE] CICS TS 5.5, EXEC CICS RECEIVE (3270 logical) (LENGTH, LENGERR): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-3270-logical
* [HC] CICS TS 6.x, EXEC CICS HANDLE CONDITION (ERROR, the default action, overriding): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [IGNORE] CICS TS 6.x, EXEC CICS IGNORE CONDITION: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-ignore-condition
* [PUSH] CICS TS 6.x, EXEC CICS PUSH HANDLE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-push-handle
* [POP] CICS TS 6.x, EXEC CICS POP HANDLE (INVREQ): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-pop-handle
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (LENGERR = 22, INVREQ = 16): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
