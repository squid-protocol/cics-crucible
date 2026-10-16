# gt-web-server-receive: server WEB RECEIVE (MAXLENGTH, LENGERR), WEB EXTRACT, WEB READ HTTPHEADER (NOTFND)

Third step of the HTTP family (gitgalaxy#4767 C3), on the peer model of `gt-http-inbound` (SPEC sections 2, 4, 5 and 6). The
three commands touch only the program's storage (WEB RECEIVE has its event), so the response the program sends is the
breadcrumb the client peer is stated to receive.

## The trap

`GTWRECV` is the program of SERVER URIMAP `RECVURI` (`HOST(*) PATH(/gt/recv)`, alias transaction `GT82`). For each request it
`WEB RECEIVE`s the body into an 8-byte buffer (`MAXLENGTH(8)`), `WEB EXTRACT`s `HTTPMETHOD`, `HOST`, `PATH` and `QUERYSTRING`,
`WEB READ HTTPHEADER('X-Crucible-Tag')`, and `WEB SEND`s one 107-byte line (200 `OK`, `text/plain`):
`RCV=` RESP (2) `/` RESP2 (3), ` L=` LENGTH (3), ` B=` the 8-byte buffer, ` M=` the first 6 bytes of the method, ` H=` the first 20
bytes of the host, ` P=` the first 10 bytes of the path with a leading `/` dropped, ` Q=` the first 10 bytes of the query string
with a leading `?` dropped, ` T=` RESP/RESP2 of the header read, ` V=` the header value (10 bytes, only if RESP is 0). The peer's
stated response body is that line without its trailing blanks.

Four scenarios, each request a `POST` or `PUT` with a body to `crucible.example` (or `other.example`), a query string and two
headers (`X-Crucible-Tag`, `X-Other`; always at least one header, see Avoided ambiguities):

* **`receive`**: body `HELLO` (5 bytes), then `ABCDEFGH` (exactly MAXLENGTH).
* **`lengerr`**: body `ABCDEFGHIJKL` (12 bytes) into MAXLENGTH 8.
* **`extract`**: a `POST` to `crucible.example` with query `a=1&b=2`, a `PUT` to `other.example` with query `z=9` (tag `gamma`).
* **`header`**: `X-Crucible-Tag: alpha` present, then a request with only `X-Other`.

## Why a naive translation breaks

* Using the buffer size or MAXLENGTH as the length received: `LENGTH` is the amount returned (5, 8, 3...), not 8.
* Raising no condition when the body is longer than MAXLENGTH, or delivering all 12 bytes: the data is truncated to 8 and the
  rest discarded, with LENGERR RESP2 57.
* Raising LENGERR when the body is exactly MAXLENGTH: only "exceeds" is an error.
* Returning an empty value, or abending, when the header is missing: it is NOTFND (RESP 13) RESP2 1, and the program carries on.
* Giving `WEB EXTRACT` the transaction's or terminal's idea of a method or host: the values come from the request line and the URL.

## Expected behaviour

Model: as `gt-http-inbound`: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time, and each request starts
its own `GT82` task (new working storage) with no terminal and no EIBAID. Requests are 5 seconds apart within a scenario.

* **`receive`** (peer `client-a`). Request 0 (10:00:00): `WEB RECEIVE INTO(8) MAXLENGTH(8)`: "LENGTH ... is set to the amount of
  data that CICS has returned to the application" [WEBRECV]: 5, buffer `HELLO   `, RESP NORMAL. Request 1 (10:00:05): 8 bytes
  into MAXLENGTH 8: the data does not exceed the value [WEBRECV, MAXLENGTH: "If the length of data exceeds the value specified..."
  is the only truncation rule], so NORMAL, LENGTH 8. `WEB EXTRACT` returns `POST`, `crucible.example`, the path `/gt/recv` (logged
  as `gt/recv`) and the query string (logged without any `?`) [WEBEXTR]; the header read is NORMAL and V is `alpha`.
  Log line, request 0: `RCV=00/000 L=005 B=HELLO    M=POST   H=crucible.example     P=gt/recv    Q=k=1&n=22   T=00/000 V=alpha`.
* **`lengerr`** (`client-b`). The 12-byte body exceeds MAXLENGTH 8 and NOTRUNCATE is not given: "the data is truncated to that
  value, and the remainder of the data is discarded" [WEBRECV, MAXLENGTH] and "A LENGERR response with a RESP2 value of 57 is
  returned if further data was present" [WEBRECV, LENGTH]. The event has resp `LENGERR`, resp2 57, `length` 8 and the first 8
  bytes `ABCDEFGH`. The program carries on (RESP is given), EXTRACT and the header read are NORMAL, and the line starts
  `RCV=22/057 L=008 B=ABCDEFGH`.
* **`extract`** (`client-c`). The first request is a `POST` to `crucible.example`; the second a `PUT` with body `NEW` to
  `other.example`, query `z=9`, tag `gamma`. HTTPMETHOD "specifies a buffer to contain the HTTP method string on the request
  line", HOST "the host component of the URL", PATH "the path specified in the request line", QUERYSTRING "the query string on the
  request line" [WEBEXTR]. The lines show `M=POST` / `M=PUT` and the two hosts and queries.
* **`header`** (`client-d`). Request 0 carries `X-Crucible-Tag: alpha`: `T=00/000 V=alpha`. Request 1 carries only `X-Other: x`:
  NOTFND RESP2 1 "The header with the given name could not be found" [WEBRHDR] (RESP 13), so `T=13/001` and V stays blank.

The peer scripts are in `case.json` (`peers`); the validator checks each `WEB-SEND` against them. Logs: `expected/*.json`.

## What a correct port must do

* Give a server task the request body through `WEB RECEIVE`, LENGTH the amount returned, truncating to MAXLENGTH and raising
  LENGERR RESP2 57 when more was present.
* Answer `WEB EXTRACT` from the request (method, host, path, query string) and `WEB READ HTTPHEADER` from the request's headers by
  name, NOTFND RESP2 1 for a header the request does not carry.

## Avoided ambiguities

* **Leading `/` of PATH and `?` of QUERYSTRING, and every length that EXTRACT / READ HTTPHEADER write back** (METHODLENGTH,
  HOSTLENGTH, PATHLENGTH, QUERYSTRLEN, VALUELENGTH): IBM does not say whether they count or what they hold after the command; the
  program drops one leading `/` or `?` and logs no such length (as `gt-web-parse-url`).
* **No headers at all**: WEB READ HTTPHEADER is INVREQ RESP2 43 "No HTTP headers found" [WEBRHDR]; a real request always carries
  headers, so every request here states at least one, and the case never reads with none.
* **Header name case**: the program reads the header with the exact spelling the request sends it in.
* **A truncated header value** (LENGERR RESP2 2) and a MAXLENGTH or VALUELENGTH not above zero (LENGERR RESP2 16 / 1): not used.
* **A request without a body** (a `GET`): what WEB RECEIVE returns is not stated; every request here is a `POST` or `PUT` with a
  body. **SCHEME, PORTNUMBER** of EXTRACT (a CVDA and a default): not requested. **NOTRUNCATE** and a second RECEIVE: not used.
* **Code page.** As `gt-http-inbound`: SRVCONVERT, `iso-8859-1`, host code page `037` are stated on both commands.

## Citations

* [WEBRECV] IBM CICS TS 6.x, EXEC CICS WEB RECEIVE (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-receive-server
  (INTO, LENGTH, MAXLENGTH; LENGERR RESP2 16 / 36 / 57).
* [WEBEXTR] IBM CICS TS 6.1, EXEC CICS WEB EXTRACT:
  https://ibm.com/docs/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_webextract.html (HTTPMETHOD, HOST, PATH,
  QUERYSTRING; LENGERR RESP2 4 / 8 / 29 / 30).
* [WEBRHDR] IBM CICS TS 6.x, EXEC CICS WEB READ HTTPHEADER: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-read-httpheader
  (HTTPHEADER, NAMELENGTH, VALUE, VALUELENGTH; NOTFND RESP2 1, INVREQ RESP2 43, LENGERR RESP2 2).
* [WEBSEND] and [URIMAP]: as `gt-http-inbound`.
