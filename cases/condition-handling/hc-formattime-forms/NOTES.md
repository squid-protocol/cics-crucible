# hc-formattime-forms: FORMATTIME's date forms, separators, TIME and binary forms

## The trap

`HCFMTF` (transaction `HCFT`) reads its mode from the terminal input (`HCFT D`, `HCFT T` or `HCFT L`), issues `EXEC CICS
FORMATTIME` commands and logs each result to TS queue `HCLOG` (ASKTIME and FORMATTIME are not events, SPEC 6.2). An item is 13
bytes: tag (2), a space, the value (10, padded with spaces); a binary form goes through `PIC 9(8)`, so it reads as 8 digits, zero-filled (`00046082`). The date and time areas are cleared after each result, because IBM
writes only the form's own length.

* **Mode D (`date-forms`)**, `ASKTIME ABSTIME` then ten forms: **D1** `YYYYMMDD`. **D2** `MMDDYYYY DATESEP('-')`.
  **D3** `DDMMYYYY DATESEP('.')`. **D4** `YYMMDD DATESEP` (no value). **D5** `MMDDYY`. **D6** `DDMMYY DATESEP('-')`. **D7** `YYDDD`.
  **D8** `YYYYDDD DATESEP('-')`. **D9** `YYDDMM DATESEP('.')`. **DA** `YYYYDDMM`.
* **Mode T (`time-and-numbers`)**: **T1** `TIME` (no TIMESEP). **T2** `TIMESEP('.')`. **T3** `TIMESEP` (no value). Then the
  binary forms **N1** `DAYCOUNT`, **N2** `DAYOFWEEK`, **N3** `DAYOFMONTH`, **N4** `MONTHOFYEAR`, **N5** `YEAR`, **N6** `MILLISECONDS`.
* **Mode L (`leap-year-end`)**: a fixed `ABSTIME` of 4070908799999 (31 December 2028 23:59:59.999): **L1** `MMDDYYYY DATESEP('/')`,
  **L2** `YYYYDDD`, **L3** `YYDDD DATESEP('-')`, **L4** `TIME TIMESEP(':')`, then N1 to N6 again.

## Why a naive translation breaks

* A port that treats `DATESEP` with no value like an omitted `DATESEP` (or the reverse) gets D4 and T3 wrong.
* A port with the day-of-year forms wrong around leap years gets L2 / L3 (day 366).
* A port that numbers `DAYOFWEEK` from Monday, or counts `DAYCOUNT` from 0, gets N1 / N2 wrong.
* A port that writes the whole area for a short form leaves stale bytes (the program clears the area to expose it).

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal `T001`, clock `2026-03-02T10:00:00` (a Monday, day 61 of 2026), a task takes no time,
so `ASKTIME` returns the clock.

* [FORMATTIME] "If you omit this option [DATESEP], no separator is supplied. If you omit data-value, a slash (/) is assumed";
  TIMESEP omitted: "no separator ... and 6 bytes are returned in an 8-character field"; given with no value: a colon.
* `date-forms`: `20260302`, `03-02-2026`, `02.03.2026`, `26/03/02`, `030226`, `02-03-26`, `26061`, `2026-061`, `26.02.03`, `20260203`.
* `time-and-numbers`: `100000`, `10.00.00`, `10:00:00`; DAYCOUNT 46082 (1 January 1900 is day 1); DAYOFWEEK 1 (Sunday=0); 2; 3;
  2026; 0.
* `leap-year-end`: ABSTIME 4070908799999 is 47116 whole days plus 86399999 ms after 1 January 1900 00:00. 2028 is leap, so 31
  December is day 366 and (1 January 2028 a Saturday) a Sunday. Items `12/31/2028`, `2028366`, `28-366`, `23:59:59`, DAYCOUNT 47117
  (46082 + 731 + 304), DAYOFWEEK 0, 31, 12, 2028, MILLISECONDS 999.

## What a correct port must do

* Join date parts with the `DATESEP` value, `/` when the option has no value, nothing when absent; the same for TIME with `:`.
* Count DAYCOUNT from day 1 = 1 January 1900 and DAYOFWEEK from Sunday = 0; give the day of year in the YYDDD forms.

## Avoided ambiguities

* **A negative ABSTIME** (INVREQ RESP2 1) is hc-resp-options' scenario.
* **`DATE`, `DATEFORM`, `FULLDATE`, `DATESTRING`**: depend on the installation's DATFORM or a zone; not used.
* **Where the unwritten bytes of an area land** for a form shorter than its area: the program clears the area after each result.
* **`ASKTIME` without a clock tick**: the harness clock is fixed, so MILLISECONDS is 0 in mode T.
* **Short fields**: every area is at least as wide as the widest output it receives.

## Citations

* [FORMATTIME] IBM CICS TS 6.x, EXEC CICS FORMATTIME (forms, DATESEP, TIMESEP, DAYCOUNT, DAYOFWEEK "Sunday=0, Saturday=6",
  MILLISECONDS 0 - 999): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-formattime
* [ASKTIME] IBM CICS TS 6.x, EXEC CICS ASKTIME: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-asktime
