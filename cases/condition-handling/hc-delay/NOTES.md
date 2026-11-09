# hc-delay: DELAY with RESP, every valid form

## The trap

`HCDLAY` (transaction `HC93`) issues six `EXEC CICS DELAY ... RESP(..)` commands and logs each RESP to TS queue `HCLOG`
(DELAY is not an event, SPEC 6.2). Item format: tag (2), ` R=`, RESP (2): 7 bytes.

* **D1** no options. **D2** `INTERVAL(0)` (packed decimal). **D3** `INTERVAL(0000002)` (hhmmss, two seconds).
* **D4** `FOR SECONDS(90)`: SECONDS alone may exceed 59. **D5** `FOR MINUTES(75)`: MINUTES alone may exceed 59.
* **D6** `FOR HOURS(1) MINUTES(2) SECONDS(3)`.

## Why a naive translation breaks

* A port that range-checks SECONDS or MINUTES against 0-59 whatever else is given raises INVREQ for D4 / D5, which IBM
  accepts.
* A port that rejects a zero interval, or an omitted interval, fails D1 / D2.
* A port that treats `FOR` as `INTERVAL` reads the wrong fields.

## Expected behaviour

* [DELAY] With no option the default is `INTERVAL(0)`. `MINUTES` is "in the range 0-59, when HOURS, SECONDS or MILLISECS
  are also specified, or 0-5999 when MINUTES is the only option specified"; `SECONDS` is 0-59 with others, "0-359 999"
  alone. So D4 (90 s alone) and D5 (75 min alone) are in range; D6 gives every unit its narrow range. D3's `mm` and `ss`
  are 00. Every command is in range, so RESP is NORMAL (0): all six items read `R=00`.
* The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Accept every form above with RESP NORMAL, in order, then write the six items to `HCLOG`, send `DONE OK` and RETURN.
* Not advance any clock the program can read, and not suspend past the scenario.

## Avoided ambiguities

* **EXPIRED** (RESP 31, "if the time has already expired when the command is issued"; "intervals under 250 ms may already
  have lapsed"): no scenario depends on elapsed time; D2 / D3 are read for NORMAL as IBM's page lists NORMAL for a
  delay that ran its interval, and the case treats a zero or short interval as not expired (the harness's tasks take
  zero time, SPEC 4).
* **The virtual clock** does not move across a DELAY (SPEC 4): nothing reads EIBTIME / ASKTIME.
* **RESP2** is never read (IBM lists RESP2 23 under NORMAL only for a cancelled delay).
* **Out-of-range values** (INVREQ RESP2 4 hours, 5 minutes, 6 seconds, 22 milliseconds) and `TIME` / `UNTIL`: not used.
* **MILLISECS** (below 50 ms "treated as expired immediately"): not used.

## Citations

* [DELAY] CICS TS 6.x, EXEC CICS DELAY (INTERVAL, FOR, HOURS, MINUTES, SECONDS ranges; default INTERVAL(0); conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delay
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
