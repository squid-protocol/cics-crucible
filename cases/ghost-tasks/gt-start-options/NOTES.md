# gt-start-options: the START options gt-start-retrieve leaves out

## The trap

`GTOPTS` (transaction `GT21`) starts background tasks with `EXEC CICS START`, using the options
that [gt-start-retrieve](../gt-start-retrieve) does not: the data options `RTRANSID`, `RTERMID`
and `QUEUE`, `AFTER` / `AT` with `HOURS` / `MINUTES` / `SECONDS`, a `TIME` past 23 hours, and a
`REQID` used twice; and it attaches a child task with `RUN TRANSID`. Two started transactions read
what they were given:

* `GT22` (`GTREAD`) issues one `RETRIEVE INTO LENGTH RTRANSID RTERMID QUEUE` and logs the response
  and the values to TS queue `GTLOG`.
* `GT23` (`GTRTRN`) issues `RETRIEVE RTRANSID` with no `INTO` until the response is not NORMAL,
  and logs each response to `GTLOG`.
* `GT24` (`GTCHLD`), the RUN TRANSID child, logs `CHILD RAN` to `GTLOG`.

GTOPTS logs the RESP / RESP2 of the STARTs whose outcome is the point (modes V and I) to its own
queue `GTSLOG`. The mode letter typed after the transaction id picks the START(s):

| Mode | START(s) | Point |
|---|---|---|
| D | GT22 `INTERVAL(0) FROM LENGTH(20) RTRANSID('GT21') RTERMID('T001') QUEUE('GTQUEUE1')` | RETRIEVE returns the data and all three values |
| E | GT22 `INTERVAL(0) FROM LENGTH(20)` | GT22's RETRIEVE names options the START did not give: ENVDEFERR |
| N | GT23 `INTERVAL(0) RTRANSID('GT21')`, no FROM | still a data record; RETRIEVE with no INTO gets it, then ENDDATA |
| A | GT23 `AFTER MINUTES(1)`, `AFTER HOURS(0) MINUTES(0) SECONDS(30)`, `AT HOURS(10) MINUTES(45)`, `TIME(250000)`, at 10:00:00 | AFTER is an interval, AT a time of day; 25 hours is 01:00 tomorrow |
| V | GT23 `INTERVAL(70)`, `AFTER HOURS(1) MINUTES(60)`, `AFTER SECONDS(360000)`, `AFTER HOURS(100)` | INVREQ with RESP2 6, 5, 6, 4; nothing starts |
| I | GT23 `INTERVAL(30) REQID('GTR00001') FROM ... RTRANSID('REQ1')`, then the same REQID with FROM again | the second START is IOERR; only the first runs |
| U | `RUN TRANSID('GT24') CHILD(WS-CHILD)`, then `RUN TRANSID('GTZZ')` (not defined) | the child task runs; the second RUN is TRANSIDERR RESP2 1 |

## Why a naive translation breaks

* A port that passes START data as one payload object loses the data options, or cannot tell
  "no RTRANSID was given" from "a blank one was": RETRIEVE must raise ENVDEFERR for an option the
  START did not specify, and must still find a data record for a START that gave RTRANSID but no
  FROM.
* `AFTER` / `AT` are not `INTERVAL` / `TIME` spelled differently: one option alone takes a wider
  range (MINUTES up to 5999, SECONDS up to 359999) than the same option combined with another
  (0 - 59). A port that range-checks them like INTERVAL's `hhmmss` rejects `AFTER MINUTES(90)`
  or accepts `AFTER HOURS(1) MINUTES(60)`.
* An hours component above 23 is not invalid: it is a time on a later day. A port that builds a
  `LocalTime` from it throws.
* A port that keys pending requests by REQID in a map silently replaces the first request when
  the same REQID is used again with FROM; CICS raises IOERR and keeps the first.
* INVREQ's RESP2 says which value was out of range; a port that only sets RESP loses it.
* A port that runs a RUN TRANSID child inline, as a method call, makes the parent wait for it
  and lets a failing child fail the parent; a port that drops the child unless FETCHed loses it.

## Expected behaviour

Model (SPEC section 4): a request expires at issue time + INTERVAL / AFTER, or at TIME / AT. A
non-terminal request is dispatched once it has expired and its issuing task has ended. Every
scenario starts at 10:00:00 with `GT21 <mode>` typed on T001. GTOPTS RECEIVEs the 6 bytes, issues
its START(s), sends `STARTS ISSUED` and RETURNs.

