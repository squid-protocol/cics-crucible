# gt-web-server-send: server WEB WRITE HTTPHEADER and WEB SEND (FROM, MEDIATYPE, STATUSCODE / STATUSTEXT, ACTION IMMEDIATE), and a second WEB SEND

Fourth step of the HTTP family (gitgalaxy#4767 C4), on the peer model of `gt-http-inbound` and the request keys of
`gt-web-server-receive` (SPEC sections 2, 4, 5 and 6). The response the program builds is what the stated client peer
receives, so the status line, the media type, the body and the written header are all observable.

## The trap

`GTWSEND` is the program of SERVER URIMAP `SENDURI` (`HOST(*) PATH(/gt/send)`, alias transaction `GT83`). For each request it
`WEB READ HTTPHEADER`s `X-Crucible-Code` (the status to answer with), `WEB EXTRACT`s the query string (the response body, 20
bytes), `WEB WRITE HTTPHEADER`s `X-Crucible-Reply: reply-<code>` and `WEB SEND`s the body with `STATUSCODE`, `STATUSTEXT` /
`STATUSLEN`, `MEDIATYPE` (a 56-byte area) and `ACTION(IMMEDIATE)`. The reason phrase and media type come from the code in the
program: 200 `OK` `text/plain`, 201 `Created` `application/json`, 404 `Not Found` `text/plain`. A request that also carries
`X-Crucible-Again` makes the program issue a second `WEB SEND` in the same task.

Two scenarios:

* **`send`** (`client-a`): three `GET`s at 10:00:00, :05 and :10, codes 200, 201 and 404, queries `item=42`, `id=7`, `gone=9`.
* **`second`** (`client-b`): one `GET` with code 200, query `k=1` and `X-Crucible-Again: Y`.

## Why a naive translation breaks

* Sending the default status for every response: STATUSCODE is what the program gives; 201 and 404 reach the peer, with their own
  reason phrases (STATUSTEXT / STATUSLEN) and their own media type.
* Sending the body with the wrong length or the wrong media type: FROMLENGTH is 20 (the query padded with blanks) and MEDIATYPE
  is the type, not the 56-byte area.
* Dropping `WEB WRITE HTTPHEADER` (the header is part of the response) or writing it per task, not per response: each response
  carries `X-Crucible-Reply` with its own request's code.
* Delivering the second `WEB SEND` to the peer, or letting it overwrite the first: with the first response IMMEDIATE the second
  is an error and reaches no one (the peer already has the first). A port that treats it as EVENTUAL (second overwrites first)
  is wrong here.

## Expected behaviour

Model: as `gt-http-inbound`: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time, and each request starts
its own `GT83` task with no terminal and no EIBAID. A `GET` has no body and the program issues no `WEB RECEIVE`.

* **`send`**. Each task: `WEB READ HTTPHEADER` of a header the request carries is NORMAL [WEBRHDR]; the NORMAL `WEB WRITE HTTPHEADER`
  is a header of the response: "When CICS is an HTTP server, the message is a response to a Web client" [WEBWHDR], and the header
  is not one CICS writes itself, so it is sent as given. `WEB SEND` is NORMAL: STATUSCODE "a halfword binary value", STATUSTEXT
  "the reason phrase" with STATUSLEN its length, MEDIATYPE a media type in a 56-byte area, FROM / FROMLENGTH the body [WEBSEND].
  The delivered response is status 200 / 201 / 404, the matching text and media type, the body and the one written header, which
  the peer's stated response (`peers.client-a`) repeats.
* **`second`**. The first `WEB SEND` is NORMAL and is delivered. The second is INVREQ: "If the IMMEDIATE option was used for the
  first response, an error is returned when you attempt the second response" [WEBSEND, ACTION]. It is a `WEB-SEND` event with
  `resp` INVREQ and no `resp2`, and it is not delivered; the peer's one response is the first. The program carries on (RESP is
  given) and RETURNs.

The peer scripts are in `case.json` (`peers`); the validator checks the delivered `WEB-SEND` and the headers written before it
against them. Logs: `expected/*.json`.

## What a correct port must do

* Deliver a server task's `WEB SEND` (status, reason phrase, media type, body) and the headers it wrote with `WEB WRITE HTTPHEADER`
  to the request's client, as one response.
* With the first response IMMEDIATE, fail a second `WEB SEND` in the task (INVREQ) and send nothing more.

## Avoided ambiguities

* **The condition of the second send.** IBM states that "an error is returned" but not the condition or RESP2 (RESP2 75, "Invalid
  send sequence", is listed on the page and not tied to this case). The log says INVREQ and states no RESP2; this reading is in
  the README's lower-confidence table. Nothing else in the case depends on it: the program does not branch on the second RESP.
* **EVENTUAL.** A second send after an EVENTUAL first one overwrites the first, and a send's effect then depends on the end of
  task: not used. Every send says `ACTION(IMMEDIATE)`.
* **A status code that allows no body** (204, 205, 304: INVREQ RESP2 72 [WEBSEND]): a failed first send leaves it unstated whether
  a following send is the first or the second response, so no scenario sends a body with such a code. Not used.
* **DOCUMENT** (`WEB SEND DOCUMENT`): excluded; every send is `FROM`.
* **Lengths written back** by `WEB READ HTTPHEADER` (VALUELENGTH) and `WEB EXTRACT` (QUERYSTRLEN): not logged and not used; the
  reason phrase length is set by the program. A leading `?` of QUERYSTRING is dropped if present (as `gt-web-server-receive`).
* **Header spelling and the headers CICS adds** (Date, Server, Content-Length, Content-Type): not modelled; only the header the
  program writes is compared. **Header name case:** the exact spelling is read and written. **No headers** on a request would be
  INVREQ RESP2 43 [WEBRHDR]: every request states `X-Crucible-Code`, and `X-Crucible-Again` is absent from most (NOTFND RESP2 1,
  which the program treats as "no").
* **Code page.** As `gt-http-inbound`: SRVCONVERT, `iso-8859-1`, host code page `037` are stated on each send; the media types are
  text or JSON.

## Citations

* [WEBSEND] IBM CICS TS 6.x, EXEC CICS WEB SEND (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-send-server
  (FROM, FROMLENGTH, MEDIATYPE, STATUSCODE, STATUSTEXT, STATUSLEN, ACTION; INVREQ RESP2 72 and 75).
* [WEBWHDR] IBM CICS TS 6.x, EXEC CICS WEB WRITE HTTPHEADER: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-write-httpheader
  (HTTPHEADER, NAMELENGTH, VALUE, VALUELENGTH; "When CICS is an HTTP server, the message is a response to a Web client").
* [WEBRHDR] IBM CICS TS 6.x, EXEC CICS WEB READ HTTPHEADER: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-read-httpheader
  (NOTFND RESP2 1, INVREQ RESP2 43).
* [WEBEXTR] IBM CICS TS 6.1, EXEC CICS WEB EXTRACT:
  https://ibm.com/docs/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_webextract.html (QUERYSTRING).
* [URIMAP]: as `gt-http-inbound`.
