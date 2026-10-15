# gt-http-inbound: an inbound HTTP request is a task (SERVER URIMAP, WEB RECEIVE, WEB SEND, a stated client peer)

The first case of the HTTP peer model (SPEC sections 2, 4 and 6, gitgalaxy#4767 C2): the "ghost" here is a task nobody
typed. No operator step starts it; a web client's request does, through a URIMAP. The peer-driven WEB cases that follow
(extract, status codes, errors) build on this one.

## The trap

`GTHECHO` is the user application program of the SERVER URIMAP `ECHOURI` (`HOST(*) PATH(/crucible/echo)`, alias
transaction `GT81`). It `WEB RECEIVE`s the request body into a 32-byte buffer, builds `ECHO:` followed by the body and
`WEB SEND`s that with status 200 `OK` and media type `text/plain`. The scenario has no operator step. The case states one
client peer, `client-a`, with the response it expects to each request, and two requests: `HELLO` at 10:00:00 and `AB` at
10:00:05, both `POST /crucible/echo` on `crucible.example`.

## Why a naive translation breaks

* A port that starts programs only from terminal steps, START and RUN never runs `GT81`: the log has two tasks that no
  terminal step explains.
* A port that picks the program by transaction id alone, not by the URIMAP's PATH and HOST, runs a task for a request
  to a path no URIMAP names (the validator refuses such a case: exactly one server URIMAP matches each request).
* A port that sends the response to "whoever called", with no stated peer, cannot be compared: `WEB SEND` to a peer the
  case does not state is a defined failure of the run, not a response (SPEC section 2).
* A port that forgets `LENGTH` is the length *received* (5, then 2), not the buffer length (32), sends `ECHO:HELLO` plus
  27 blanks.

## Expected behaviour

Model (SPEC sections 2 and 4): the CSD's resources are installed; the clock is 2026-03-02T10:00:00; a task takes no time;
a request arriving while no task runs starts its task at once.

* **Request 0 (10:00:00).** `client-a` sends `POST http://crucible.example/crucible/echo`, media type `text/plain`, body
  `HELLO`. Exactly one SERVER URIMAP matches: `ECHOURI`. `OTHERURI` has `PATH(/crucible/other/*)`, which does not match
  (a trailing asterisk is "a wildcard character at the end of the path" [URIMAP]); `HOST(*)` matches any host name
  [URIMAP]; `SCHEME(HTTP)` "accepts web client requests made by using either the HTTP scheme or the HTTPS scheme"
  [URIMAP] (the case sends HTTP). The task runs alias transaction `GT81` [URIMAP: TRANSACTION "specifies the 1-4
  character name of an alias transaction that is to be used to run the application"] and its program is the URIMAP's
  `PROGRAM`, "the user application program that composes the HTTP response" [URIMAP]. `trigger` is
  `{"kind": "http", "request": 0}`; there is no terminal, so `termid` and `eibaid` are null, and no COMMAREA.
  * `WEB RECEIVE INTO LENGTH MAXLENGTH SRVCONVERT CHARACTERSET HOSTCODEPAGE`: "receives the body of an HTTP request"
    into the buffer [WEBRECV]; INTO needs MAXLENGTH greater than zero [WEBRECV] (32); "LENGTH ... is set to the amount of
    data that CICS has returned to the application" [WEBRECV]: 5, and the buffer holds `HELLO`. The body is shorter than
    MAXLENGTH (32), so neither LENGERR 36 nor 57 [WEBRECV]. RESP NORMAL. The event's `data` is the 5
    bytes written into INTO; its `length` is 5.
  * `WEB SEND FROM FROMLENGTH MEDIATYPE STATUSCODE STATUSTEXT STATUSLEN ...`: "the WEB SEND command specifies a response
    to be sent" [WEBSEND], with the status code "inserted on the status line" and STATUSTEXT "human-readable text to
    describe the reason for the status code" [WEBSEND]: 200 `OK`. FROMLENGTH 10: the first five bytes of `WS-OUT` are
    `ECHO:`, and the received five follow. `FROM` is therefore `ECHO:HELLO`; the event's `from` is those 10 bytes.
    No ACTION is given, so the response goes at end of task [WEBSEND: "EVENTUAL ... sends the response to the Web client at
    end of task"]; the case makes nothing depend on that.
  * `RETURN` ends the task.
  * The peer's first stated response is status 200, `text/plain`, body `ECHO:HELLO`: it equals the event.
* **Request 1 (10:00:05).** The same with body `AB`: a new task 2 (the previous has ended; nothing is shared), `LENGTH`
  2, response `ECHO:AB` (7 bytes), the peer's second stated response.

The peer script is in `case.json` (`peers`); the validator checks every event against it. The expected log is
`expected/echo.json`.

## What a correct port must do

Start a task per inbound request from the URIMAP that matches its scheme, host and path, with the URIMAP's alias
transaction and program, no terminal and no EIBAID; give the program the request body through `WEB RECEIVE` with
`LENGTH` set to what was received; deliver `WEB SEND`'s status, media type and body to the request's stated peer; and
treat a send to an unstated peer as a failure of the run.

## Avoided ambiguities

* **Code page.** Whether CICS converts a body when neither SRVCONVERT nor NOSRVCONVERT is given depends on the media
  type and the Content-Type header; both commands state SRVCONVERT, the character set `iso-8859-1` and host code page
  `037`, and use the text media type `text/plain` ("for code page conversion to take place, the MEDIATYPE option must
  specify a type of data content that can be identified as text" [WEBSEND]). The log and the peer script hold the
  characters, not the ASCII bytes on the wire.
* **Most specific match.** IBM takes "the most specific match" when more than one URIMAP matches [URIMAP]; the case has
  exactly one match per request and the validator requires it.
* **The alias transaction's program.** IBM says "whatever name you choose for the alias transaction, it must always run
  the same program" and that the URIMAP's program overrides the transaction definition's [URIMAP]. The model gives the
  alias a CSD `DEFINE TRANSACTION` naming the same program as the URIMAP's `PROGRAM`, so that no reading of the
  override matters. (Listed in the README's lower-confidence table: IBM's default alias runs IBM's web attach
  program, which is not observable here.)
* **No pipelining, HTTPS, headers or chunking.** Requests are plain HTTP, one at a time, with a body and a media type;
  the request line's method is recorded but nothing observable depends on it (WEB RECEIVE does not return it).
* **Timing.** The two requests are five seconds apart and no step shares their second (SPEC section 4).

## Citations

* [WEBRECV] IBM CICS TS 6.x, EXEC CICS WEB RECEIVE (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-receive-server
* [WEBSEND] IBM CICS TS 6.x, EXEC CICS WEB SEND (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-send-server
* [URIMAP] IBM CICS TS 6.x, URIMAP resource definitions (USAGE, SCHEME, HOST, PATH, TRANSACTION, PROGRAM):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-system-management/resources/urimap/dfha4_summary.html
