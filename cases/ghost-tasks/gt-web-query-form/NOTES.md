# gt-web-query-form: server WEB READ QUERYPARM / FORMFIELD and the STARTBROWSE / READNEXT / ENDBROWSE browse of each

Next step of the HTTP family (gitgalaxy#7956: the top det-modelled EXEC CICS command with no case, by burned programs: WEB READ,
1 burned program), on the peer model of `gt-web-server-receive` (SPEC sections 2, 4, 5 and 6). None of the commands is an event
(they touch only the program's storage), so the response each program sends is the breadcrumb the client peer is stated to receive.

## The trap

`GTWQRY` is the program of SERVER URIMAP `QRYURI` (`PATH(/gt/qry)`, alias `GT83`); `GTWFRM` of `FRMURI` (`PATH(/gt/frm)`, alias
`GT84`). Each request runs this fixed sequence (QUERYPARM in `GTWQRY`, FORMFIELD in `GTWFRM`) and `WEB SEND`s one 118-byte line
(200 `OK`, `text/plain`):

1. `WEB READ ('k')` into an 8-byte buffer: `K=` RESP/RESP2 and the value if RESP is 0.
2. `WEB READ ('NAME')` (upper case; the request sends `name` or `NAME`): `U=` RESP/RESP2 and the value.
3. `WEB READ ('zz')`, a name no request has: `Z=` RESP/RESP2.
4. `WEB READ ('name')` into a 3-byte buffer: `S=` RESP/RESP2 and the 3 bytes.
5. `WEB READNEXT` before any STARTBROWSE: `N=` RESP/RESP2.
6. `WEB STARTBROWSE` (no name: from the first pair): `T=` RESP; `WEB READNEXT` until RESP is not 0, at most 6: `C=` the pairs
   read, `F=` the RESP that ended the loop, `B=` `name=value;` for each pair (30 bytes); `WEB ENDBROWSE`: `E=` RESP.

`GTWQRY` scenario `queryparm` (peer `client-q`): `GET ?k=7&name=Al%41n&x=y`, `POST ?k=9&name=Bo` (body `hi`), `GET ?NAME=Cy%2Fd&K=3`.
`GTWFRM` scenario `formfield` (peer `client-f`): three `POST`s of `application/x-www-form-urlencoded` bodies `k=7&name=Al%41n&x=y`,
`NAME=Cy%2Fd&K=3`, `k=9&name=Bo`, no query string. Logs: `expected/*.json`.

## Why a naive translation breaks

* Matching names case-sensitively: `'k'` finds `K`, `'NAME'` and `'name'` find the same parameter.
* Returning the escaped text: `Al%41n` is `AlAn`, `Cy%2Fd` is `Cy/d`.
* Raising no condition for an absent name (NOTFND RESP2 1) or a value longer than the buffer (LENGERR RESP2 5, the first 3 bytes kept).
* Letting READNEXT work with no browse (INVREQ RESP2 4), or ending a browse with anything but ENDFILE (RESP 20), or returning names
  in a changed case (they come back "as stored", so `NAME` and `K` in the third request).
* Reading FORMFIELD from the query string of a POST, or QUERYPARM from a form body: each request carries its data in exactly one place.

## Expected behaviour

Model: as `gt-web-server-receive`: the CSD is installed, clock 2026-03-02T10:00:00, a task takes no time, each request starts its
own task, requests 5 seconds apart. Request lines (`queryparm`; `formfield` has the same lines for its bodies in the order A, C, B):

* **A** (`k=7&name=Al%41n&x=y`): `K=00/000 7`, `U=00/000 AlAn`, `Z=13/001`, `S=22/005 AlA`, `N=16/004`, `T=00`, `C=3`, `F=20`,
  `B=k=7;name=AlAn;x=y;`, `E=00`.
* **B** (`k=9&name=Bo`): `K` 9, `U` `Bo`, `Z=13/001`, `S=00/000 Bo` (fits in 3 bytes), `C=2`, `B=k=9;name=Bo;`.
* **C** (`NAME=Cy%2Fd&K=3`): `K=00/000 3` (`'k'` matches `K`), `U=00/000 Cy/d`, `S=22/005 Cy/`, `C=2`, `B=NAME=Cy/d;K=3;`.

Rules used: names are matched ignoring case [WRFF, WRQP: "The string of text supplied is not case sensitive."]; escaped characters
are unescaped ("CICS unescapes any escaped characters before placing them in the buffer" [WRFF]; "Escaped characters in the query
string data are unescaped" [WRQP]; READNEXT returns data "in its unescaped form" [RNFF, RNQP]); a name not present is NOTFND RESP2 1
[WRFF, WRQP]; a value longer than VALUE is truncated, LENGERR RESP2 5 [WRFF, WRQP]; READNEXT before STARTBROWSE is INVREQ RESP2 4
[RNFF, RNQP]; the end of the list is ENDFILE [RNFF, RNQP]; READNEXT returns the name "as it is stored" [RNFF, RNQP]; STARTBROWSE
with no name starts at the first pair [SBFF, SBQP]. READ QUERYPARM "processes query string data for all HTTP methods, including GET,
POST, PUT, and DELETE" [WRQP], hence the `GET` and the `POST` with a query; FORMFIELD data comes "in the entity body when the POST method
is used" [WRFF], hence the form `POST`s. RESP codes: NOTFND 13, INVREQ 16, ENDFILE 20, LENGERR 22.

## What a correct port must do

* Answer `WEB READ QUERYPARM` from the query string and `WEB READ FORMFIELD` from a POSTed form body, by name ignoring case, with
  the value unescaped; NOTFND RESP2 1 for an absent name; truncation to the buffer with LENGERR RESP2 5.
* Keep a browse cursor per task: STARTBROWSE at the first pair, READNEXT the next pair (name as stored, value unescaped), ENDFILE at
  the end, INVREQ RESP2 4 when no browse is open, ENDBROWSE closing it.

## Avoided ambiguities

* **Repeated names**, **empty values**, and `+` for a blank: the pages do not say; no request repeats a name, has an empty value or a `+`.
* **Lengths written back** (VALUELENGTH, NAMELENGTH of READNEXT): not logged; the program refills the buffers with blanks before each
  read and logs only the bytes it moved on RESP 0 (or the 3 bytes kept by a truncation).
* **FORMFIELD on a GET, and QUERYPARM on a form body**: the pages tie FORMFIELD to form media types and to the GET query string, and say
  nothing exact about the mix. Each request carries its data in one place only, and no FORMFIELD request has a query string.
* **INVREQ RESP2 13** (no keyword parameters / no form data), **17** (invalid forms data), **6** (not NAME=VALUE) and the multipart forms:
  not used; every request has well-formed `name=value` pairs.
* **A READNEXT after a LENGERR** (the same field is returned again [RNFF]): the browse buffers are 8 bytes and no pair is longer.
* **A second STARTBROWSE** (ILLOGIC RESP2 5) and **ENDBROWSE** with no browse: not used. ENDBROWSE is NORMAL here and logs only its RESP.
* **Code page.** ASCII text only: `HOSTCODEPAGE('037')` on every command that takes it, `CHARACTERSET('iso-8859-1')` on the FORMFIELD
  read and browse start, SRVCONVERT / `iso-8859-1` / `037` on the `WEB SEND` as in `gt-web-server-receive`.
* **The headers**: every request states one header only to satisfy the request model; no program reads it.

## Citations

IBM CICS TS 6.1, reference, application commands (base `https://ibm.com/docs/SSGMCP_6.1.0/reference-applications/commands-api/`):

* [WRFF] `dfhp4_webreadformfield.html`: EXEC CICS WEB READ FORMFIELD (NOTFND RESP2 1; LENGERR RESP2 1, 4, 5; INVREQ RESP2 13, 17).
* [WRQP] `dfhp4_webreadqueryparm.html`: EXEC CICS WEB READ QUERYPARM (NOTFND RESP2 1; LENGERR RESP2 1, 5; INVREQ RESP2 13).
* [SBFF] `dfhp4_webstartbrowseformfield.html`, [SBQP] `dfhp4_webstartbrowsequeryparm.html`: EXEC CICS WEB STARTBROWSE.
* [RNFF] `dfhp4_webreadnextformfield.html`, [RNQP] `dfhp4_webreadnextqueryparm.html`: EXEC CICS WEB READNEXT (ENDFILE; INVREQ RESP2 4, 6;
  LENGERR RESP2 4, 5).
* [EBFF] `dfhp4_webendbrowseformfield.html`, [EBQP] `dfhp4_webendbrowsequeryparm.html`: EXEC CICS WEB ENDBROWSE (INVREQ RESP2 4).
* [WEBSEND] and [URIMAP]: as `gt-http-inbound`.
