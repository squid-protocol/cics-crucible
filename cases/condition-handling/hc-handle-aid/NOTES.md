# hc-handle-aid: HANDLE AID on a terminal RECEIVE

## The trap

`HANDLE AID` routes control by the attention key the operator pressed, after an input
command. `HCAID` runs under seven transactions, which it tells apart by EIBTRNID. Each one
sets its HANDLE AID labels, then issues one `RECEIVE INTO(WS-INPUT) LENGTH(WS-INLEN)`
(WS-INLEN = 20):

| Transaction | HANDLE AID state at the RECEIVE | Key(s) used |
|---|---|---|
| `HA01` | `PF7(GOT-PF7) ANYKEY(GOT-ANY)` | ENTER, PF7, PF9 |
| `HA02` | `PF7(GOT-PF7)`, then `HANDLE AID PF7` with no label | PF7 |
| `HA03` | `PF7(GOT-PF7)`, and `RESP` on the RECEIVE | PF7 |
| `HA04` | `PF7(GOT-PF7)`, then `PUSH HANDLE` | PF7 |
| `HA05` | `PF7(GOT-PF7)`, `PUSH HANDLE`, `POP HANDLE` | PF7 |
| `HA06` | none: it RETURNs `TRANSID('HA07')` | ENTER |
| `HA07` | `CLEAR(GOT-CLEAR) ANYKEY(GOT-ANY)` | CLEAR, PA1 (they send no data) |

The trail starts with a letter for the path: `n` (no label taken), `p` (GOT-PF7), `a`
(GOT-ANY), `c` (GOT-CLEAR), `r` (RESP given), `u` (pushed), `o` (popped). It then holds
LENGTH as 2 digits and the first 8 bytes of WS-INPUT. The labels write the input too, which
shows that the data had been moved before control passed.

## Why a naive translation breaks

* A port that treats ANYKEY as "any key" takes GOT-ANY on ENTER.
* A port that drops a HANDLE AID with no label keeps PF7's old label.
* A port that checks the AID before it moves the data, or before it sets LENGTH, shows
  spaces and the old LENGTH (20) in the label's trail.
* A port that ignores RESP's NOHANDLE takes GOT-PF7 in `HA03`.
* A port that keeps the HANDLE AID across PUSH HANDLE takes it in `HA04`. One that does not
  stack it loses it in `HA05`.
* A port that gives CLEAR or PA1 the ENTER path, or does not let the first RECEIVE of a task
  that CLEAR or PA1 started complete with no data, never reaches GOT-CLEAR or GOT-ANY.

## Expected behaviour

1. **RECEIVE.** In each terminal task started by typed text, the text fits LENGTH(20). The
   RECEIVE moves it and sets LENGTH to its length (6): "When the data has been received,
   the data area is set to the length of the data" [RECEIVE]. Its RESP is NORMAL. A 3270
   logical unit has no EOC [RECEIVE].
2. **When control passes.** "Control is passed after the input command is completed; that
   is, after any data received in addition to the AID has been passed to the application
   program" [AID]. So each label's trail shows LENGTH 06 and the typed text.
3. **`anykey-not-enter`** (`HA01`, ENTER): ANYKEY is "any PA key, any PF key, or the CLEAR
   key, but not ENTER" [AID], and ENTER has no label. Control "returns to the application
   program at the instruction immediately following the input command" [AID]. Trail
   `n06 HA01 A`.
4. **`own-label`** (`HA01`, PF7): PF7's label. Trail `p06 HA01 B`.
5. **`anykey-pf`** (`HA01`, PF9): PF9 has no label, but it is a PF key, so ANYKEY's label
   applies. Trail `a06 HA01 C`.
6. **`deactivated`** (`HA02`, PF7): "To ignore an AID, issue a HANDLE AID command that
   specifies the associated option without a label. This deactivates the effect of that
   option in any previously-issued HANDLE AID command" [AID]. Trail `n06 HA02 D`.
