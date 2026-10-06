# hc-terminal-receive: unformatted terminal RECEIVE and SEND CONTROL

## The trap

`HCTERM` (transaction `HC03`) reads the operator's unformatted input with `EXEC CICS RECEIVE`
and no map. Its first RECEIVE takes six bytes with `MAXLENGTH(6) NOTRUNCATE`: the transaction
id, a blank and a mode letter. The rest of the input is retained by CICS for the next RECEIVE
of the task. Each mode then reads that rest in a different way:

| Mode | Input | Second RECEIVE | Trap |
|---|---|---|---|
| `R` | `HC03 RLONGDATA` | `INTO(WS-PART) LENGTH(WS-INLEN)` with WS-INLEN = 4, `RESP` | LENGERR, truncation, LENGTH out = 8 |
| `H` | `HC03 HTOOLONG` / `HC03 HOK` | `INTO(WS-PART)`, no LENGTH, under `HANDLE CONDITION LENGERR(TOO-LONG)` | the translator's default LENGTH; the handler is a GO TO |
| `A` | `HC03 AOVERFLOW` | `INTO(WS-PART)`, no RESP, no handler | the default action: abend AEIV |
| `N` | `HC03 NABCDEFGHIJ` | `MAXLENGTH(4) NOTRUNCATE` in a loop until a piece is shorter than 4 | nothing is discarded; LENGTH is the length returned |
| `S` | `HC03 SVIA-SET` | `SET(ADDRESS OF LS-INPUT) LENGTH(WS-INLEN) MAXLENGTH(20)` | a LINKAGE record addressing CICS's input |
| other | `HC03 C` | none; `SEND CONTROL CURSOR(WS-CURSOR) ALARM FRSET ERASEAUP` | the device controls, CURSOR as an offset |

Every task begins with `SEND CONTROL ERASE FREEKB`. The program leaves a breadcrumb in
`WS-TRAIL` on every path: `rr/ll ` (RESP and LENGTH, two digits each) after a RECEIVE, the
data it received, `L22` from the LENGERR handler, `n` when no LENGERR arose, `c` after the
device controls. The trail is sent with `SEND TEXT FROM(WS-TRAIL) LENGTH(40)`.

## Why a naive translation breaks

* LENGTH is in/out. A port that passes it by value, or reads only INTO's length, never raises
  LENGERR and never shows the original length (8 in `lengerr-resp`).
* A port that reads the whole input once and discards the rest has nothing for the second
  RECEIVE: NOTRUNCATE "retains the remaining data ... to satisfy subsequent RECEIVE commands".
  A port that ignores NOTRUNCATE raises LENGERR on the first RECEIVE and abends every task.
* Under NOTRUNCATE, LENGTH is the length *returned* (4), not the original length.
* A port that maps HANDLE CONDITION LENGERR to a `catch` around the RECEIVE comes back to the
  statement after it and writes `n`; CICS goes to TOO-LONG and never returns.
* A port that treats an unhandled condition as "carry on" sends the trail in
  `lengerr-default`; CICS abends the task first.
* `SEND CONTROL` is easy to drop: it sends no data. It is the only thing that erases the
  screen and unlocks the keyboard before the SEND TEXT.

## Expected behaviour

Common to all scenarios: one task, `HC03 <mode><rest>` typed on a cleared screen (EIBCALEN
= 0, SPEC section 5). The terminal is the reference region's 3270 logical unit, so no RECEIVE
raises EOC (SPEC section 2; [RECEIVE-3270] lists INVREQ, LENGERR and TERMERR only).

1. **`SEND CONTROL ERASE FREEKB`**: device controls only, "ERASE specifies that the screen ...
   is to be erased", "FREEKB specifies that the 3270 keyboard is to be unlocked" [SEND-CONTROL].
   None of its conditions (INVREQ for a BMS logical message, RETPAGE / TSIOERR for SET or
   PAGING, IGREQID, INVLDC, IGREQCD, INVPARTN [SEND-CONTROL]) can arise: the program builds no
   logical message and names no partition, LDC or REQID. The event has the options sorted.
2. **First RECEIVE**, `INTO(WS-HEAD) LENGTH(WS-INLEN) MAXLENGTH(6) NOTRUNCATE RESP(WS-RESP)`:
   "If INTO is specified, MAXLENGTH overrides the use of LENGTH as an input to CICS"; "If the
   length of data exceeds the value specified and the NOTRUNCATE option is present, CICS retains
   the remaining data and uses it to satisfy subsequent RECEIVE commands. The data area
   specified in the LENGTH option is set to the length of data returned" [RECEIVE-3270]. So
   NORMAL, WS-HEAD = `HC03 x`, WS-INLEN = 6: trail `00/06 `. In `device-controls` the input is
   exactly six bytes, so nothing is retained.
3. **`lengerr-resp`**: the rest is `LONGDATA` (8). With INTO and no MAXLENGTH, LENGTH "specifies
   the maximum length that the program accepts" (4). "If the length of data exceeds the value
   specified and the NOTRUNCATE option is not present, the data is truncated to that value and
   the LENGERR condition occurs. The data area specified in the LENGTH option is set to the
   original length of data"; "If this option [MAXLENGTH] is omitted, the value indicated in the
   LENGTH option is assumed" [RECEIVE-3270]. RESP suppresses any handler [HC]: WS-RESP =
   DFHRESP(LENGERR) = 22 [RESP-CODES], WS-INLEN = 8, WS-PART = `LONG`. Trail
   `00/06 22/08 LONG`.
