# hc-handle-aid-pf-keys: HANDLE AID labels for PF8 and PF12, in one command and in two

## The trap

`HANDLE AID` routes control by the attention key the operator pressed, after an input
command. `HCAIDK` runs under two transactions, which it tells apart by EIBTRNID. Each one sets
HANDLE AID labels for the same two keys, then issues one `RECEIVE INTO(WS-INPUT)
LENGTH(WS-INLEN)` (WS-INLEN = 20):

| Transaction | HANDLE AID state at the RECEIVE | Key(s) used |
|---|---|---|
| `HK01` | `PF8(GOT-PF8) PF12(GOT-PF12)`, one command | PF8, PF12, PF7 |
| `HK02` | `PF12(GOT-PF12)`, then `PF8(GOT-PF8)`, two commands | PF12, PF8 |

The trail starts with a letter for the path: `n` (no label taken), `e` (GOT-PF8), `t`
(GOT-PF12). It then holds LENGTH as 2 digits and the first 8 bytes of WS-INPUT; the trail is
sent with SEND TEXT ... LENGTH(40) ERASE. The labels write the input too, which shows that the
data had been moved before control passed.

## Why a naive translation breaks

* A port that keeps one HANDLE AID label per program (the last command's) loses PF12 in `HK02`:
  the second HANDLE AID, for PF8, replaces the first.
* A port that maps the PF key names by a table that stops short (PF1 to PF9, or PF10 to PF12
  swapped) takes the wrong label or none for PF12 or PF8.
* A port that takes a label for a key that has none (PF7 in `HK01`) instead of going on after
  the RECEIVE.
* A port that checks the AID before it moves the data, or before it sets LENGTH, shows spaces
  and the old LENGTH (20) in the label's trail.

## Expected behaviour

Model (SPEC sections 2 and 4): the CSD is installed, the clock is 2026-03-02T10:00:00, a task
takes no time. Each scenario types the transaction id and one word at terminal T001 with the
key named; the tasks started by PF keys carry typed text whose first word is the transaction id
(SPEC section 4). The RECEIVE moves the text (6 bytes) and sets LENGTH to 6: "When the data has
been received, the data area is set to the length of the data" [RECEIVE]; its RESP is NORMAL.

* **`two-keys-pf8`** (`HK01`, PF8): "Control is passed after the input command is completed; that
  is, after any data received in addition to the AID has been passed to the application
  program" [AID]. PF8 has a label in the command, so GOT-PF8 takes control: trail `e06 HK01 A`.
* **`two-keys-pf12`** (`HK01`, PF12): the other option of the same command: trail `t06 HK01 B`.
* **`two-keys-pf7-none`** (`HK01`, PF7): PF7 is named in no HANDLE AID; control "returns to the
  application program at the instruction immediately following the input command" [AID]:
  trail `n06 HK01 C`.
* **`separate-commands-pf12`** (`HK02`, PF12): a HANDLE AID command that names a key sets that
  key's label; IBM describes ignoring a key as a HANDLE AID that names it without a label, which
  "deactivates the effect of that option in any previously-issued HANDLE AID command" [AID], so
  the options of earlier commands stay in effect until deactivated. The later command, which
  names only PF8, does not name PF12. Trail `t06 HK02 D`.
* **`separate-commands-pf8`** (`HK02`, PF8): the later command's own label: trail `e06 HK02 E`.

Each task sends the trail and RETURNs (level 1, no TRANSID).

## What a correct port must do

* Keep a HANDLE AID label per key, per program: several options in one command, and options
  set by several commands, are all in effect.
* Know every PF key name PF1 to PF24, PF8 and PF12 included, and take no label for a key that
  has none.
* Act on the AID only after the input command has completed: data moved and LENGTH set.

## Avoided ambiguities

* **A second label for a key already labelled.** IBM's page is quoted here for deactivation
  only; no scenario gives one key two labels in turn.
* **ANYKEY, ENTER, CLEAR and PA keys, PUSH / POP HANDLE and RESP on the RECEIVE** are the
  business of `hc-handle-aid`; none is used here.
* **An AID and a condition on one input command**: the RECEIVE here (no map) raises none.
* **No PF key is defined as a transaction** in the CSD (TASKREQ).

## Citations

* [AID] CICS TS 6.x, EXEC CICS HANDLE AID (PF1-PF24 options, when control passes, a key named without a label): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-aid
* [RECEIVE] CICS TS 5.5, EXEC CICS RECEIVE (3270 logical) (LENGTH): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-3270-logical
