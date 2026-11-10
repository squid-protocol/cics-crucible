# hc-enq-deq: ENQ and DEQ with RESP, every valid form

## The trap

`HCENQD` (transaction `HC94`) issues five ENQ / DEQ pairs, each command with `RESP(..)`, and logs each RESP to TS queue
`HCLOG` (ENQ and DEQ are not events, SPEC 6.2). Item format: tag (2), ` R=`, RESP (2): 7 bytes. Tags `E1`-`E5` are the
ENQs, `D1`-`D5` the DEQs, in order E1 D1 E2 D2 ...

* **1** `RESOURCE(WS-RES)` alone (`ACCTLOCK`, 8 bytes; the whole data area is the resource name).
* **2** `RESOURCE` with `LENGTH(8)`.
* **3** ENQ `RESOURCE` with `NOSUSPEND` on a resource nobody holds.
* **4** ENQ `RESOURCE` with `MAXLIFETIME(DFHVALUE(UOW))`.
* **5** ENQ `RESOURCE` with `MAXLIFETIME(DFHVALUE(TASK))`.

## Why a naive translation breaks

* A port that raises ENQBUSY for NOSUSPEND whether or not the resource is held fails pair 3 (IBM raises it only when
  the resource is unavailable).
* A port that rejects `MAXLIFETIME`, or does not accept a `DFHVALUE` CVDA there, fails pairs 4 and 5.
* A port that requires `LENGTH` or rejects it on DEQ fails pair 2.
* A port that makes a DEQ after its ENQ anything but NORMAL fails every pair.

## Expected behaviour

* [ENQ] The resource is free (one task in the region), so each ENQ is NORMAL: the application is not suspended, and
  ENQBUSY "occurs when an ENQ command specifies a resource that is unavailable and the NOSUSPEND option is specified".
  `LENGTH` is valid in the range 1 through 255; `MAXLIFETIME` takes UOW (the default) or TASK.
* [DEQ] Each DEQ releases the resource its ENQ took, with the same `RESOURCE` (and `LENGTH`): NORMAL.
* So all ten items read `R=00`. The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Accept every form above with RESP NORMAL, in order, write the ten items to `HCLOG`, send `DONE OK` and RETURN.

## Avoided ambiguities

* **A failed ENQ** (LENGERR RESP2 1, INVREQ RESP2 2 with an incorrect MAXLIFETIME CVDA, ENQBUSY): not used. Each would
  make a runtime record an ENQ event SPEC 6.2 has no row for, and ENQBUSY needs a second task holding the resource.
* **The same task ENQing a resource it already holds**, and **DEQ of a resource not held**: every DEQ follows its ENQ and
  no resource is held twice, so the case does not depend on what IBM does there.
* **LENGTH shorter than the name** (resource identity by prefix) and **DEQ operand errors** (LENGTH outside 1-255):
  one task, so nothing observable but RESP; not used.
* **Held at end of task:** nothing is held at RETURN; the case does not read what task end releases.

## Citations

* [ENQ] CICS TS 6.x, EXEC CICS ENQ (RESOURCE, LENGTH, NOSUSPEND, MAXLIFETIME, conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-enq
* [DEQ] CICS TS 6.x, EXEC CICS DEQ (RESOURCE, LENGTH, conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-deq
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
