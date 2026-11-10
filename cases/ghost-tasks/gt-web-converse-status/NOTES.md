# gt-web-converse-status: WEB CONVERSE STATUSTEXT / STATUSLEN and MEDIATYPE of the response

Follows `gt-web-client` (WEB OPEN / CONVERSE / CLOSE against a stated origin peer, gitgalaxy#4767). That case reads only the
status code and body. This one reads the rest of the response line and the content type: the reason phrase (`STATUSTEXT`,
length `STATUSLEN`) and the media type (`MEDIATYPE`). Part of gitgalaxy#7956 (cases for the uncovered commands).

## The trap

`GTWCVS` is the program of transaction `GT86`, typed as `GT86 A`, `GT86 B` or `GT86 C`; each names a different origin host.
It issues `WEB OPEN`, then `WEB CONVERSE ... GET PATH('/gt/status') INTO(32 bytes) MAXLENGTH(32) TOLENGTH STATUSCODE
STATUSTEXT(19 bytes) STATUSLEN(19) MEDIATYPE(56 bytes)`, `WEB CLOSE`, and sends
`GT86 S=<status> L=<tolength> T=<reason phrase, 19 wide> M=<media type>`. Three scenarios:

* **`ok`** (`GT86 A`, host `ok.example`): 200, reason phrase `OK`, media type `application/json`, body `{"n":1}` (TOLENGTH 7).
* **`notfound`** (`GT86 B`, host `missing.example`): 404, `Not Found`, `text/plain`, body `no such item` (12). A 404 is a response.
* **`fullphrase`** (`GT86 C`, host `busy.example`): 503, `Service Unavailable` (19 characters, exactly `STATUSLEN`),
  `text/html`, body `try later` (9). The phrase fills the area with nothing to spare and is not an error.

## Why a naive translation breaks

* Taking the reason phrase from the status code (a table of 200 -> OK): the phrase is the **server's** text, returned in
  `STATUSTEXT`; a server may send any phrase for a code.
* Not filling `STATUSTEXT` or `MEDIATYPE` at all (a Java HTTP client that exposes only a status int and a body), so the program
  shows blanks.
* Treating a phrase of exactly `STATUSLEN` characters as too long (an off-by-one that raises LENGERR RESP2 58): IBM raises it
  when the text *exceeds* the length.
* Putting the request's media type (no body here, so none is sent) into the output instead of the response's.

## Expected behaviour

Model: as `gt-web-client` (CSD installed, clock 2026-03-02T10:00:00, a task takes no time). `WEB-OPEN`, `WEB-CONVERSE` and
`WEB-CLOSE` are events (SPEC section 6); their fields are unchanged. The reason phrase and media type are **not** event
fields: they are observable through the program's `SEND TEXT`, whose `text` is in each log. The peer's response states them
(`statustext`, `mediatype`; `statustext` is the additive peer key this case introduces, SPEC section 5).

* **`STATUSTEXT` / `STATUSLEN`**: "Specifies a data area to receive any text returned by the server to describe the status
  code." "The STATUSLEN option gives the length allowed for the text." [WEBCONV] Examples on the page are "OK" for 200 and
  "Bad Request" for 400. LENGERR RESP2 58 is "The status text exceeds the length specified"; a phrase of exactly STATUSLEN
  characters does not exceed it (`fullphrase`).
* **`MEDIATYPE`**: "Specifies a 56-character data area to receive the media type (that is, the type of data content) for the
  body, for example `text/xml`." [WEBCONV] With no body sent the area is not an input; it only receives the response's.
* **`STATUSCODE`, `INTO`, `TOLENGTH`** as in `gt-web-client` [WEBCONV].

Logs: `expected/*.json`.

## What a correct port must do

* Return the server's reason phrase in `STATUSTEXT` and its Content-Type in `MEDIATYPE`, with `NORMAL` for any status.
* Accept a phrase whose length equals `STATUSLEN`.
* Leave the rest of each area as the program had it (blanks).

## Avoided ambiguities

* **Padding of the areas.** IBM does not say what follows the text in `STATUSTEXT` or `MEDIATYPE` (the page has no padding
  rule). The program starts both areas as blanks and the log reads blanks after the text: listed in the README's
  lower-confidence table. A phrase of exactly 19 characters leaves no padding in `STATUSTEXT`, which is why `fullphrase` exists.
* **A phrase longer than `STATUSLEN`** (LENGERR RESP2 58): IBM does not say what `STATUSTEXT` then holds, so no scenario sends one.
* **`STATUSLEN` on return.** IBM describes it as the length allowed (an input); whether CICS updates it is not stated, so the
  program never reads it back.
* **Request-side options**: `FROM` / `FROMLENGTH`, a request `MEDIATYPE`, `QUERYSTRING` / `QUERYSTRLEN`, `NOOUTCONVERT`, and the
  methods POST and PUT are not used: the `WEB-CONVERSE` event (SPEC section 6.2) carries only method GET/HEAD/DELETE/OPTIONS/TRACE and
  a path, so the request body, query and content type cannot be stated in a log without a new event shape. A later case.
* **Code page**, **HTTPS**, **URIMAP**, **failures of the exchange**: as `gt-web-client`.

## Citations

* [WEBCONV] IBM CICS TS 6.x, EXEC CICS WEB CONVERSE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-converse
  (STATUSTEXT, STATUSLEN, MEDIATYPE, STATUSCODE, INTO, TOLENGTH; LENGERR RESP2 58, 59). Read 2026-11-10.
* [WEBOPEN] IBM CICS TS 6.x, EXEC CICS WEB OPEN: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-open
* [WEBCLOSE] IBM CICS TS 6.x, EXEC CICS WEB CLOSE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-close