7. **`resp-no-aid`** (`HA03`, PF7): "the use of RESP implies NOHANDLE ... NOHANDLE overrides
   both the HANDLE AID and the HANDLE CONDITION command, with the result that PF key
   responses are ignored" [RESP]. WS-RESP is 0. Trail `r0006 HA03 E`.
8. **`push-suspends`** (`HA04`, PF7): PUSH HANDLE suspends "the current effect of the IGNORE
   CONDITION, HANDLE ABEND, HANDLE AID, and HANDLE CONDITION commands" [PUSH]. Trail
   `u06 HA04 F`.
9. **`pop-restores`** (`HA05`, PF7): POP HANDLE restores "the effect of IGNORE CONDITION,
   HANDLE ABEND, HANDLE AID, and HANDLE CONDITION commands to the state they were in before a
   PUSH HANDLE command was executed" [POP]. So PF7's label applies. Trail `p06 HA05 G`.
10. **`clear-no-data`** and **`pa1-anykey`**: `HA06` sends `w` and RETURNs TRANSID HA07 with
    no COMMAREA. The next key starts HA07 whatever it is (SPEC section 4), with EIBCALEN 0.
    CLEAR and PA keys transmit no data. "If a task is initiated from a terminal by means of
    an AID, the first RECEIVE command in the task does not read from the terminal but copies
    only the input buffer (even if the length of the data is zero) so that control can be
    passed by means of a HANDLE AID command for that AID" [AID]. The RECEIVE is therefore
    NORMAL with LENGTH 0. CLEAR has its own label: trail `c00`. PA1 has none, but it is a
    PA key, so ANYKEY's label applies: trail `a00`.

Each task then sends the trail with SEND TEXT ... LENGTH(40) ERASE and RETURNs (level 1, no
TRANSID), except HA06 (see above).

## What a correct port must do

* Keep each key's HANDLE AID label per program. Deactivate a key named without a label.
  Give ANYKEY PA keys, PF keys and CLEAR, but not ENTER.
* Act on the AID only after the input command has completed: data moved and LENGTH set.
* Take no AID action on a command with RESP or NOHANDLE.
* Stack the HANDLE AID state with PUSH HANDLE, and restore it with POP HANDLE.

## Avoided ambiguities

* **ANYKEY after a deactivated key.** IBM says a HANDLE AID with no label "deactivates the
  effect of that option". It does not say whether ANYKEY's label then takes that key. No
  scenario deactivates a key while ANYKEY has a label.
* **An AID and a condition on one input command.** IBM does not say which one CICS acts on
  first when the input command also raises a condition (MAPFAIL on a RECEIVE MAP after CLEAR
  or a PA key, LENGERR, EOC) and a HANDLE AID label applies to the key. No scenario raises a
  condition on a command whose key has a label. So no RECEIVE MAP is used here: CLEAR and PA
  keys would raise MAPFAIL. pc-aid-menu tests CLEAR before its RECEIVE MAP.
* **Typed transaction ids with a PF key.** The tasks started with PF7 or PF9 carry typed
  text whose first word is the transaction id (SPEC section 4). The CSD defines no PF key as
  a transaction (TASKREQ).
* **No COMMAREA** is passed between HA06 and HA07: the RETURN has none, and HA07 reads
  none.

## Citations

* [AID] CICS TS 6.x, EXEC CICS HANDLE AID (ANYKEY, the label omitted, when control passes, the first RECEIVE of a task an AID started): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-aid
* [RECEIVE] CICS TS 5.5, EXEC CICS RECEIVE (3270 logical) (LENGTH; conditions INVREQ, LENGERR, TERMERR): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-3270-logical
* [RESP] CICS TS 6.x API Reference, RESP and RESP2 options ("the use of RESP implies NOHANDLE ... with the result that PF key responses are ignored"): https://www.ibm.com/docs/en/SSJL4D_6.x/pdf/api-reference_pdf.pdf
* [NOHANDLE] CICS TS 5.6, NOHANDLE option: https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=format-nohandle-option
* [PUSH] CICS TS 6.x, EXEC CICS PUSH HANDLE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-push-handle
* [POP] CICS TS 6.x, EXEC CICS POP HANDLE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-pop-handle
