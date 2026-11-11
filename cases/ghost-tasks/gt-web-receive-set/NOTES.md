# gt-web-receive-set: server WEB RECEIVE SET (CICS acquires the storage) with MEDIATYPE and NOSRVCONVERT

On the peer model of `gt-http-inbound` and `gt-web-server-receive` (SPEC sections 2, 4, 5 and 6). `gt-web-server-receive` covers the
buffer form (`INTO` / `MAXLENGTH`); this case covers the other form, `SET`, with the two options that case never issues.

## The trap

`GTWRSET` is the program of SERVER URIMAP `RSETURI` (`HOST(*) PATH(/gt/rset)`, alias transaction `GT87`). For each request it issues

`WEB RECEIVE SET(ptr) LENGTH(len) MEDIATYPE(area) NOSRVCONVERT RESP RESP2`

points a LINKAGE item at the returned storage (`SET ADDRESS OF LS-BODY TO ptr`), and `WEB SEND`s one 37-byte line (200 `OK`,
`text/plain`): `RCV=` RESP (2), ` L=` LENGTH (3), ` B=` the first `min(LENGTH, 8)` bytes of the body, ` MT=` the first 10 bytes of the
MEDIATYPE area. The peer's stated response body is that line without trailing blanks.

One scenario, `receive`, three POSTs from `client-a` to `crucible.example/gt/rset`, 5 seconds apart:

* 10:00:00 `text/plain`, body `HELLO` (5 bytes).
* 10:00:05 `application/json`, body `{"a":1}` (7 bytes).
* 10:00:10 `image/jpeg`, body `ABCDEFGHIJKL` (12 bytes: longer than the 8-byte LINKAGE item, which the program does not read past).

## Why a naive translation breaks

* Treating `LENGTH` as an input (a maximum) for the `SET` form: it is output only, so a port that needs a preset value, or caps
  the body at the working-storage `LENGTH`, returns 0 or a truncated body.
* Copying the body into a fixed program buffer and reporting the buffer size as the length: the log shows 5, 7 and 12.
* Leaving `MEDIATYPE` unwritten, or writing the request's `Content-Type` header text instead of the type: the area holds the
  media type (`application/json` -> `applicatio` in the first 10 bytes).
* Writing a `WEB-RECEIVE` event with no `data` (as for an unwritten buffer): with `SET`, the pointer addresses the whole body.

## Expected behaviour

Model: as `gt-http-inbound`: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time, and each request starts
its own `GT87` task (new working storage) with no terminal and no EIBAID.

* **`receive`**. Each request: "If the SET option is specified ... CICS acquires the storage for the data and returns its
  address" [WEBRECV, SET], "LENGTH ... the amount of data that CICS has returned to the application" and, with `SET`, is
  required and set by CICS [WEBRECV, LENGTH]; `MEDIATYPE` "a 56-byte area" that receives the media type of the data [WEBRECV,
  MEDIATYPE]. `NOSRVCONVERT` asks for no conversion of the body. Nothing exceeds a limit (no MAXLENGTH is given), so RESP is
  NORMAL and the event carries `length` 5 / 7 / 12 and `data` the whole body (the bytes the pointer addresses, as for `READ SET`).
  The program reads the first `min(LENGTH, 8)` bytes through the pointer. Lines:
  `RCV=00 L=005 B=HELLO    MT=text/plain`, `RCV=00 L=007 B={"a":1}  MT=applicatio`, `RCV=00 L=012 B=ABCDEFGH MT=image/jpeg`.

The peer scripts are in `case.json` (`peers`); the validator checks each `WEB-SEND` against them. Log: `expected/receive.json`.

## What a correct port must do

* Give a server task the whole request body through `WEB RECEIVE SET`, with `LENGTH` the amount returned and the pointer
  addressing exactly those bytes.
* Write the request's media type into the `MEDIATYPE` area.
* Accept `NOSRVCONVERT` without changing the body.

## Avoided ambiguities

* **The rest of the MEDIATYPE area**: IBM gives its size (56) but not what follows the media type; the program logs only the first
  10 bytes, and all three types are at least 10 characters long.
* **Bytes of the body beyond LENGTH**: not addressable by contract; the program reads at most `LENGTH` bytes.
* **Conversion**: NOSRVCONVERT's effect on the bytes is the host's code page question (register X38 assumes the body is in the
  program's characters whatever the option); the SEND states `SRVCONVERT`, `iso-8859-1` and host code page `037` as the other
  cases do, and the bodies are plain ASCII text.
* **Media type parameters** (`; charset=...`) and header case: not used. **A second RECEIVE, NOTRUNCATE, a request without a
  body**: not used (IBM does not say what the areas then hold; `SET` with `NOTRUNCATE` is not allowed by the model).
* **Storage ownership / FREEMAIN of the acquired block**: not used.

## Citations

* [WEBRECV] IBM CICS TS 6.x, EXEC CICS WEB RECEIVE (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-receive-server
  (SET, LENGTH, MEDIATYPE, SRVCONVERT / NOSRVCONVERT, MAXLENGTH).
* [WEBSEND] and [URIMAP]: as `gt-http-inbound`.