* **`data-options`** (D): the START gives FROM (`ORDER 0021 READY`, 20 bytes), RTRANSID `GT21`,
  RTERMID `T001` and QUEUE `GTQUEUE1`; it expires at once [START]. GT22 runs with no terminal.
  Its RETRIEVE gets the data (NORMAL, LENGTH 20) and "a 4-character area that can be used in
  the TRANSID option" (RTRANSID), the same for TERMID (RTERMID), and "the 8-character area for
  the temporary storage queue name" (QUEUE) [RETRIEVE]. GTLOG: `R=00 L=0020 T=GT21 M=T001
  Q=GTQUEUE1 D=ORDER 0021 READY`.
* **`envdeferr`** (E): the START gives FROM only. GT22's RETRIEVE names RTRANSID, RTERMID and
  QUEUE too: "ENVDEFERR occurs when a RETRIEVE command specifies an option not specified by the
  corresponding START command" [RETRIEVE]. DFHRESP(ENVDEFERR) = 56 [RESP-CODES]. RESP is given,
  so no abend. GTREAD logs only the response (`R=56`, the rest blank): it reads none of the
  areas after a response other than NORMAL / LENGERR.
* **`no-into`** (N): the START gives RTRANSID and no FROM. A data record is stored all the same:
  RETRIEVE's ENDDATA covers a START "that did not specify any of the data options FROM, RTRANSID,
  RTERMID, or QUEUE" [RETRIEVE], which this one did. GT23's `RETRIEVE RTRANSID` (no INTO, so no
  LENGTH is set and no data is moved) returns `GT21`; its second RETRIEVE is ENDDATA: "Tasks
  without terminals access only a single data record" [RETRIEVE]. GTLOG: `R=00 T=GT21`,
  `R=29 T=`.
* **`after-at`** (A): AFTER "Specifies the interval of time that is to elapse before the new task
  is started", given as "A combination of at least two of HOURS(0 - 99), MINUTES(0 - 59), and
  SECONDS(0 - 59)" or "one of HOURS(0 - 99), MINUTES(0 - 5999), or SECONDS(0 - 359999)"; AT
  "Specifies the time at which the new task is to be started", the same ways [START]. So:
  * `AFTER MINUTES(1)` expires at 10:01:00 (recorded as the interval it amounts to, `000100`);
  * `AFTER HOURS(0) MINUTES(0) SECONDS(30)` at 10:00:30 (`000030`);
  * `AT HOURS(10) MINUTES(45)` at 10:45:00 (recorded as the time, `104500`);
  * `TIME(250000)`: "If you specify a time with an hours component that is greater than 23, you
    are specifying a time on a day following the current one" [EXPIRATION]: 01:00 on 3 March,
    after `until` (one hour), so its task never runs here.

  The three tasks run in expiry order (SPEC 4): AFT2 at 10:00:30, AFT1 at 10:01:00, AT01 at
  10:45:00, each logging its RTRANSID and then ENDDATA. GTLOG holds six items in that order.
* **`invreq-resp2`** (V): INVREQ (16) with RESP2 4 when "The value specified in HOURS, for AFTER
  or AT options, or the hh value that is specified for INTERVAL, is out of range", 5 for MINUTES /
  mm, 6 for SECONDS / ss [START]:
  * `INTERVAL(70)` is hh 00, mm 00, ss 70: "The mm and ss are each in the range 0 - 59" → RESP2 6;
  * `AFTER HOURS(1) MINUTES(60)`: combined, MINUTES is 0 - 59 → RESP2 5;
  * `AFTER SECONDS(360000)`: alone, SECONDS is 0 - 359999 → RESP2 6;
  * `AFTER HOURS(100)`: HOURS is 0 - 99 → RESP2 4.

  Each START names only one value out of range, so which of several would be reported never
  arises. No request is created. GTSLOG: `S=16/06`, `S=16/05`, `S=16/06`, `S=16/04`. An AFTER out
  of range amounts to no interval, so its event's `interval` is null (SPEC 6.2).
* **`reqid-ioerr`** (I): the first START (REQID `GTR00001`, FROM `ORDER 0021 READY`, RTRANSID
  `REQ1`, INTERVAL(30)) is NORMAL and expires at 10:00:30. Its data is "stored in a TS queue by
  using the REQID name specified ... as the identifier" [START]. The second START uses the same
  REQID with FROM while that request is pending: IOERR, "A START operation uses a REQID name that
  exists. This condition occurs only when the FROM option is also used" [START]. DFHRESP(IOERR)
  = 17. GTOPTS gives no RESP2 option on these STARTs (IBM documents no RESP2 for this IOERR), so
  WS-RESP2 keeps its VALUE 0. GTSLOG: `S=00/00`, `S=17/00`. At 10:00:30 GT23 RETRIEVEs `REQ1`,
  then ENDDATA.

* **`run-transid`** (U): `RUN TRANSID` "starts a task on the local system ... The started task
  (child task) runs asynchronously with the starting task (parent task)"; CICS places "the child
  token that represents the child task" in the 16-character CHILD area [RUN]. RESP NORMAL; GTSLOG
  `S=00/00`. `RUN TRANSID('GTZZ')`: GTZZ is not defined, TRANSIDERR (28) with RESP2 1 [RUN];
  GTSLOG `S=28/01`. The GT24 child runs with no terminal and EIBCALEN 0 and logs `CHILD RAN` to
  GTLOG. It is recorded after GT21 (SPEC 4: a RUN child is dispatched like a request that expires
  when the RUN is issued); nothing observable depends on that order (below).

## What a correct port must do

* Keep each START's data record as FROM data plus the RTRANSID / RTERMID / QUEUE values, each
  present or absent, and create a record when any of them is given.
* RETRIEVE: ENDDATA when no record is left; ENVDEFERR for an option the START did not give;
  otherwise the values asked for, and the data only with INTO.
* Turn AFTER / AT into an expiry with their own range rules, and INVREQ's RESP2 per value; read
  TIME / AT hours above 23 as a later day.
* Raise IOERR for a START with FROM whose REQID names a request that still holds data.
* Attach a RUN TRANSID child without waiting for it, and raise TRANSIDERR for an undefined one.

## Avoided ambiguities

* **Concurrency.** GTOPTS writes only GTSLOG; the started tasks write only GTLOG, and in each
  scenario they run alone or at different times (10:00:30 / 10:01:00 / 10:45:00), so real CICS
  multitasking cannot reorder an observable write.
* **After ENVDEFERR** IBM does not say whether the data areas are written or whether the record
  is used up: GTREAD reads no area after it and issues no further RETRIEVE.
* **RETRIEVE INTO for a record whose START had no FROM** (only RTRANSID / RTERMID / QUEUE): IBM
  does not say whether that is ENVDEFERR. Mode N's GT23 does not name INTO, and mode E's START has
  FROM.
* **Several values out of range on one START**: which RESP2 is reported is not documented; each
  START in mode V has exactly one value out of range.
* **RESP2 of the IOERR**: not documented, so not requested.
* **REQID reuse without FROM**, or of a request another task issued: IOERR "occurs only when the
  FROM option is also used" leaves these open; mode I reuses its own REQID, with FROM both times.
* **TIME(250000)'s task** expires after `until`, so whether anything else happens overnight is
  not observed.
* **The RUN child against its parent.** The child runs concurrently with GT21 in real CICS: GT21
  writes only GTSLOG and the child only GTLOG, and GT21 never FETCHes it. The child token's bytes
  are not documented beyond its length; GTOPTS never reads WS-CHILD.
* No START here names TERMID, so no terminal coalescing (gt-terminal-coalesce covers it).

## Citations

* [START] CICS TS 6.x, EXEC CICS START (AFTER, AT, HOURS / MINUTES / SECONDS ranges, INTERVAL, TIME, FROM, REQID, QUEUE, RTRANSID, RTERMID; conditions INVREQ RESP2 4 / 5 / 6, IOERR): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RETRIEVE] CICS TS 6.x, EXEC CICS RETRIEVE (INTO, LENGTH, RTRANSID, RTERMID, QUEUE; ENDDATA, ENVDEFERR; "Tasks without terminals access only a single data record"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-retrieve
* [EXPIRATION] CICS TS 6.x, Expiration times (hours greater than 23; the six-hour rule): https://www.ibm.com/docs/en/cics-ts/6.x?topic=control-expiration-times
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ = 16, IOERR = 17, ENDDATA = 29, ENVDEFERR = 56): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [RUN] CICS TS 6.x, EXEC CICS RUN TRANSID (the child task, CHILD; TRANSIDERR RESP2 1): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-run-transid
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
