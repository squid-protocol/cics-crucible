# hc-terminal-eoc: EOC on an LUTYPE2 terminal

## The trap

The case CSD defines the terminal `T001` with a TYPETERM of `DEVICE(LUTYPE2)`: a 3270 display
logical unit, not the reference region's 3270 logical unit (SPEC section 2). Its input message
is one SNA chain, so the RECEIVE that returns it raises **EOC**, end of chain, RESP 6. EOC's
default action is to *ignore* it, unlike almost every other condition.

`HCEOC` runs under three transactions, which it tells apart by EIBTRNID before its RECEIVE
`INTO(WS-INPUT) LENGTH(WS-INLEN)` (WS-INLEN = 20):

| Transaction | EOC handled by | Trail |
|---|---|---|
| `HC04` | `RESP(WS-RESP)` | `r`, then RESP / LENGTH / the data |
| `HC05` | `HANDLE CONDITION EOC(GOT-EOC)` | `e` and EIBRESP from the handler |
| `HC06` | neither: the default action | `i`, then EIBRESP / LENGTH / the data |

## Why a naive translation breaks

* A port that treats every RESP other than NORMAL as an error, or abends on every unhandled
  condition, abends `HC06`: CICS ignores EOC and the program goes on.
* A port whose RECEIVE always answers NORMAL never takes the EOC handler in `HC05` and shows
  RESP 0 in `HC04`.
* A port that maps HANDLE CONDITION to a `catch` writes `n` in `HC05`.

## Expected behaviour

Each scenario: one task, the transaction id and one letter typed on a cleared screen (6 bytes;
EIBCALEN 0).

1. **RECEIVE.** The 6 bytes fit in LENGTH(20): no truncation, LENGTH set to 6 [RECEIVE-LU2:
   "When the data has been received, the data area is set to the length of the data"]. On a
   3270 display logical unit the input message is an SNA chain, and its single RU carries the
   end-of-chain indicator, so EOC: "occurs when a request/response unit (RU) is received with
   end-of-chain-indicator set. Field EIBEOC also indicates this condition" [RECEIVE-LU2].
   DFHRESP(EOC) = 6 [RESP-CODES]. The RECEIVE event has resp EOC, length 6, the 6 bytes.
2. **`eoc-resp`** (`HC04 X`): RESP given: no transfer [HC], WS-RESP = 6. Trail
   `r06/06 HC04 X`.
3. **`eoc-handled`** (`HC05 Y`): HANDLE CONDITION EOC(GOT-EOC) is active: control passes to
   GOT-EOC [HC], which writes `e` and EIBRESP (6), then falls into SEND-TRAIL. The `n` after the
   RECEIVE is never written. Trail `e06`.
4. **`eoc-default`** (`HC06 Z`): no RESP, no handler. EOC's "Default action: ignore the
   condition" [RECEIVE-LU2]: control returns after the RECEIVE with the EIB set (EIBRESP 6
   [EIB]). Trail `i06/06 HC06 Z`.

Each task then sends the trail with SEND TEXT ... LENGTH(40) ERASE and RETURNs (level 1, no
TRANSID).

## What a correct port must do

* Know the terminal's device type: an LUTYPE2 terminal's RECEIVE raises EOC where a 3270
  logical unit's does not.
* Give EOC its own default action, ignore, and still set EIBRESP; route it through RESP and
  HANDLE CONDITION like any condition.

## Avoided ambiguities

* Whether CICS raises EOC on a RECEIVE that returns only part of the chain (NOTRUNCATE, or
  input longer than LENGTH) is not stated: every input here fits in one RECEIVE.
* Input longer than one RU (a chain of several RUs) is not used: 6 bytes is far below any RU
  size a BIND can negotiate.
* Whether LENGTH and INTO are set before a HANDLE CONDITION transfer is not stated: GOT-EOC
  reads neither.

## Citations

* [RECEIVE-LU2] CICS TS 5.5, EXEC CICS RECEIVE (LUTYPE2/LUTYPE3) (EOC, LENGERR, INVREQ, TERMERR; LENGTH): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-lutype2lutype3
* [RECEIVE-3270] CICS TS 5.5, EXEC CICS RECEIVE (3270 logical) (no EOC condition): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-3270-logical
* [HC] CICS TS 6.x, EXEC CICS HANDLE CONDITION: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (EOC = 6): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [EIB] CICS TS 6.x, EIB fields (EIBRESP): https://www.ibm.com/docs/en/cics-ts/6.x?topic=information-eib-fields
