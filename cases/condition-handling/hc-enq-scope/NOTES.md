# hc-enq-scope: ENQ / DEQ with the TASK and UOW scope options

## The trap

`HCENQS` (transaction `HCES`) issues five ENQ / DEQ pairs that name the scope of the enqueue, each command with
`RESP(..)`, and logs each RESP to TS queue `HCLOG` (ENQ, DEQ are not events, SPEC 6.2). Item format: tag (2), ` R=`,
RESP (2): 7 bytes. Tags `E1`-`E5` are the ENQs, `D1`-`D5` the DEQs, in order E1 D1 E2 D2 ...

* **1** ENQ then DEQ `RESOURCE(WS-RES) TASK` (`ACCTLOCK`, 8 bytes; the data area is the resource).
* **2** ENQ then DEQ `RESOURCE UOW`.
* **3** ENQ then DEQ `RESOURCE LENGTH(8) TASK`.
* **4** ENQ `RESOURCE TASK NOSUSPEND` on a resource nobody holds, then DEQ `RESOURCE TASK`.
* **5** ENQ `RESOURCE TASK`, then `EXEC CICS SYNCPOINT`, then DEQ `RESOURCE TASK`. The SYNCPOINT is the only event
  between the two log items besides the TS writes (SPEC 6.2 `SYNCPOINT`, RESP NORMAL).

`hc-enq-deq` covers the forms without the scope options (and `MAXLIFETIME`); this case covers the `TASK` and `UOW`
options.

## Why a naive translation breaks

* A port that rejects `TASK` or `UOW` on ENQ or on DEQ (both commands list both options) fails pairs 1-5.
* A port that treats the SYNCPOINT as releasing every enqueue, then fails the DEQ of pair 5 (a DEQ of a resource no
  longer held), gets an error RESP where IBM gives NORMAL: IBM says a TASK enqueue carries over units of work.
* A port that raises ENQBUSY for NOSUSPEND whether or not the resource is held fails pair 4.

## Expected behaviour

Model (SPEC sections 2 and 4): one task in the region, the clock 2026-03-02T10:00:00, terminal T001.

* The resource is free, so each ENQ is NORMAL: the application is not suspended, and ENQBUSY occurs only when the
  resource is unavailable and NOSUSPEND is specified [ENQ].
* "Option UOW forces the dequeue at the end of a unit of work (UOW). Option TASK forces the dequeue at the end of a
  task. If there are several units of work in a task, the enqueue carries over the UOWs." [ENQ]. In pair 5 the
  enqueue is task-scoped, so the SYNCPOINT does not release it and the DEQ that follows releases it: NORMAL.
* Each DEQ names the same resource, by the same method (and the same LENGTH) as its ENQ, and the same scope: NORMAL
  [DEQ].
* So all ten items read `R=00`. The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Accept `TASK` and `UOW` on ENQ and DEQ with RESP NORMAL, in order; keep the TASK enqueue across the SYNCPOINT;
  write the ten items to `HCLOG`, record the SYNCPOINT event (NORMAL) between items 9 and 10, send `DONE OK`, RETURN.

## Avoided ambiguities

* **A UOW-scoped enqueue across a SYNCPOINT:** IBM releases it at syncpoint, and what DEQ then answers for a resource
  no longer held is not stated on the ENQ / DEQ pages; no pair does that (pair 5 is TASK, pair 2 has no syncpoint).
* **Several ENQs of one resource by one task** ("a matching number of DEQ commands"), **a TASK ENQ against a UOW ENQ of
  the same resource**, and **DEQ naming a different scope than its ENQ**: no resource is held twice and each DEQ
  repeats its ENQ's scope, so the case does not depend on them.
* **A failed ENQ / DEQ** (LENGERR, INVREQ, ENQBUSY): not used; ENQBUSY needs a second task holding the resource.
* **ENQMODEL / ENQSCOPE:** no ENQMODEL is installed for `ACCTLOCK`, so the enqueue is local.
* **Held at end of task:** nothing is held at RETURN.

## Citations

* [ENQ] CICS TS 6.x, EXEC CICS ENQ (RESOURCE, LENGTH, UOW, TASK, NOSUSPEND, conditions; the quoted sentences above):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-enq
* [DEQ] CICS TS 6.x, EXEC CICS DEQ (RESOURCE, LENGTH, UOW, TASK, conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-deq
* [SYNCPOINT] CICS TS 6.x, EXEC CICS SYNCPOINT: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-syncpoint
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
