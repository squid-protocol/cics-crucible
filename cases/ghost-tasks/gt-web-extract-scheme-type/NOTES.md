# gt-web-extract-scheme-type: server WEB EXTRACT of SCHEME / REQUESTTYPE (CVDAs) and the zero-length LENGERRs of VERSIONLEN, PATHLENGTH, HOSTLENGTH

Sibling of `gt-web-server-receive` (gitgalaxy#7956, cics-crucible breadth), on the same peer model (SPEC sections 2, 4, 5 and 6).
`WEB EXTRACT` touches only the program's storage, so the response the program sends is the breadcrumb the client peer is stated to
receive. `gt-web-server-receive` covers HTTPMETHOD, HOST, PATH and QUERYSTRING; this case covers the options it lists as not
requested (SCHEME, REQUESTTYPE) and the "length not greater than zero" conditions of three length options.

## The trap

`GTWEXT` is the program of SERVER URIMAP `EXTURI` (`HOST(*) PATH(/gt/ext)`, alias transaction `GT87`). For each request it issues
five `WEB EXTRACT`s, each with `RESP` / `RESP2`:

1. `SCHEME` and `REQUESTTYPE`: each returned CVDA is compared with `DFHVALUE(HTTP)` / `DFHVALUE(HTTPYES)` and shown as `Y` or `N`
   (never as a number), with the RESP/RESP2 of the command (`E=`).
2. `HTTPVERSION` with `VERSIONLEN(0)` (`V0=`).
3. `PATH` with `PATHLENGTH(0)` (`P0=`).
4. `HOST` with `HOSTLENGTH(0)` (`H0=`).
5. `HTTPVERSION` with `VERSIONLEN(10)` (`VN=`): RESP/RESP2 only; the version text is never shown.

It then `WEB SEND`s one 56-byte line (200 `OK`, `text/plain`): `S=Y R=Y E=00/000 V0=22/007 P0=22/005 H0=22/021 VN=00/000`. The
peer's stated response body is that line.

Two scenarios, each one request to `crucible.example/gt/ext` over HTTP: **`get`** (no body) and **`post`** (body `PING`, which
the program never receives). Both give the same line: no result here depends on the method or the body.

## Why a naive translation breaks

* Treating `SCHEME` as text (`HTTP`) or as the port: it is a CVDA, a fullword compared with `DFHVALUE(HTTP)`.
* Treating `REQUESTTYPE` as the method, or as `HTTPNO`: a request that is an HTTP request (not a response) is `HTTPYES`.
* Accepting a length of zero and returning the piece: `VERSIONLEN`, `PATHLENGTH` and `HOSTLENGTH` not greater than zero are each
  LENGERR (22), RESP2 7, 5 and 21 respectively, three different codes for one mechanism.
* Raising an error for `VERSIONLEN(10)`: the version string fits, so the command is NORMAL.

## Expected behaviour

Model: as `gt-web-server-receive`: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time, and the request
starts its own `GT87` task with no terminal and no EIBAID. One request per scenario, at 10:00:00.

* **Command 1.** The request arrives on an HTTP (not HTTPS) URIMAP, so SCHEME is the CVDA `HTTP`; the request is a request, not a
  response, so REQUESTTYPE is `HTTPYES` [WEBEXTR]. Both match, the command is NORMAL: `S=Y R=Y E=00/000`.
* **Command 2.** `VERSIONLEN` is 0, not greater than zero: LENGERR, RESP2 7 [WEBEXTR]: `V0=22/007`.
* **Command 3.** `PATHLENGTH` is 0: LENGERR, RESP2 5 [WEBEXTR]: `P0=22/005`.
* **Command 4.** `HOSTLENGTH` is 0: LENGERR, RESP2 21 [WEBEXTR]: `H0=22/021`.
* **Command 5.** `VERSIONLEN` is 10, which holds any HTTP version string ("HTTP/1.0", "HTTP/1.1" are 8 bytes): NORMAL, `VN=00/000`.
  RESP is RESP2 0 for NORMAL, so `00/000`.
* The task `WEB SEND`s the line and returns. The event carries status 200, statustext `OK`, mediatype `text/plain`, the 56 bytes.

The peer script is in `case.json` (`peers`); the validator checks the `WEB-SEND` against it. Logs: `expected/*.json`.

## What a correct port must do

* Answer `WEB EXTRACT` SCHEME and REQUESTTYPE from the request with the CVDA values (`HTTP`, `HTTPYES`).
* Raise LENGERR RESP2 7 / 5 / 21 for a VERSIONLEN / PATHLENGTH / HOSTLENGTH not greater than zero, and treat each command's
  condition independently (the program carries on because RESP is given).

## Avoided ambiguities

* **PORTNUMBER and the HTTPVERSION text.** SPEC does not state the port or the version of a request, and IBM's value depends on the
  URIMAP and the client: neither is requested into a displayed value (command 5 gives RESP only).
* **HTTPS.** The case uses HTTP only; the SCHEME of an HTTPS URIMAP (`HTTPS`) and REQUESTTYPE `HTTPNO` (a response) are not used.
* **A length of zero beside a requested area for several options in one command.** One option per command, so only one
  condition can apply (the stub refuses a command raising several).
* **Contents of the areas after a LENGERR.** IBM says the piece is truncated or not returned; the program never reads the areas
  of commands 2 to 4.
* **Code page.** As `gt-web-server-receive`: SRVCONVERT, `iso-8859-1`, host code page `037` are stated on the send.

## Citations

* [WEBEXTR] IBM CICS TS 6.1, EXEC CICS WEB EXTRACT:
  https://ibm.com/docs/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_webextract.html (SCHEME and REQUESTTYPE CVDAs;
  LENGERR RESP2 5 PATHLENGTH not greater than zero, 7 VERSIONLEN not greater than zero, 21 HOSTLENGTH not greater than zero).
* [WEBSEND] and [URIMAP]: as `gt-http-inbound`.
