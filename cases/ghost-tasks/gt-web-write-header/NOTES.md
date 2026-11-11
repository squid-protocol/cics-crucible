# gt-web-write-header: server WEB WRITE HTTPHEADER with a zero or negative NAMELENGTH / VALUELENGTH

The failure sibling of `gt-web-server-send`, which shows `WEB WRITE HTTPHEADER` only on its NORMAL path. Peer model and request keys as
`gt-http-inbound` (SPEC sections 2, 4, 5 and 6).

## The trap

`GTWWHL` is the program of SERVER URIMAP `WHURI` (`HOST(*) PATH(/gt/wh)`, alias transaction `GT90`). It `WEB READ HTTPHEADER`s
`X-Crucible-Mode` and then issues one `WEB WRITE HTTPHEADER` of `X-Crucible-Note: ok` whose lengths the mode sets. On a non-NORMAL RESP it
writes `M<mode> R=<RESP> E=<RESP2>` to TS queue `GTWHLOG`. It always answers `WEB SEND FROM('done')`, status 200.

One scenario, **`send`** (`client-a`), five `GET`s at 10:00:00, :05, :10, :15 and :20:

| Request | Mode | NAMELENGTH | VALUELENGTH | `WEB WRITE HTTPHEADER` | Header in the delivered response |
|---|---|---|---|---|---|
| 0 | `1` | 15 | 2 | NORMAL | `X-Crucible-Note: ok` |
| 1 | `2` | 0 | 2 | LENGERR RESP2 35 | none |
| 2 | `3` | -1 | 2 | LENGERR RESP2 35 | none |
| 3 | `4` | 15 | 0 | LENGERR RESP2 55 | none |
| 4 | `5` | 15 | -1 | LENGERR RESP2 55 | none |

## Why a naive translation breaks

* Writing the header anyway (a Java port that appends the name and value whatever the lengths): the failed writes must add nothing, so
  the four failing responses carry no header.
* Treating a non-positive length as "use the whole area" or as an empty header name / value: IBM makes it an error, not a default.
* Mixing the two checks: a bad name length is RESP2 35, a bad value length RESP2 55; both are LENGERR (condition 22).
* Abending: the conditions come back to the program (RESP given), which logs them and still sends its answer.

## Expected behaviour

Model: as `gt-http-inbound`: clock 2026-03-02T10:00:00, a task takes no time, each request starts its own `GT90` task with no terminal and
no EIBAID, a `GET` has no body and the program issues no `WEB RECEIVE`.

* **Mode 1:** NORMAL; the header is a header of the response ("When CICS is an HTTP server, the message is a response to a Web client"
  [WEBWHDR]); the peer's response states it.
* **Modes 2 and 3:** LENGERR, RESP2 35: "The length in NAMELENGTH is not greater than zero." [WEBWHDR] (0 and -1 are both "not greater than
  zero"). Log item `M2 R=22 E=0035` and `M3 R=22 E=0035` (LENGERR is condition 22 [WEBWHDR]).
* **Modes 4 and 5:** LENGERR, RESP2 55: "The length in VALUELENGTH is not greater than zero or greater than 32000." [WEBWHDR]. Log items
  `M4 R=22 E=0055` and `M5 R=22 E=0055`.
* **Events.** A failed `WEB-WRITE-HTTPHEADER` event names the header area and the value area the program passed (`X-Crucible-Note`,
  `ok`), with `resp` LENGERR and `resp2`; the lengths are not events. A failed write is not a header of the response: the validator
  counts only NORMAL writes against the peer's `headers`, so responses 1-4 state none.
* **TS queue** `GTWHLOG`: items 1-4 are written by the four failing tasks, in order.

## What a correct port must do

* Return LENGERR RESP2 35 for a `NAMELENGTH` and RESP2 55 for a `VALUELENGTH` that is zero or negative, and add no header to the response.
* Leave the task running so a later `WEB SEND` is the response.

## Avoided ambiguities

* **A `VALUELENGTH` above 32000** (also RESP2 55 [WEBWHDR]): not used; the event's `value` would have to be a 32001-byte string. Sibling gap.
* **Which check comes first** when both lengths are bad: IBM states no order, so no request breaks both.
* **Header not allowed** (INVREQ RESP2 19 [WEBWHDR]): the page says that where CICS as a server creates a header (Content-Type, Content-Length,
  Date, Server ...) and the header suits a response "CICS does not overwrite" the application's; the case avoids all CICS-generated names.
* **Two writes of one name:** IBM adds a second header "in addition to the existing header"; the peer's `headers` is a name-to-value map and
  cannot state two, so no scenario writes a name twice.
* **Content of a failed event's name / value:** IBM says nothing about what a rejected write leaves; the event records the program's areas
  (a case-stated reading, README lower-confidence table).
* **RESP2 after a NORMAL write** is not asserted. **Code page:** the header is plain ASCII alphanumerics and hyphens. **ACTION:** the send
  says `ACTION(DFHVALUE(IMMEDIATE))`, and the header write precedes it.

## Citations

* [WEBWHDR] IBM CICS TS 6.x, EXEC CICS WEB WRITE HTTPHEADER: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-write-httpheader
  (Conditions INVREQ, LENGERR, NOTOPEN; 22 LENGERR RESP2 35 and 55 quoted above; NAMELENGTH, VALUELENGTH "fullword binary value"; read 2026-11-11).
* [WEBSEND] IBM CICS TS 6.x, EXEC CICS WEB SEND (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-send-server
  (FROM, FROMLENGTH, MEDIATYPE, STATUSCODE, STATUSTEXT, STATUSLEN, ACTION).
* [WEBRHDR] IBM CICS TS 6.x, EXEC CICS WEB READ HTTPHEADER: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-read-httpheader
* [URIMAP]: as `gt-http-inbound`.
