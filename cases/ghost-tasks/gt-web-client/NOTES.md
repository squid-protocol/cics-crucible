# gt-web-client: client WEB OPEN / WEB CONVERSE / WEB CLOSE against a stated origin peer

Fifth step of the HTTP family (gitgalaxy#4767 C5). C2 to C4 modelled the server role (an inbound request is a task, SPEC
section 2, HTTP peer). This case models the client role: a program opens a connection to a host, sends one request, reads
the response and closes. The server it talks to is a **stated origin peer** (`peers.<id>.host` in `case.json`, SPEC sections
2 and 5); the peer's scripted response is what `WEB CONVERSE` returns.

## The trap

`GTWCLI` is the program of transaction `GT85`, typed at the terminal as `GT85 A` or `GT85 B`. `A` names host `orders.example`,
`B` names host `gone.example`. It issues `WEB OPEN HOST HOSTLENGTH SCHEME(HTTP) SESSTOKEN`, `WEB CONVERSE SESSTOKEN PATH('/gt/item')
METHOD(GET) INTO MAXLENGTH(32) TOLENGTH STATUSCODE` and `WEB CLOSE SESSTOKEN`, then sends `GT85 S=<status> L=<tolength> <body>` to the
terminal. Two scenarios:

* **`ok`** (`GT85 A`): peer `orders` answers 200, body `item=42` (TOLENGTH 7).
* **`notfound`** (`GT85 B`): peer `gone` answers 404, body `no such item` (TOLENGTH 12). A 404 is a response, not a failure:
  the command is `NORMAL` and the program reads the status.

## Why a naive translation breaks

* Treating a non-2xx status as a CICS condition (a Java HTTP client that throws on 404): `WEB CONVERSE` is `NORMAL` and the
  status code is data, `STATUSCODE`, which the program reads.
* Dropping the host: the connection goes to the host `WEB OPEN` names; the same program reaches two different servers.
* Ignoring TOLENGTH or the length of the received body: the program shows `L=07` / `L=12`.
* Skipping `WEB CLOSE`, leaking the connection.

## Expected behaviour

Model: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time. Each scenario types the transaction once.
`WEB-OPEN`, `WEB-CONVERSE` and `WEB-CLOSE` are events (SPEC section 6); the session token is not shown. The origin peer is
found by the OPEN's `host`; its nth response in the scenario answers the nth NORMAL `WEB CONVERSE` to it, and the validator
checks the event's status and body against it (SPEC section 9). The client and server roles are told apart by `SESSTOKEN`.

* **`WEB OPEN`** with HOST / HOSTLENGTH, SCHEME(HTTP) and no PORTNUMBER: NORMAL. IBM: "WEB OPEN enables an application program,
  through CICS web support, to open a connection with a specified host on an HTTP server"; SESSTOKEN "returns an 8-byte binary
  session token"; PORTNUMBER is needed only when the port is not the default, "For HTTP, the default port number is 80" [WEBOPEN].
* **`WEB CONVERSE`** with PATH / PATHLENGTH, METHOD GET and no body: "WEB CONVERSE enables an application program to compose and
  send an HTTP client request and receive a response from the server"; STATUSCODE is "the HTTP status code" of the server (200,
  404), INTO receives the response body, TOLENGTH "the amount of data returned to the application" [WEBCONV]. The conditions the
  page lists (INVREQ, LENGERR, NOTFND, TIMEDOUT and others) are all failures of the exchange, not statuses, so 404 is NORMAL.
* **`WEB CLOSE`** with SESSTOKEN: NORMAL [WEBCLOSE].

Logs: `expected/*.json`.

## What a correct port must do

* Open the connection to the host named, deliver the request to that server, and return the server's status and body to the
  program as `STATUSCODE`, INTO and TOLENGTH, with `NORMAL` for any status the server sends.
* Close the connection on `WEB CLOSE`.

## Avoided ambiguities

* **`WEB CONVERSE` after `WEB CLOSE`.** Not used (this is the scenario the brief offered only if IBM names the RESP2). IBM's
  WEB CONVERSE page has "NOTOPEN: 27, Invalid session token" and, separately, INVREQ RESP2 41 "connection has been closed" and
  74 (Connection: close sent, or inactivity timeout) [WEBCONV]; the WEB CLOSE page lists NOTOPEN (RESP2 27, 144) without saying which
  RESP2 goes with it [WEBCLOSE]. No sentence says that a token already closed is "invalid", or distinguishes it from a closed
  connection, so a log would have to pick NOTOPEN 27, INVREQ 41 or INVREQ 74 by guess. The validator rejects a `WEB-CONVERSE`
  with no session open.
* **Failures of the exchange**: NOTOPEN, the INVREQ / IOERR / TIMEDOUT / NOTFND / NOTAUTH of OPEN and CONVERSE: no scenario
  causes one, and the three events carry `resp` / `resp2` only for a later case.
* **A server that closes the connection** (a `Connection: close` response, INVREQ 74), pipelining, `CLOSESTATUS`, keep-alive:
  not modelled. One session at a time, opened and closed in the same task; a session left open at task end is rejected.
* **Options not used**: HTTPS and certificates, URIMAP (`USAGE(CLIENT)`), PORTNUMBER, proxies, QUERYSTRING, authentication,
  TIMEOUT, request bodies (`FROM`, MEDIATYPE on input, `CLIENTCONV` / `CHARACTERSET` for the request), `ACTION(EXPECT)`,
  containers, STATUSTEXT / STATUSLEN, HTTPVNUM / HTTPRNUM, BODYCHARSET. The program names no MEDIATYPE, so the response's
  media type is not observable; the peer's `mediatype` is stated for completeness and not compared.
* **Code page.** The default applies: "The default is that the entity body is converted both when the request is sent out, and when
  the response is received" [WEBCONV]. The bodies are letters, digits, `=` and blanks, which every ASCII-compatible response
  charset and host code page shares, and the log holds the characters after conversion. Trailing blanks are not compared.
* **Length of the hostname**: given with HOSTLENGTH (14 and 12). A HOST that resolves or not (NOTFND RESP2 20) is not asked: the
  peer stands for the server.

## Citations

* [WEBOPEN] IBM CICS TS 6.x, EXEC CICS WEB OPEN: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-open
  (HOST, HOSTLENGTH, SCHEME, PORTNUMBER defaults, SESSTOKEN; conditions).
* [WEBCONV] IBM CICS TS 6.x, EXEC CICS WEB CONVERSE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-converse
  (PATH, METHOD, INTO, MAXLENGTH, TOLENGTH, STATUSCODE; NOTOPEN RESP2 27; INVREQ RESP2 41, 74; CLIENTCONV default).
* [WEBCLOSE] IBM CICS TS 6.x, EXEC CICS WEB CLOSE: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-close
  (SESSTOKEN; NOTOPEN).
* [URIMAP] and the peer model: as `gt-http-inbound`.
