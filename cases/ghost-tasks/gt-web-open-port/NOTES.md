# gt-web-open-port: WEB OPEN PORTNUMBER, the default port and a port above 65535

Follows `gt-web-client`, which leaves PORTNUMBER unused. `WEB OPEN` takes the port as a fullword binary value; a program that
connects to a server on a port the scheme does not default to must name it, and CICS refuses a port that cannot exist.

## The trap

`GTWPRT` is the program of transaction `GT8P`, typed at the terminal as `GT8P A` or `GT8P B`. It issues
`WEB OPEN HOST('orders.example') HOSTLENGTH(14) PORTNUMBER(port) SCHEME(HTTP) SESSTOKEN RESP RESP2`. Only when the OPEN was
NORMAL does it issue `WEB CONVERSE` (GET `/gt/item`) and `WEB CLOSE`. It then sends `GT8P O=<resp> W=<resp2> S=<status> <body>`
(`O` is the numeric RESP of the OPEN, `W` its RESP2 shown only when the OPEN was not NORMAL, `S` the status of the exchange).

* **`default-port`** (`GT8P A`): port 80, the HTTP default. The OPEN is NORMAL and the program reaches the stated origin peer
  `orders` (200, body `item=42`): `GT8P O=00 W=000 S=200 item=42`.
* **`port-too-high`** (`GT8P B`): port 65536. The OPEN is INVREQ with RESP2 138 (`O=16`, `W=138`); no connection exists, so the
  program issues no CONVERSE and no CLOSE: `GT8P O=16 W=138 S=000`.

## Why a naive translation breaks

* A Java client that takes the port into a `URI` or `Socket` and lets an out-of-range port throw `IllegalArgumentException`
  instead of returning INVREQ / RESP2 138 to a program that handled RESP.
* A port truncated to 16 bits (65536 becomes 0, or 65537 becomes 1) and connected anyway: the OPEN reports NORMAL.
* Ignoring an explicit port 80 or treating it as a different server from the default port.

## Expected behaviour

Model: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time. The origin peer is found by the OPEN's
`host` (SPEC section 2, client role); `WEB-OPEN` carries host, scheme, `resp` and, where IBM documents it, `resp2`. The port is
not an event key (SPEC: "the port is the default"): the program shows its outcome instead.

* **PORTNUMBER**: "Specifies the port number, as a fullword binary value. You specify the port number only if it is not the
  default for the specified scheme. For HTTP, the default port number is 80, and for HTTPS, the default port number is 443"
  [WEBOPEN]. Naming 80 for HTTP is therefore the same connection as naming no port: NORMAL, then the peer's response.
* **INVREQ RESP2 138**: the WEB OPEN conditions list "INVREQ ... 138 The port number is greater than 65535" [WEBOPEN]. 65536 is
  greater than 65535, so the OPEN fails with INVREQ and RESP2 138.
* **After the failed OPEN** the program issues nothing further to the web: no session was returned, so the log has no
  `WEB-CONVERSE` or `WEB-CLOSE`.

Logs: `expected/*.json`.

## What a correct port must do

* Pass the port to the connection; connect to the origin the host (and the default port) names, and return the response.
* Return INVREQ with RESP2 138 to the program for a port above 65535, without connecting, and without raising an exception
  the program did not handle.

## Avoided ambiguities

* **A port below 1** (0 or negative): IBM's page gives it no condition, so no scenario uses one.
* **A non-default port** (for example 8080): the SPEC states peers by host and the WEB-OPEN event has no port, so which peer a
  non-default port reaches is not stated. Not used; a later case would need an additive SPEC key.
* **RESP2 of a NORMAL OPEN**: IBM sets RESP2 for exceptional conditions only, so the program shows `W` only after a failed
  OPEN and the log never asserts a RESP2 of a NORMAL command.
* **Order of checks**: 65536 is the only invalid input; HOST / HOSTLENGTH / SCHEME are valid, so no other OPEN condition can
  compete with 138.
* **Options not used**: HTTPS, certificates, URIMAP, proxies; as in `gt-web-client`. The CONVERSE and CLOSE of `default-port` are
  as that case.

## Citations

* [WEBOPEN] IBM CICS TS 6.x, EXEC CICS WEB OPEN: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-open
  (PORTNUMBER defaults; INVREQ RESP2 138; opened 2026-11-10).
