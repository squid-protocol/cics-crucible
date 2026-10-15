# hc-counter-increment-wrap: GET DCOUNTER INCREMENT, WRAP at the default maximum, and a GET at the limit without WRAP (SUPPRESSED, RESP2 101)

Follows [`hc-dcounters`](../hc-dcounters) (the DCOUNTER lane, hex values) and [`hc-named-counters`](../hc-named-counters); this case
adds the increment and the limit.

## The trap

`HCCWRP` (transaction `HC73`) is typed with a mode after `HC73` and logs each command to TS queue `HCLOG` (the named-counter
commands are not events, SPEC 6.2). Item format, 33 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` V=`, the 8-byte value as 16
hex digits. RESP2 is logged only for a failed command; the value only for a GET or QUERY that completed (zeros otherwise). The
value areas are `PIC X(8)`, so a value near 2**64 - 1 can be set and read byte for byte. Pool `HCPOOL`, counter `HCWRP1`.

* **I**: `DEFINE DCOUNTER VALUE(10)`; GET INCREMENT(5), GET INCREMENT(5), QUERY, GET (default increment), QUERY.
* **W**: defined at the default maximum minus 2; three GETs take it to the maximum; `GET ... WRAP`; QUERY; GET.
* **L**: defined at the default maximum minus 1; two GETs take it to the maximum; GET without WRAP, GET INCREMENT(5) without WRAP;
  `GET ... WRAP`; GET.

## Why a naive translation breaks

* A port that ignores INCREMENT steps by 1 (I2-I4 differ).
* A port with a 64-bit signed or 32-bit counter overflows or goes negative near the maximum (W2-W4, L2-L3).
* A port that lets the counter run past the maximum (or wraps silently without the WRAP option) logs `R=00` at L4-L6 where IBM
  returns SUPPRESSED.
* A port that answers the limit with INVREQ, LENGERR or NOTFND logs a different RESP.
* A port that lets the failed GETs of L4-L6 change the counter shows it in L7 / L8.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; the region starts with no named counters; each scenario starts at 10:00:00
on 2026-03-02 with `HC73 <mode>` typed on T001. SUPPRESSED is RESP 72 [RESP-CODES]. The default maximum of a DCOUNTER is "a
doubleword filled with X'FF'" and the default minimum is zero [DEFINE-COUNTER].

* **`incr`** (I): INCREMENT is "an increment by which the named counter is to be updated, instead of the default value of 1"; the
  GET returns the number "assigned before the increment is applied" [GET-COUNTER].
  * I1 DEFINE VALUE(10): NORMAL. I2 GET INCREMENT(5): `000000000000000A`. I3 GET INCREMENT(5): `000000000000000F` (15).
    I4 QUERY: `0000000000000014` (20). I5 GET (default increment 1): `0000000000000014`. I6 QUERY: `0000000000000015` (21).
* **`wrap`** (W): "If you omit the WRAP option, and the counter-at-limit condition is reached, CICS returns SUPPRESSED, RESP2=101";
  WRAP rewinds the counter "if it is in a counter-at-limit condition" and "resets the current value of the named counter equal to the
  minimum value defined for the counter" [GET-COUNTER].
  * W1 DEFINE VALUE X'FFFFFFFFFFFFFFFD': NORMAL. W2 GET `FFFFFFFFFFFFFFFD`, W3 GET `FFFFFFFFFFFFFFFE`, W4 GET `FFFFFFFFFFFFFFFF`
    (the maximum is assigned: the counter is now at its limit, "The maximum value for the named counter has already been assigned").
  * W5 GET WRAP: NORMAL, returns `0000000000000000` (the counter was rewound to the minimum, 0, and that number assigned; see
    the README lower-confidence table). W6 QUERY `0000000000000001`. W7 GET `0000000000000001`.
* **`limit`** (L): "the request fails with the counter-at-limit error (SUPPRESSED, RESP2=101), but the current number is not
  changed" [GET-COUNTER].
  * L1 DEFINE VALUE X'FFFFFFFFFFFFFFFE': NORMAL. L2 GET `FFFFFFFFFFFFFFFE`, L3 GET `FFFFFFFFFFFFFFFF` (maximum assigned).
  * L4 GET, L5 GET and L6 GET INCREMENT(5), all without WRAP: `R=72 S=101`, value area not written (the program logs zeros).
  * L7 GET WRAP: NORMAL, `0000000000000000`. L8 GET: `0000000000000001`. The failed GETs left the counter at its limit and
    unchanged: the first WRAP rewinds to the minimum, not to a value shifted by L4-L6.

## What a correct port must do

* Return the value before the increment and advance by INCREMENT (default 1); hold DCOUNTER values as unsigned 64-bit.
* At the counter-at-limit condition, a GET without WRAP is SUPPRESSED (RESP 72), RESP2 101, and leaves the counter unchanged.
* A GET with WRAP at the limit rewinds the counter to its minimum.

## Avoided ambiguities

* **MINIMUM / MAXIMUM** (own limits), **REDUCE, REWIND, COMPAREMIN / COMPAREMAX** (SUPPRESSED RESP2 103), **NOSUSPEND**,
  **INCREMENT larger than the range** (INVREQ 406): not used. Every limit is the default one.
* **QUERY at the limit** (the value of a counter-at-limit): not logged; IBM's wording is not a single sentence.
* **A GET whose INCREMENT would step past the maximum while not yet at the limit**: no scenario does that; L6 is issued only
  after the limit is reached.
* **RESP2 of a completed command / VALUE of a failed GET**: not stated; not logged / zeros, as in hc-dcounters.
* **Pool-server errors, BUSY, other tasks and regions**: none; each scenario is one task.

## Citations

* [DEFINE-COUNTER] CICS TS 6.x, EXEC CICS DEFINE COUNTER and DEFINE DCOUNTER (VALUE, default minimum / maximum):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-define-counter-define-dcounter
* [GET-COUNTER] CICS TS 6.x, EXEC CICS GET COUNTER and GET DCOUNTER (INCREMENT, WRAP, SUPPRESSED RESP2 101):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-counter-get-dcounter
* [QUERY-COUNTER] CICS TS 6.x, EXEC CICS QUERY COUNTER and QUERY DCOUNTER (VALUE):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-query-counter-query-dcounter
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (SUPPRESSED 72):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
