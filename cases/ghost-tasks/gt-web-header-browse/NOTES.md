# gt-web-header-browse: server WEB STARTBROWSE / READNEXT / ENDBROWSE HTTPHEADER

The HTTP-header sibling of the QUERYPARM / FORMFIELD browse in `gt-web-query-form` (gitgalaxy#7956: the det-modelled `WEB STARTBROWSE
HTTPHEADER`, `WEB READNEXT HTTPHEADER` and `WEB ENDBROWSE HTTPHEADER` had no case; every uncovered command has 0 burned programs, so
this is the server-side group that the peer model can state). Peer model and request keys as `gt-http-inbound` (SPEC sections 2, 4, 5, 6).
None of the commands is an event: the response each task sends is the breadcrumb the client peer is stated to receive.

## The trap

`GTWHBR` is the program of SERVER URIMAP `HBRURI` (`HOST(*) PATH(/gt/hb)`, alias transaction `GT91`). It `WEB READ HTTPHEADER`s
`X-Crucible-Mode` (1 to 5) and then runs a fixed sequence, logging each RESP / RESP2 in one 67-byte `WEB SEND` line (200 `OK`,
`text/plain`):

| Item | Command | Answer in every mode |
|---|---|---|
| `P=` | `WEB READNEXT HTTPHEADER` before any browse | INVREQ RESP2 4 (`16/004`) |
| `Q=` | `WEB ENDBROWSE HTTPHEADER` before any browse | INVREQ RESP2 4 (`16/004`) |
| `T=` | `WEB STARTBROWSE HTTPHEADER` | NORMAL (`00`) |
| `S=` | a second `WEB STARTBROWSE HTTPHEADER` inside the browse | ILLOGIC RESP2 10 (`21/010`) |
| `R=` | the first `WEB READNEXT HTTPHEADER`, buffers set by the mode (below) | see below |
| `F=` | mode 1 only: `WEB READNEXT` until RESP is not NORMAL (at most 30) | ENDFILE (`20`); `00` in modes 2-5 (no loop) |
| `E=` | `WEB ENDBROWSE HTTPHEADER` | NORMAL (`00/000`) |
| `X=` | `WEB READNEXT HTTPHEADER` after the browse ended | INVREQ RESP2 4 (`16/004`) |

Scenario **`browse`** (`client-a`), five `GET`s at 10:00:00, :05, :10, :15, :20 (each states `X-Crucible-Mode` only):

| Request | Mode | First READNEXT buffers | `R=` |
|---|---|---|---|
| 0 | `1` | NAMELENGTH 64, VALUELENGTH 255 | NORMAL `00/000` |
| 1 | `2` | NAMELENGTH 1 | LENGERR RESP2 4 (`22/004`) |
| 2 | `3` | NAMELENGTH 0 | LENGERR RESP2 1 (`22/001`) |
| 3 | `4` | VALUELENGTH 0 | LENGERR RESP2 1 (`22/001`) |
| 4 | `5` | NAMELENGTH -1 | LENGERR RESP2 1 (`22/001`) |

## Why a naive translation breaks

* Letting `READNEXT` / `ENDBROWSE` work with no browse (they are INVREQ RESP2 4), or again after `ENDBROWSE`.
* Letting a second `STARTBROWSE` restart or ignore the browse (ILLOGIC RESP2 10 "already in progress").
* Ending the browse with anything but ENDFILE, or looping forever when the list ends.
* Truncating silently: a name longer than NAMELENGTH is LENGERR RESP2 4, not a short name with NORMAL.
* Treating a zero or negative buffer length as "no limit": it is LENGERR RESP2 1.
* Mixing the RESP2s: RESP2 1 (a length of zero or less, server) is not RESP2 35 / 55 (the client-side numbers) and not 4 / 5.

## Expected behaviour

Model: as `gt-http-inbound`: clock 2026-03-02T10:00:00, a task takes no time, each request starts its own `GT91` task with no terminal.
Every line is `M=<mode> P=16/004 Q=16/004 T=00 S=21/010 R=<..> F=<..> E=00/000 X=16/004`; only `R` and `F` vary:

* Mode 1: `R=00/000 F=20`. Modes 2: `R=22/004 F=00`. Modes 3, 4, 5: `R=22/001 F=00`.

Rules used (all [WRH] = READNEXT, [WSB] = STARTBROWSE, [WEB] = ENDBROWSE pages below):
* READNEXT before STARTBROWSE: INVREQ RESP2 4, "The command is being issued before a WEB STARTBROWSE has been issued." [WRH]
* ENDBROWSE before STARTBROWSE: INVREQ RESP2 4, "...before a WEB STARTBROWSE command is issued." [WEB]
* STARTBROWSE: "signals the start of a browse of the HTTP header information." [WSB]; a second one while a browse is open is ILLOGIC
  RESP2 10, "An HTTP header browse is already in progress." [WSB]
* READNEXT: "retrieves the next HTTP header in the list of headers." [WRH]; at the end ENDFILE, "The end of the list of HTTP headers has
  been reached." [WRH]
* LENGERR RESP2 4: "The header name has been truncated because the receiving buffer is too small (CICS as an HTTP server)." [WRH]
* LENGERR RESP2 1: "The length in NAMELENGTH or VALUELENGTH is less than or equal to zero (CICS as an HTTP server)." [WRH]
* ENDBROWSE "terminates the browse" [WEB]; after it a READNEXT is again "before a WEB STARTBROWSE" (a reading: the browse is gone).
* RESP codes: ENDFILE 20, INVREQ 16, LENGERR 22, ILLOGIC 21.

## What a correct port must do

* Keep a browse flag per task: STARTBROWSE opens it (ILLOGIC RESP2 10 if open), READNEXT and ENDBROWSE need it (INVREQ RESP2 4), ENDBROWSE clears it.
* Return headers one at a time, ENDFILE after the last; validate NAMELENGTH / VALUELENGTH (RESP2 1) and truncate the name with LENGERR RESP2 4.

## Avoided ambiguities

* **Order, case and number of headers.** IBM does not say in what order READNEXT returns headers, in what case names come back, or whether
  CICS or the transport adds headers of its own. The program logs no header name and no count: only RESP / RESP2, and the end of the
  list (a mode-1 loop that always ends in ENDFILE, as long as every value fits 255 bytes).
* **INVREQ RESP2 43** ("No HTTP headers found") on STARTBROWSE and **RESP2 6** (a header not in NAME:VALUE form): every request states a header; none is malformed.
* **A READNEXT after a LENGERR**: whether the header is returned again is not stated for HTTPHEADER; modes 2-5 end the browse right after it.
* **A VALUE truncation** (LENGERR RESP2 5): the first header returned is not stated, so no value buffer is made short; **RESP2 4 with a name buffer of 1 byte**
  assumes every header name is longer than one byte (HTTP names are tokens; the stated `X-Crucible-Mode` has 15).
* **Lengths written back** (NAMELENGTH / VALUELENGTH) are not logged. The program refills the buffers and lengths before each read.
* **Client-side numbers** (RESP2 35 / 51 / 52 / 55, SESSTOKEN, NOTOPEN): CICS as an HTTP client, a sibling gap.

## Citations

IBM CICS TS 6.1, reference, application commands (base `https://ibm.com/docs/SSGMCP_6.1.0/reference-applications/commands-api/`; read 2026-11-11):

* [WSB] `dfhp4_webstartbrowsehttpheader.html`: EXEC CICS WEB STARTBROWSE HTTPHEADER (ILLOGIC RESP2 10; INVREQ RESP2 1, 3, 43; NOTFND RESP2 1).
* [WRH] `dfhp4_webreadnexthttpheader.html`: EXEC CICS WEB READNEXT HTTPHEADER (ENDFILE; INVREQ RESP2 1, 3, 4, 6; LENGERR RESP2 1, 4, 5, 35, 51, 52, 55).
* [WEB] `dfhp4_webendbrowsehttpheader.html`: EXEC CICS WEB ENDBROWSE HTTPHEADER (INVREQ RESP2 1, 3, 4; NOTOPEN RESP2 27).
* [WEBRHDR], [WEBSEND], [URIMAP]: as `gt-web-write-header` and `gt-http-inbound`.
