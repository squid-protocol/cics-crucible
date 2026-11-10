# hc-delay-range: DELAY with a value out of IBM's range is INVREQ, and the top of each range is NORMAL

## The trap

`HCDLRG` (transaction `HCDR`) reads its mode from the terminal input (`HCDR B` or `HCDR G`), issues `EXEC CICS DELAY`
commands with `RESP` / `RESP2`, and logs the result of each to TS queue `HCLOG` (DELAY is not an event, SPEC 6.2).

* **Mode B (`out-of-range`)**, eight commands, each with ONE value out of range; item format: tag (2), ` R=`, RESP (2),
  ` 2=`, RESP2 (2): 12 bytes.
  * **B1** `FOR HOURS(100)`. **B2** `FOR HOURS(1) MINUTES(60)`. **B3** `FOR MINUTES(1) SECONDS(60)`.
  * **B4** `FOR SECONDS(1) MILLISECS(1000)`. **B5** `INTERVAL(006000)` (mm = 60). **B6** `INTERVAL(000060)` (ss = 60).
  * **B7** `FOR MINUTES(6000)` alone. **B8** `FOR SECONDS(360000)` alone.
* **Mode G (`top-of-range`)**, seven commands, each at the top of its range; item format: tag (2), ` R=`, RESP (2): 7 bytes.
  * **G1** `HOURS(99)`. **G2** `HOURS(1) MINUTES(59)`. **G3** `MINUTES(1) SECONDS(59)`. **G4** `SECONDS(1) MILLISECS(999)`.
  * **G5** `INTERVAL(005959)`. **G6** `MINUTES(5999)` alone. **G7** `SECONDS(359999)` alone.

## Why a naive translation breaks

* A port that never range-checks answers NORMAL for every B command and the delay "runs".
* A port that checks MINUTES / SECONDS against 0-59 whatever else is given refuses G6 / G7 (and B7 / B8 for the wrong reason
  at the wrong bound: 60 alone is valid).
* A port that checks HOURS against 0-23 refuses G1.
* A port that reports one RESP2 for every out-of-range value (say 4) gets B2 to B8 wrong.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal `T001`, clock `2026-03-02T10:00:00`; a task takes no time.

* [DELAY] INVREQ (condition 16) with RESP2 4 "hours out of range", 5 "minutes out of range", 6 "seconds out of range", 22
  "milliseconds out of range". `HOURS` is 0-99. `MINUTES` is "in the range 0-59, when HOURS, SECONDS or MILLISECS are also
  specified, or 0-5999 when MINUTES is the only option specified"; `SECONDS` is 0-59 with the others, 0-359999 alone;
  `MILLISECS` is 0-999 with the others. For `INTERVAL(hhmmss)` "mm and ss are in the range 0-59".
* **`out-of-range`**: B1 RESP2 4; B2 RESP2 5 (60 minutes with HOURS); B3 RESP2 6 (60 seconds with MINUTES); B4 RESP2 22 (1000 ms
  with SECONDS); B5 RESP2 5 (mm 60); B6 RESP2 6 (ss 60); B7 RESP2 5 (6000 minutes alone is past 5999); B8 RESP2 6 (360000 seconds alone
  is past 359999). All RESP 16 (INVREQ), so the items read `B1 R=16 2=04` ... `B8 R=16 2=06`; the task goes on after each (RESP is
  specified, so the task is not abended), sends `DONE OK` and RETURNs.
* **`top-of-range`**: every command is in range, so RESP is NORMAL: seven items `G1 R=00` ... `G7 R=00`. (A DELAY that runs to
  its interval is NORMAL; the harness's tasks take no time, SPEC 4.)

## What a correct port must do

* Check each value against the range its sibling options select (alone or with others), answer INVREQ with the RESP2 of the
  option that is out of range, not perform the delay, and let the task go on.
* Accept the top of every range as NORMAL, in particular HOURS above 23 and MINUTES / SECONDS above 59 when alone.

## Avoided ambiguities

* **More than one value out of range in one command:** IBM gives no order for the RESP2, so every B command has exactly one.
* **An `INTERVAL` hours part above 99** and a negative interval: IBM gives no range; not used.
* **RESP2 on NORMAL** is not read (IBM lists RESP2 23 under NORMAL only for a cancelled delay); mode G logs RESP only.
* **EXPIRED** (RESP 31) and elapsed time: no scenario reads a clock; MILLISECS is used only at 999 / 1000 beside SECONDS(1).
* **`MILLISECS` alone** (0-359999999): not used.
* **Whether a real region would wait 99 hours** in G1: the harness's tasks take no time (SPEC 4) and the case reads no clock.

## Citations

* [DELAY] IBM CICS TS 6.x, EXEC CICS DELAY (INTERVAL, FOR, HOURS, MINUTES, SECONDS, MILLISECS ranges; INVREQ RESP2 4, 5, 6, 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delay
* [RESP-CODES] IBM CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0, INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
