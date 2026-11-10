# hc-fetch-child: FETCH CHILD / FETCH ANY / FREE CHILD of RUN TRANSID children, and their INVREQ and NOTFND cases

## The trap

HCFT (HCFPAR) reads its mode from the terminal input (`HCFT N`, `A`, `Y`, `B`, `F`). It logs one 24-byte record per
FETCH or FREE to TS queue HCFLOG, `R=rrr/sss C=c A=aaaa T=t`: RESP, RESP2, the COMPSTATUS (`N` NORMAL, `A` ABEND, `-`
not read), the ABCODE and whether the token FETCH ANY returned equals the one RUN returned (`Y`/`N`, `-` when not
asked). FETCH and FREE are not SPEC events (only RUN is), so their outcomes are observed through these records, as in
`hc-delay`. HCFD (HCFCHD) logs `CHILD RAN` to HCFCLOG and RETURNs; HCFE (HCFCHA) issues `ABEND ABCODE('HCFX')` with no
HANDLE ABEND exit.

* `N`: `RUN TRANSID('HCFD') CHILD`, then `FETCH CHILD`.
* `A`: the same with HCFE, which abends.
* `Y`: RUN HCFD, `FETCH ANY` twice.
* `B`: `FETCH ANY` with no children, then `FETCH CHILD` of a token that was never issued (LOW-VALUES).
* `F`: RUN HCFD, `DELAY INTERVAL(1)` (the child has completed), `FREE CHILD` twice, then `FETCH CHILD`.

## Why a naive translation breaks

* A port that reads the child's abend as the FETCH's RESP (an ABEND, a non-NORMAL RESP) gets `A` wrong: the FETCH is
  NORMAL and the abend is reported only through COMPSTATUS and ABCODE.
* A port that treats a second FETCH ANY with nothing left as INVREQ gets `Y` wrong: that is NOTFND with RESP2 1;
  INVREQ with RESP2 52 is the parent that never had a child (`B`).
* A port that lets FETCH CHILD return a freed child's result, or FREE CHILD of a freed token succeed, gets `F` wrong.
* A port that does not wait in FETCH returns before the child has run (`N`, `A`, `Y`).

## Expected behaviour

Model (SPEC sections 2 and 4): one region, terminal T001, clock 2026-03-02T10:00:00. Each scenario is one operator
step (`HCFT <mode>`) at time 0. The parent is task 1; a child is task 2, with trigger `{"kind": "run", "task": 1,
"event": 1}`.

* **`child-normal`** (`N`): "FETCH CHILD will return when the child task is completed." [FETCH-CHILD] The child writes
  `CHILD RAN` and returns, so the FETCH is NORMAL with COMPSTATUS NORMAL and a blank ABCODE ("ABCODE ... blank if the
  child did not abend" [FETCH-ANY]): `R=000/000 C=N A=     T=-`.
* **`child-abend`** (`A`): the child abends HCFX, the task ends `abend`. The FETCH is NORMAL, COMPSTATUS is ABEND and
  ABCODE is `HCFX`: `R=000/000 C=A A=HCFX T=-`. [FETCH-CHILD]
* **`fetch-any`** (`Y`): "FETCH ANY will return when any eligible child task has completed, or when there are no
  unfetched children remaining." [FETCH-ANY] The first FETCH ANY returns the one child's token, which is the CHILD
  token of the RUN [RUN-TRANSID]: `R=000/000 C=N A=     T=Y`. The second finds no unfetched child: NOTFND with RESP2 1
  [FETCH-ANY]: `R=013/001 C=- A=     T=-`.
* **`bad-token`** (`B`): FETCH ANY of a parent with no children is INVREQ with RESP2 52 [FETCH-ANY]
  (`R=016/052 C=- A=     T=-`); FETCH CHILD of a token that is not valid is INVREQ with RESP2 50 [FETCH-CHILD]
  (`R=016/050 C=- A=     T=-`).
* **`free-child`** (`F`): the DELAY gives the child time to complete. FREE CHILD of the token frees it (NORMAL,
  `R=000/000 C=- A=     T=-`); a freed token is invalid, so a second FREE CHILD and FETCH CHILD are INVREQ with RESP2 50
  [FREE-CHILD] [FETCH-CHILD] (`R=016/050 C=- A=     T=-` twice).

## What a correct port must do

* Return from FETCH CHILD / FETCH ANY only once the child has completed, and report a child's abend through COMPSTATUS
  and ABCODE, not through RESP.
* Tell NOTFND (RESP2 1, no unfetched children left) from INVREQ (RESP2 52, no children at all; RESP2 50, invalid or
  freed token).
* Make FREE CHILD invalidate the token.
* Run the children as tasks 2 in the SPEC section 4 order; here only one child exists per scenario.

## Avoided ambiguities

* SPEC section 3 keeps a child's order against its parent unobservable ("no FETCH"). A waiting FETCH or a DELAY makes
  the order unobservable too (the parent waits until the child ends; the child's only effect is its own TS queue); no
  scenario depends on which of two runnable tasks goes first.
* FETCH CHANNEL, NOSUSPEND and TIMEOUT (NOTFINISHED RESP2 52 / 53), ties between several children and INVREQ RESP2 51
  (channel already fetched) are left out: their outcomes depend on when the scheduler dispatches a child (register X18).
  IBM's TIMEOUT maximum differs between the FETCH ANY page and the FETCH CHILD page, so TIMEOUT is not used.
* FETCH ANY after FREE CHILD is not used. COMPSTATUS is read only when RESP is NORMAL; ABCODE is pre-set to blanks.
* COMPSTATUS is compared with the numeric CVDAs NORMAL 1016 and ABEND 900 (the CVDA list), because DFHVALUE is not
  expanded in an IF.
* The runner does not yet run this case: it names "a waiting FETCH", "FREE CHILD" and "a parent that waits with a RUN
  child" as unsupported (X18), so the cobol-stub cells are `unsupported`. The logs are derived from IBM's text only.

## Citations

* [FETCH-CHILD] IBM CICS TS 6.x, Application Programming Reference, EXEC CICS FETCH CHILD:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-fetch-child
* [FETCH-ANY] IBM CICS TS 6.x, EXEC CICS FETCH ANY: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-fetch-any
* [FREE-CHILD] IBM CICS TS 6.x, EXEC CICS FREE CHILD: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-free-child
* [RUN-TRANSID] IBM CICS TS 6.x, EXEC CICS RUN TRANSID: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-run-transid
* [RESP-CODES] IBM CICS TS 6.x, RESP and RESP2 values of each command, as on the pages above.
