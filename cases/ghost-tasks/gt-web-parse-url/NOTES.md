# gt-web-parse-url: EXEC CICS WEB PARSE URL: the parts of a URL, default ports, INVREQ for a bad URL, LENGERR for a short buffer

This is the pure-computation member of the `EXEC CICS WEB` family (gitgalaxy#4767): `WEB PARSE URL` touches only the program's
storage and needs no HTTP peer, so it is observable with the breadcrumb queue alone and adds no SPEC event. The peer-driven commands
(OPEN / CONVERSE / SEND / RECEIVE) are separate cases.

## The trap

`GTWPARS` (transaction `GT71`) is typed with a mode after `GT71` and logs what each `WEB PARSE URL` did to TS queue `GTWLOG`. Item
format, 88 bytes: tag (3), ` R=` RESP (2), ` S=` RESP2 (3), ` SCH=` the first 5 bytes of SCHEMENAME, ` P=` PORTNUMBER (5 digits),
` HL=` HOSTLENGTH after the command (3 digits), ` H=` the first 20 bytes of HOST, ` P=` the first 10 bytes of PATH with a leading `/`
dropped, ` Q=` the first 10 bytes of QUERYSTRING with a leading `?` dropped. A failed command logs RESP and RESP2 only; the other fields
are blank / zero.

* **P**: five well-formed URLs. **E**: two URLs IBM rejects. **L**: one URL with one output buffer too short at a time.

## Why a naive translation breaks

* A port that returns the scheme as typed (`HtTp`, `hTTps`) logs `HtTp`: IBM returns it in upper case (P2, P3).
* A port that leaves PORTNUMBER 0 (or null) when the URL names no port logs `P=00000` for P2 / P3; IBM returns the scheme's default
  (80 / 443).
* A port that keeps the brackets of an IPv6 host (`[2001:db8::1]`) or splits the host at the first colon logs the wrong HOST / port
  (P5).
* A port that parses any string (no scheme, `%zz`) never raises INVREQ (E1, E2); one that truncates silently never raises LENGERR
  (L1-L3), or raises it with the wrong RESP2 (host 29, path 30, query string 8).

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; each scenario starts at 10:00:00 on 2026-03-02 with `GT71 <mode>` typed on
T001. NORMAL is RESP 0, INVREQ 16, LENGERR 22 [RESP-CODES]. The output areas are `WS-SCHEME` (16 characters), `WS-HOST` (116),
`WS-PATH` and `WS-QRY` (256), `WS-PORT` (fullword binary); HOSTLENGTH, PATHLENGTH and QUERYSTRLEN are set to the buffer sizes before
each command (116, 256, 256 except as stated).

* **`parse`** (P): the command splits "a URL into its component parts" [PARSE-URL]. SCHEMENAME is "returned in upper case" and only
  HTTP and HTTPS are supported; HOST is the host name or IP address, "without brackets" for an IPv6 address; PORTNUMBER is the
  explicit port, "or the default for the scheme if none" (80 HTTP, 443 HTTPS) [PARSE-URL].
  * P1 `https://example.com:8443/a/b?x=1&y=2`: `HTTPS`, port 8443, host `example.com` (HOSTLENGTH 11, "set to the length of the data
    returned"), path `a/b`, query `x=1&y=2`.
  * P2 `HtTp://example.org/docs?q=7`: `HTTP`, port 80, `example.org`, `docs`, `q=7`.
  * P3 `hTTps://example.net/s?k=v`: `HTTPS`, port 443, `example.net`, `s`, `k=v`.
  * P4 `http://192.0.2.7:8080/a?b=c`: `HTTP`, 8080, `192.0.2.7` (HOSTLENGTH 9), `a`, `b=c`.
  * P5 `http://[2001:db8::1]:81/a?b=c`: `HTTP`, 81, host `2001:db8::1` (11), `a`, `b=c`.
  * The program sends `DONE OK` and RETURNs.
* **`errors`** (E): INVREQ RESP2 28 "Incorrect URL" and RESP2 65 "Bad escape sequence" [PARSE-URL].
  * E1 `example.com/a?x=1` (no scheme, no `://`): INVREQ 28. See the README lower-confidence table.
  * E2 `http://example.com/a%zz?x=1` (`%` not followed by two hex digits): INVREQ 65. IBM: the command checks that "escape
    sequences" are valid.
* **`lengerr`** (L): URL `http://example.com/a/b?x=1&y=2`; one buffer is too short per command and the other two are large.
  * L1 HOSTLENGTH 4: LENGERR RESP2 29 "Length of host name returned is greater than HOSTLENGTH" (host is 11 characters).
  * L2 PATHLENGTH 1: LENGERR 30 "Length of path returned is greater than PATHLENGTH" (path is at least 3 characters).
  * L3 QUERYSTRLEN 1: LENGERR 8 "Length of query string returned is greater than QUERYSTRLEN" (`x=1&y=2`, 7 characters).
  * Only one buffer is short per command, so IBM's order among the three LENGERRs is never needed.

## What a correct port must do

* Return SCHEMENAME in upper case whatever the case typed; PORTNUMBER explicit, else 80 for HTTP and 443 for HTTPS.
* Return an IPv6 host without brackets and an IPv4 host as dotted text; set HOSTLENGTH to the returned length.
* INVREQ RESP2 28 for an incorrect URL, 65 for a bad escape sequence; LENGERR RESP2 29 / 30 / 8 when the host / path / query
  string is longer than its supplied length.

## Avoided ambiguities

* **Whether PATH has its leading `/` and QUERYSTRING its `?`**, and **PATHLENGTH / QUERYSTRLEN of a returned value**: IBM does not
  say; the program drops one leading `/` or `?` if present and logs neither length.
* **A URL with no path or no query string**: IBM does not say what the areas hold; every successful URL has both.
* **HOSTTYPE** (a CVDA whose numbers this case would have to assert): not requested.
* **Escapes in a valid URL** (whether the query string is returned escaped or decoded, how a path escape is returned): none used.
* **Other schemes** (`ftp://`), an empty host, an overlong URL, URLLENGTH not matching the URL: not used.
* **What the output areas hold after a failed command or a LENGERR** ("truncated" data): never logged.

## Citations

* [PARSE-URL] CICS TS 6.1, EXEC CICS WEB PARSE URL (options, SCHEMENAME upper case, PORTNUMBER default, HOST without brackets,
  INVREQ RESP2 28 / 65, LENGERR RESP2 8 / 29 / 30):
  https://ibm.com/docs/SSGMCP_6.1.0/reference-applications/commands-api/dfhp4_webparseurl.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, LENGERR 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
