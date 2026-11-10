# hc-handle-mapfail: the same empty ENTER is a jump, a return code or an abend

## The trap

`HCMAPF` shows a map with one unprotected field `OPT` that is **not** FSET, then returns the same transaction
with a 1-byte COMMAREA. The next task issues `RECEIVE MAP`. An ENTER that modifies nothing transmits no field,
so the RECEIVE raises MAPFAIL. Three transactions run the same program and differ only in how they treat it:

* **HM01**: `HANDLE CONDITION MAPFAIL(NO-INPUT)`. Empty ENTER: control goes to `NO-INPUT`, the `MOVE 'RECEIVE DONE'`
  after the RECEIVE never runs. ENTER with `A` typed: the handler is not used, control continues.
* **HM02**: `RECEIVE ... RESP(WS-RESP)`, tested against `DFHRESP(MAPFAIL)` / `DFHRESP(NORMAL)`. No jump.
* **HM03**: no handler, no RESP. Empty ENTER: the default action, task abend AEI9.

The outcome of each path is the text SEND TEXT puts on the screen (`AT LABEL`, `RECEIVE DONE`, `RESP MAPFAIL`,
`RESP NORMAL`).

## Why a naive translation breaks

* Porting `HANDLE CONDITION MAPFAIL(label)` as a return code leaves the statement after the RECEIVE running on an
  empty ENTER (`RECEIVE DONE` instead of `AT LABEL`).
* Porting MAPFAIL as an exception that is always caught, or as "no input is fine", hides the abend in HM03.
* Treating HM01's handler as armed for the whole task, or as raised for input that did arrive (`A`).
* In HM02 the HANDLE CONDITION is not active at all; a port that shares one handler table across the transactions
  jumps instead of returning RESP.

## Expected behaviour

Model (SPEC sections 2 and 4): one region, terminal T001, clock 2026-03-02T10:00:00, a task every 10 s.
Task 1 of each scenario types the transaction (EIBCALEN 0): SEND MAP (cursor on OPT from `IC`; the field has no FSET,
so its attribute is X'40', MDT off) and RETURN TRANSID with the COMMAREA `S`. Task 2 is the scenario.

* **`handle-empty`** (HM01, `fields: {}`): "occurs if the data to be mapped has a length of zero or does not contain a
  set-buffer-address (SBA) sequence" [RECEIVE-MAP], and it "also arises" when the operator presses "ENTER or a function key
  without entering data" [RECEIVE-MAP]. RECEIVE-MAP is logged with resp MAPFAIL. "Use the HANDLE CONDITION command to
  specify the label to which control is to be passed if a condition occurs" [HANDLE-CONDITION]: `NO-INPUT` runs, SEND
  TEXT `AT LABEL`, RETURN. The statement after the RECEIVE is skipped.
* **`handle-input`** (HM01, `OPT = A`): the field is transmitted with an SBA, RECEIVE-MAP resp NORMAL, no condition, the handler is
  not taken: SEND TEXT `RECEIVE DONE`.
* **`resp-empty`** (HM02, `fields: {}`): "The use of RESP implies NOHANDLE" [RESP]. RECEIVE-MAP resp MAPFAIL, no
  abend, no jump; `WS-RESP` equals `DFHRESP(MAPFAIL)` ("36 MAPFAIL" in the RECEIVE MAP page's condition table
  [RECEIVE-MAP]): SEND TEXT `RESP MAPFAIL`.
* **`resp-input`** (HM02, `OPT = A`): RESP is NORMAL: SEND TEXT `RESP NORMAL`.
* **`unhandled-empty`** (HM03, `fields: {}`): "Default action: terminate the task abnormally." [RECEIVE-MAP]. The abend
  code is AEI9 (SPEC section 6.2, which takes it from IBM's AEIA topic for the MAPFAIL condition; see Avoided
  ambiguities). RECEIVE-MAP resp MAPFAIL, then ABEND AEI9, task ends `abend`; nothing is sent.

## What a correct port must do

* Transfer control to the HANDLE CONDITION label on MAPFAIL, and only on MAPFAIL.
* Return MAPFAIL as RESP 36 in HM02 without a jump or an abend.
* Abend the task with AEI9 when MAPFAIL has no handler and no RESP.
* Not raise MAPFAIL when the field was transmitted.

## Avoided ambiguities

* **The INTO area after MAPFAIL.** IBM says "The receiving data area contains the unmapped input data stream" and
  "The input map is not set to nulls" [RECEIVE-MAP], but never says the area is unchanged. No scenario reads
  `HMAPI` after a MAPFAIL.
* **RESP2.** The RECEIVE MAP page gives no RESP2 values for MAPFAIL, so no log item carries one.
* **The abend code AEI9** comes from SPEC section 6.2's table, not from a page read for this case. The IBM
  abend-code page for AEI9 was not fetched; if the table is wrong, this case is.
* **IGNORE CONDITION MAPFAIL** is not exercised: the IBM IGNORE CONDITION page could not be read while writing the case.
  It stays a sibling gap.
* **HANDLE AID beside a condition on the same RECEIVE**: no HANDLE AID here (see pc-aid-menu).
* The DFHAC2206 message CICS writes on the abend is not an event (SPEC section 6.2).

## Citations

* [RECEIVE-MAP] IBM CICS TS 6.x, EXEC CICS RECEIVE MAP (MAPFAIL, default action, INTO area):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [HANDLE-CONDITION] IBM CICS TS 6.x, EXEC CICS HANDLE CONDITION (label, NOHANDLE / RESP deactivate it):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [RESP] IBM CICS TS 6.x, EXEC CICS command format and programming considerations ("The use of RESP implies NOHANDLE"):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_apiformat.html
