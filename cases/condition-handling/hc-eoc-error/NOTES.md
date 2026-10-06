# hc-eoc-error: HANDLE CONDITION ERROR and EOC, a condition ignored by default

## The trap

HANDLE CONDITION ERROR catches only a condition whose *default action is an abend*. EOC's
default action is to ignore it. The case CSD defines terminal `T001` as an LUTYPE2 device
(as in hc-terminal-eoc), so a RECEIVE that returns the whole input raises EOC (RESP 6).
`HCEOE` sets `HANDLE CONDITION ERROR(GOT-ERROR)` and then RECEIVEs `INTO(WS-INPUT)
LENGTH(WS-INLEN)` (WS-INLEN = 20). Under `EE02` it also sets `HANDLE CONDITION
EOC(GOT-EOC)`.

| Transaction | Handlers at EOC | Trail |
|---|---|---|
| `EE01` | ERROR only | `i06/06 EE01 Q`: EOC ignored, not sent to ERROR |
| `EE02` | ERROR and EOC | `c06`: EOC's own label |

## Why a naive translation breaks

* A port that sends every unhandled condition to ERROR's label writes `e06` in `EE01`.
* A port that abends on EOC, or treats ERROR as "any condition", never reaches the `i` path.

## Expected behaviour

Each scenario has one task: the transaction id and one letter typed on a cleared screen (6
bytes), with ENTER and EIBCALEN 0.

1. **RECEIVE.** The 6 bytes fit LENGTH(20), so LENGTH is set to 6 [RECEIVE-LU2]. The single
   RU carries end-of-chain, so EOC: "occurs when a request/response unit (RU) is received
   with end-of-chain-indicator set" [RECEIVE-LU2]. DFHRESP(EOC) = 6 [RESP-CODES].
2. **`eoc-not-error`** (`EE01 Q`): EOC is in no HANDLE CONDITION. ERROR's action is taken
   only "if the default action for such a condition terminates the task abnormally" [HC].
   EOC's "Default action: ignore the condition" [RECEIVE-LU2], so control returns after the
   RECEIVE with EIBRESP 6. Trail `i06/06 EE01 Q`.
3. **`eoc-own-label`** (`EE02 R`): EOC has a HANDLE CONDITION label, so control passes to
   GOT-EOC [HC]. Trail `c06`.

Each task sends the trail with SEND TEXT ... LENGTH(40) ERASE and RETURNs (level 1, no
TRANSID).

## What a correct port must do

* Route a condition with no handler to ERROR's label only when its default action is an
  abend. A condition ignored by default (EOC) goes on, ERROR or not.

## Avoided ambiguities

* As in hc-terminal-eoc: every input fits one RECEIVE. Whether EOC arises on a RECEIVE that
  returns only part of the chain is not stated.
* GOT-EOC reads neither INTO nor LENGTH: whether they are set before a HANDLE CONDITION
  transfer is not stated.

## Citations

* [RECEIVE-LU2] CICS TS 5.5, EXEC CICS RECEIVE (LUTYPE2/LUTYPE3) (EOC, its default action; LENGTH): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-lutype2lutype3
* [HC] CICS TS 6.x, EXEC CICS HANDLE CONDITION (ERROR): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (EOC = 6): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
