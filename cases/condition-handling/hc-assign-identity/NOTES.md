# hc-assign-identity: ASSIGN APPLID and SYSID, the region identity a case states

## The trap

`HCIDA` (transaction `HCID`) issues `EXEC CICS ASSIGN APPLID SYSID RESP`, logs to TS queue `HCLOG` (ASSIGN is not an
event, SPEC 6.2), LINKs to `HCIDB` with no COMMAREA, ASSIGNs again in the other option order and logs. `HCIDB` ASSIGNs
`SYSID` alone, logs, then `APPLID` alone, logs. The case states the region (`region` in case.json, SPEC section 2):
APPLID `CRUCAPP1`, SYSID `CRU1`. Item (29 bytes): tag (2), ` A=[`, APPLID (8), `] S=[`, SYSID (4), `]`, ` R=`, RESP (2).
Every area is preset to `X` fill, so an option a port skips shows as `XXXXXXXX` / `XXXX`.

* **A1** `HCIDA`, both options in one command. **B1** `HCIDB`, SYSID alone. **B2** `HCIDB`, APPLID alone.
  **A2** `HCIDA` after the LINK returned, SYSID before APPLID.

## Why a naive translation breaks

* A port that writes only the first option of a multi-option ASSIGN leaves `XXXX` or `XXXXXXXX` at A1 or A2.
* A port that writes both fields whatever was asked overwrites the sentinel the command did not name (B1 would show
  `A=[CRUCAPP1]`, B2 `S=[CRU1]`).
* A port that takes the identity from the program or the transaction, or swaps APPLID and SYSID, fails every item.
* A port that gives a LINKed program a different identity than its caller fails B1 / B2 against A1 / A2.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal task on T001, the clock 2026-03-02T10:00:00, the stated region.

* **`identity`**
  * A1: APPLID is the CICS system's 8-character applid [ASSIGN], here the stated `CRUCAPP1`; SYSID is the 4-character
    name of the local CICS system [ASSIGN], the stated `CRU1`. No INVREQ is documented for either option, so RESP is
    NORMAL: `R=00`.
  * `LINK PROGRAM('HCIDB')` without COMMAREA: a LINK event with length 0 and no commarea.
  * B1: `ASSIGN SYSID` alone writes only SYSID: `A=[XXXXXXXX] S=[CRU1]`. B2: `ASSIGN APPLID` alone writes only APPLID
    (SYSID was reset to `XXXX`): `A=[CRUCAPP1] S=[XXXX]`.
  * `HCIDB` RETURNs to its caller (level 2).
  * A2: the same identity in the other option order: `A=[CRUCAPP1] S=[CRU1] R=00`. `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Fill exactly the options named, from the stated region, the same in every program of the task, NORMAL on all, and
  write the four log items in order.

## Avoided ambiguities

* **The values:** IBM fixes neither (SIT `APPLID`, `SYSIDNT` are the installation's), so the case states them
  (SPEC section 2, Region identity) and both are full length: no blank padding is relied on.
* **XRF generic APPLID:** not modelled (the page: "If your system is using XRF, the value that is returned is the generic
  APPLID").
* **PRINSYSID:** not used. IBM raises INVREQ when "the principal facility is not an MRO, LU6.1, or APPC session, or if
  the task has no principal facility", which the page's table lists as RESP2 5 only for the command as a whole; a
  sibling gap.
* **Mixed options with a failing one:** not used (the page says the other options are still populated on INVREQ).

## Citations

* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (APPLID: "This option returns an 8-character APPLID of the CICS system that
  owns the transaction."; SYSID: "This option returns the 4-character name that is given to the local CICS system."):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign (read 2026-11-10)
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