4. **`lengerr-handled`**: no LENGTH; the CICS translator supplies the length of INTO,
   WS-PART's 4 bytes [LENGTH-OPTIONS]. The rest `TOOLONG` (7) raises LENGERR, the RECEIVE
   event shows the 4 bytes moved and the original length. HANDLE CONDITION LENGERR(TOO-LONG)
   passes control to TOO-LONG [HC] (a GO TO, SPEC section 2), which writes `L` and EIBRESP 22
   and goes to SEND-TRAIL. Trail `00/06 L22`.
5. **`handler-unused`**: the rest `OK` (2) fits: NORMAL, LENGTH not given so nothing is set
   back, no transfer; `n`. Trail `00/06 n`.
6. **`lengerr-default`**: the rest `OVERFLOW` (8) raises LENGERR with neither RESP nor a
   HANDLE active. LENGERR's "Default action: terminate the task abnormally" [RECEIVE-3270],
   abend code AEIV (SPEC 6.2). The task ends with no SEND TEXT and no RETURN.
7. **`in-pieces`**: the rest `ABCDEFGHIJ` (10) comes back as `ABCD` (4), `EFGH` (4) and `IJ`
   (2), each NORMAL, LENGTH the length returned [RECEIVE-3270]. The loop stops after the piece
   shorter than 4, and the last RECEIVE's RESP and LENGTH are noted. Trail
   `00/06 ABCD|EFGH|IJ|00/02 `.
8. **`set-address`**: `SET(ADDRESS OF LS-INPUT)` "specifies the pointer reference that is to
   be set to the address of the data read"; LENGTH "If you specify the SET option, the argument
   must be a data area. When the data has been received, the data area is set to the length of
   the data" [RECEIVE-3270]. The rest `VIA-SET` (7) is under MAXLENGTH(20): NORMAL, 7. The
   program reads only LS-INPUT(1:7). Trail `00/06 00/07 VIA-SET`.
9. **`device-controls`**: `SEND CONTROL CURSOR(WS-CURSOR) ALARM FRSET ERASEAUP`, WS-CURSOR = 85:
   CURSOR is "a halfword binary value that specifies the cursor position relative to zero"
   [SEND-CONTROL]; the event has the options sorted and `cursor: {"offset": 85}`. Trail
   `00/06 c`.

Every task that does not abend ends with SEND TEXT (the 40-byte trail, no options) and a
level-1 RETURN with no TRANSID.

## What a correct port must do

* Model the task's terminal input as a stream that RECEIVE consumes: NOTRUNCATE keeps the
  rest for the next RECEIVE; without it, longer data is truncated and LENGERR raised.
* Treat LENGTH (FLENGTH) as in/out, with MAXLENGTH taking over the input role, and set it to
  the original length on LENGERR and to the length returned otherwise.
* Supply INTO's length when LENGTH is omitted.
* Route LENGERR through RESP, HANDLE CONDITION (a jump that does not return), or the default
  abend AEIV.
* Make a LINKAGE record named by `SET(ADDRESS OF ...)` show the data received.
* Emit SEND CONTROL with its options and the CURSOR offset.

## Avoided ambiguities

* Whether INTO's bytes past the data received are left alone or overwritten is not stated:
  the program never reads them (it prints `WS-PART(1:WS-INLEN)`, or the whole of WS-PART only
  when LENGERR filled it).
* Whether LENGTH and INTO are set before a HANDLE CONDITION transfer is not stated: the
  handler TOO-LONG reads neither (the RECEIVE event still records them).
* What a RECEIVE does when nothing is retained and the operator has typed nothing more is a
  wait for input that a scenario step cannot express: every loop ends on a short piece, and
  `device-controls` issues no second RECEIVE.
* Bytes of LS-INPUT past the data received are CICS storage the documentation does not
  describe: the program reads LS-INPUT(1:WS-INLEN) only.
* A pointer reference other than `ADDRESS OF` a LINKAGE 01 record is not used.
* Whether a RECEIVE that leaves data retained raises EOC on an LUTYPE2 terminal is not
  stated: this case's terminal is a 3270 logical unit (no EOC); EOC is
  `hc-terminal-eoc`'s, without NOTRUNCATE.

## Citations

* [RECEIVE-3270] CICS TS 5.5, EXEC CICS RECEIVE (3270 logical) (INTO, SET, LENGTH, MAXLENGTH, NOTRUNCATE; INVREQ, LENGERR, TERMERR): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-3270-logical
* [SEND-CONTROL] CICS TS 5.5, EXEC CICS SEND CONTROL (ALARM, CURSOR, ERASE, ERASEAUP, FREEKB, FRSET; conditions): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-send-control
* [LENGTH-OPTIONS] CICS TS 5.6, LENGTH options in CICS commands (the translator's default length of a data area): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=format-length-options-in-cics-commands
* [HC] CICS TS 6.x, EXEC CICS HANDLE CONDITION (RESP / NOHANDLE deactivate it for the command): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (LENGERR = 22): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
