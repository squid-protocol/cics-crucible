# hc-counter-shared-namespace: a DCOUNTER read by COUNTER commands (LENGERR RESP2 001 / 002 / 003), DEFINE of a name that exists under the other command is INVREQ RESP2 202

Follows [`hc-dcounters`](../hc-dcounters) (DCOUNTER alone), [`hc-named-counters`](../hc-named-counters) (COUNTER alone) and
[`hc-counter-increment-wrap`](../hc-counter-increment-wrap); this case puts the two command sets on one counter.

## The trap

`HCCNSP` (transaction `HC74`) is typed with a mode after `HC74` and logs each command to TS queue `HCLOG` (the named-counter
commands are not events, SPEC 6.2). Item format, 33 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` V=`, the value as 16 hex
digits (a fullword result is right-aligned, so `7FFFFFFF` is `000000007FFFFFFF`). RESP2 is logged only for a failed command; the
value only for a command that completed (zeros otherwise). Pool `HCPOOL`, counters `HCNSP1` / `HCNSP2` / `HCNSP3`.

* **B**: `DEFINE DCOUNTER` at 2**31, 2**32 and 2**33; `QUERY COUNTER` of each; `GET COUNTER` of the 2**32 one; `QUERY DCOUNTER` of
  the 2**31 one.
* **F**: `DEFINE DCOUNTER` at 2**31 - 2; `QUERY COUNTER`, `GET COUNTER`, `QUERY COUNTER` while the value fits; `GET DCOUNTER` takes it to
  2**31; `QUERY COUNTER`; `QUERY DCOUNTER`.
* **D**: `DEFINE DCOUNTER` (VALUE 5), then `DEFINE COUNTER` of the same name with and without VALUE, `QUERY DCOUNTER`; `DEFINE COUNTER`
  (VALUE 9), then `DEFINE DCOUNTER` of the same name, `QUERY COUNTER`, `QUERY DCOUNTER`.

## Why a naive translation breaks

* A port that keeps COUNTER and DCOUNTER names in separate tables lets the second DEFINE of D2, D3, D6 succeed (`R=00`), where IBM
  returns INVREQ 202, and then answers D4 / D7 from the wrong counter.
* A port that truncates the doubleword to a fullword on a COUNTER command returns a wrapped or negative value (B2, B4, B6, B7, F6)
  where IBM returns LENGERR.
* A port that gives every LENGERR the same RESP2 loses 001 / 002 / 003.
* A port that raises LENGERR on a COUNTER command for a value that fits (F2 - F4) is wrong; a port that never raises it past
  2**31 - 1 is wrong at F6.
* A port that makes a failed DEFINE reset the existing counter shows it at D4.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; the region starts with no named counters; each scenario starts at 10:00:00
on 2026-03-02 with `HC74 <mode>` typed on T001. INVREQ is RESP 16 and LENGERR RESP 22 [RESP-CODES].

* **`big`** (B). LENGERR "occurs for COUNTER commands only and does not apply to DCOUNTER requests" and "occurs when a counter that
  was defined by a DCOUNTER command or by the CALL interface has a value which is too large to be correctly represented as a
  fullword signed binary value" [GET-COUNTER] [QUERY-COUNTER]. RESP2: 001 "overflowed into the high-order (sign) bit (that is, the
  value returned is negative)"; 002 "A value is too large for a fullword data area by only 1 bit. In this case, the overflow value is
  exactly 1."; 003 "too large for a fullword data area by a value greater than 1." [QUERY-COUNTER]
  * B1 DEFINE DCOUNTER 2**31 NORMAL. B2 QUERY COUNTER: 2**31 sets the sign bit: `R=22 S=001`.
  * B3 DEFINE DCOUNTER 2**32 NORMAL. B4 QUERY COUNTER: 2**32 is one bit above a fullword (overflow value exactly 1): `R=22 S=002`.
  * B5 DEFINE DCOUNTER 2**33 NORMAL. B6 QUERY COUNTER: the overflow is 2, greater than 1: `R=22 S=003`.
  * B7 GET COUNTER of the 2**32 counter: the same condition and RESP2 as B4 (`R=22 S=002`; the page gives GET and QUERY the same
    LENGERR). The counter after a failed GET is not read again (see Avoided ambiguities).
  * B8 QUERY DCOUNTER of the 2**31 counter (only QUERY COUNTER touched it): `0000000080000000`, DCOUNTER has no LENGERR.
