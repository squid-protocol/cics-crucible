# hc-map-not-in-mapset: SEND MAP / RECEIVE MAP for a map the mapset does not hold is abend ABM0

## The trap

`HCMAB` (transaction `HC61`) is typed with a mode after `HC61`. Mapset `HCSET3` holds one map, `HCM3`.

* **O** `SEND MAP('HCM3') MAPSET('HCSET3') FROM(HCM3O) ERASE`, then `SEND TEXT` and RETURN: the control, the map is in the
  mapset.
* **S** `SEND MAP('HCSET3') FROM(HCM3O) ERASE` with no `MAPSET`. The name is the mapset's, not a map's: the real-world
  source defect this case is modelled on is a program naming its mapset in `MAP` and leaving `MAPSET` out.
* **R** `RECEIVE MAP('HCSET3') INTO(HCM3I)` with no `MAPSET`, the same mistake on input.
* **X** `HANDLE ABEND LABEL(MAP-ABEND)`, then `SEND MAP('HCNONE') MAPSET('HCSET3')`: a map the (named) mapset does not hold.
  The exit does `ASSIGN ABCODE`, writes `X1 ` + the code to TS queue `HCLOG` (ASSIGN is not an event, SPEC 6.2), sends
  `DONE OK` and RETURNs.

## Why a naive translation breaks

* A port that resolves the map by its name alone (a map table keyed by map name, mapset ignored) finds nothing for
  `HCSET3` and either refuses, or, worse, sends another map.
* A port that treats a missing map as a condition (a RESP value, MAPFAIL) cannot be told apart here, but gives a program that
  tests `RESP` the wrong control flow; IBM lists no condition for it.
* A port that lets the program carry on after the failed SEND MAP (sends `DONE OK`) logs events CICS never produced.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; the clock is 2026-03-02T10:00:00; the code page is EBCDIC CCSID 037.

* **`in-mapset`** (O): RECEIVE of `HC61 O` (6 bytes); SEND-MAP `HCM3` of `HCSET3` with ERASE (the field `NAME` is
  `ATTRB=(UNPROT,NORM,IC,FSET)`: attribute X'C1', no data sent, cursor on it, SPEC 6.3); SEND-TEXT `DONE OK`; RETURN.
* **`omitted-mapset`** (S): "If this option [MAPSET] is not specified, the name given in the MAP option is assumed to be
  that of the mapset" [SEND-MAP]. CICS therefore looks for map `HCSET3` in mapset `HCSET3`, which holds only `HCM3`. That is
  abend ABM0: "The map specified for a basic mapping support (BMS) request could not be located"; system action: "The
  transaction is abnormally terminated with a CICS transaction dump" [ABM0]. No SEND-MAP event (nothing was sent), no
  SEND-TEXT, no RETURN: the task ends `abend`. The `ABEND` event has `cause` `system` (an abend CICS itself raises; neither
  EXEC CICS ABEND nor an unhandled condition: SEND MAP's condition list [SEND-MAP] has no condition for a missing map).
* **`receive`** (R): the same abend for the RECEIVE MAP [RECEIVE-MAP] [ABM0]; no RECEIVE-MAP event.
* **`exit`** (X): the same abend, now with an active HANDLE ABEND exit: control goes to `MAP-ABEND` (the `ABEND` event has
  outcome `exit`, the exit being HCMAB's `MAP-ABEND`) [HANDLE-ABEND]. `ASSIGN ABCODE` returns `ABM0` [ASSIGN]. Item:
  `X1 ABM0` (7 bytes). The exit sends `DONE OK` and RETURNs normally.

## What a correct port must do

* Know which maps each mapset holds, and take MAPSET to be the MAP name when it is omitted.
* For a map its mapset does not hold, abend `ABM0` instead of sending or receiving anything; leave the task's RESP and
  HANDLE CONDITION out of it; honour a HANDLE ABEND exit.

## Avoided ambiguities

* **RESP on the failing command**: IBM lists no condition for a missing map, so `RESP` / `RESP2` / HANDLE CONDITION should
  not see ABM0; the page does not say so in as many words, and no scenario gives the command `RESP`.
* **The mapset itself missing** (PGMIDERR is how CICS reports a program, map set or partition set that is not defined when
  autoinstall is off): not used; `HCSET3` is defined in the CSD.
* **Whether RECEIVE MAP reads the terminal's input before it looks for the map**: the task's events are the same either
  way; the scenario types nothing for the map.
* **The transaction dump and the message the terminal shows**: not observable here.

## Citations

* [SEND-MAP] IBM CICS TS 6.x, EXEC CICS SEND MAP (MAPSET default; conditions INVMPSZ 38, INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map
* [RECEIVE-MAP] IBM CICS TS 6.x, EXEC CICS RECEIVE MAP (conditions INVMPSZ, INVREQ, MAPFAIL ...):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [ABM0] IBM CICS TS 6.1, abend code ABM0:
  https://www.ibm.com/docs/SSGMCP_6.1.0/reference-abend-codes/abend-codes/ABxx_abend_codes/ABM0.html
* [HANDLE-ABEND] IBM CICS TS 6.x, EXEC CICS HANDLE ABEND:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-abend
* [ASSIGN] IBM CICS TS 6.x, EXEC CICS ASSIGN (ABCODE):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