* **`fit`** (F). A value that "can be correctly represented as a fullword signed binary value" is returned by COUNTER commands.
  * F1 DEFINE DCOUNTER 2**31 - 2 NORMAL. F2 QUERY COUNTER `000000007FFFFFFE`. F3 GET COUNTER returns `000000007FFFFFFE` (value before
    the increment [GET-COUNTER]; the counter is now 2**31 - 1). F4 QUERY COUNTER `000000007FFFFFFF`.
  * F5 GET DCOUNTER returns `000000007FFFFFFF` and the counter becomes 2**31. F6 QUERY COUNTER: now sign bit set, `R=22 S=001`.
    F7 QUERY DCOUNTER `0000000080000000`.
* **`dup`** (D). DEFINE RESP2 202 is "Duplicate counter name. A named counter of this name already exists." [DEFINE-COUNTER]; the
  condition is INVREQ.
  * D1 DEFINE DCOUNTER VALUE 5 NORMAL. D2 DEFINE COUNTER (no VALUE) of the same name: `R=16 S=202`. D3 DEFINE COUNTER VALUE(7):
    `R=16 S=202`. D4 QUERY DCOUNTER `0000000000000005`: the failed DEFINEs did not touch the existing counter.
  * D5 DEFINE COUNTER VALUE 9 NORMAL. D6 DEFINE DCOUNTER of the same name (VALUE 0): `R=16 S=202`. D7 QUERY COUNTER `0000000000000009`.
    D8 QUERY DCOUNTER `0000000000000009` (see the README lower-confidence table).

## What a correct port must do

* Keep one name table per pool for COUNTER and DCOUNTER: a DEFINE of an existing name is INVREQ 202 whichever command set made it.
* Hold the value as an unsigned 64-bit; on a COUNTER command raise LENGERR when it does not fit a signed fullword: RESP2 001 for
  2**31 .. 2**32 - 1, 002 when exactly one bit over, 003 above that; never on a DCOUNTER command.

## Avoided ambiguities

* **The value of a counter after a failed GET COUNTER (LENGERR)**: IBM does not say whether the increment is applied, so no
  scenario reads (or GETs) the counter again after B7.
* **RESP2 for values in 2**32 .. 2**33 - 1 other than exactly 2**32**, and for 2**32 - 1 (sign bit and nothing else): only the values
  at 2**31, 2**32, 2**33 are used.
* **GET COUNTER whose increment carries the counter across 2**31**: the fit scenario crosses with GET DCOUNTER.
* **Cross-set access of a small value** (F2 - F4, D7, D8): see the README lower-confidence table; IBM advises one command set per
  counter.
* **RESP2 of a completed command / VALUE of a failed command**: not stated; not logged / zeros, as in hc-dcounters.
* **Pool-server errors, BUSY, other tasks and regions**: none; each scenario is one task.

## Citations

* [DEFINE-COUNTER] CICS TS 6.x, EXEC CICS DEFINE COUNTER and DEFINE DCOUNTER (RESP2 202; "Always access a named counter using
  commands from the same command set that you used to define the counter"):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-define-counter-define-dcounter
* [GET-COUNTER] CICS TS 6.x, EXEC CICS GET COUNTER and GET DCOUNTER (LENGERR):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-counter-get-dcounter
* [QUERY-COUNTER] CICS TS 6.x, EXEC CICS QUERY COUNTER and QUERY DCOUNTER (LENGERR RESP2 001 / 002 / 003):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-query-counter-query-dcounter
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, LENGERR 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
