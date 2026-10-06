# ca-channel-containers: a channel in place of a COMMAREA

## The trap

`CACHAN` (transaction `CA05`) passes its data to other programs in a **channel** instead of a
COMMAREA. It names the channel `CAREQUEST` on PUT CONTAINER, which creates it, and puts three
things in it: a CHAR container `REQUEST` (`ABCDEFGHIJ`), an APPEND of `KLM` to it, and a BIT
container `COUNT` holding a fullword (258). It then LINKs to `CACHSUB` with `CHANNEL(WS-CHAN)`.

`CACHSUB` names no channel at all: every command uses its **current channel**, the one it was
LINKed with. It reads `REQUEST` whole and into a 4-byte area, asks for `COUNT`'s length only
(NODATA), reads `COUNT` back as a fullword, asks for a container and a channel that do not
exist, deletes `COUNT`, puts a `REPLY`, and deletes `COUNT` again under a HANDLE CONDITION
CONTAINERERR. Back in `CACHAN`, the reply is there and `COUNT` is gone. `CACHAN` then XCTLs to
`CACHXB` with the channel, which reads the reply through its own current channel and creates a
second channel of its own.

Containers are not events (SPEC 6.2 lists none), so every program writes what each command
returned (tag, RESP, RESP2, FLENGTH, data) to TS queue `CALOG` (copybook `CALOG`, 31 bytes).

`CACHERR` (transaction `CA06`) reads a container its channel does not have with neither RESP
nor HANDLE CONDITION.

## Why a naive translation breaks

* A port that turns a channel into a COMMAREA-like DTO passed by value loses what the LINKed
  program changes. IBM: a program started by LINK "can also return containers to the calling
  program ... by creating new containers, or by reusing existing containers" [CURRENT]. Here the
  caller must see `REPLY` appear and `COUNT` disappear.
* A port that only knows named channels breaks every command without CHANNEL: those use the
  current channel [PUT] [GET], which is the channel the program was LINKed or XCTLed with, and
  none for a terminal task (INVREQ RESP2 4 on GET, blanks from ASSIGN CHANNEL) [ASSIGN] [GET].
* Container data is bytes. A port that stores a container as a string, trims it, or converts
  it changes `COUNT`'s fullword or `REQUEST`'s length.
* The length rules are in-out: FLENGTH is the most a GET takes and then the container's length,
  also on LENGERR; NODATA returns only the length [GET].
* CONTAINERERR, CHANNELERR, LENGERR and INVREQ are ordinary conditions: RESP, HANDLE CONDITION,
  or the default action (abend AEZJ for CONTAINERERR) [AEZJ] [HANDLE].

## Expected behaviour

### `round-trip` (`CA05`)

`CACHAN` (no COMMAREA, no current channel):

1. `ASSIGN CHANNEL`: "the 16-character name of the current channel of the program, if one
   exists; otherwise, blanks" [ASSIGN]. Logged `ASG0`, data blank.
2. `GET CONTAINER('REQUEST')` with no CHANNEL: INVREQ, RESP2 4, "The CHANNEL option was not
   specified, there is no current channel ... and the command was issued outside the scope of a
   currently-active BTS activity" [GET]. (There is no BTS here.) `GET0 016 004`.
3. `PUT CONTAINER('REQUEST') CHANNEL(CAREQUEST) FROM(WS-REQ) CHAR`: "If the channel does not
   exist, it is created" [PUT]. NORMAL. FROM's length (10) is the default FLENGTH [LENGTH].
4. `PUT ... FROM(WS-MORE) APPEND`: "the data passed to the container is appended to the existing
   data" [PUT]. `REQUEST` is now `ABCDEFGHIJKLM` (13 bytes).
5. `PUT CONTAINER('COUNT') ... FROM(WS-BIN) FLENGTH(LENGTH OF WS-BIN) BIT`: a new BIT container,
   "The data in the container cannot be converted" [PUT]. NORMAL.
6. `LINK PROGRAM('CACHSUB') CHANNEL(WS-CHAN)`: the channel "is to be made available to the
   called program" [LINK]; it is `CACHSUB`'s current channel [CURRENT]. No COMMAREA: EIBCALEN 0,
   the LINK event has length 0 and commarea null (SPEC 6.2). NORMAL.

`CACHSUB` (current channel `CAREQUEST`):

7. `ASSIGN CHANNEL`: `CAREQUEST` [ASSIGN].
8. `GET CONTAINER('REQUEST') INTO(WS-AREA) FLENGTH(WS-LEN)`, WS-LEN 20: no CHANNEL, so the
   current channel [GET]. "As an output field, FLENGTH returns the length of the data in the
   container": 13. The log takes WS-AREA's first WS-LEN bytes: `ABCDEFGHIJKLM`. The `REQUEST`
   container is CHAR, put and got without FROMCCSID / INTOCCSID: both default to the region's
   CCSID ("If INTOCCSID and INTOCODEPAGE are not specified, the value for conversion defaults to
   the CCSID of the region" [GET]), so no conversion takes place.
9. Same, INTO the 4-byte WS-SHORT with FLENGTH 4: LENGERR RESP2 11, "The length of the program
   area is shorter than the length of the data in the container. When the area is smaller, the
   data is truncated to fit into it" [GET]; FLENGTH returns 13. `GET4 022 011 00013 ABCD`.
10. `GET CONTAINER('COUNT') NODATA FLENGTH(WS-LEN)`: "no data is retrieved. Use this option to
    discover the length of the data in the container" [GET]. 4.
11. `GET CONTAINER('COUNT') INTO(WS-BIN) FLENGTH(WS-LEN)`, 4: the four bytes put in step 5,
    unconverted (BIT): 258.
12. `GET CONTAINER('NOSUCH')`: CONTAINERERR RESP2 10, "The container named on the CONTAINER
    option could not be found" [GET]. DFHRESP(CONTAINERERR) = 110 [RESP-CODES].
13. `GET ... CHANNEL('CAOTHER')`: no channel of that name was ever created: CHANNELERR RESP2 2,
    "The channel specified on the CHANNEL option could not be found" [GET]. 122 [RESP-CODES].
14. `DELETE CONTAINER('COUNT')`: NORMAL [DELETE].
15. `PUT CONTAINER('REPLY') FROM(WS-REPLY)`: no CHANNEL: "the current channel is implied" [PUT].
16. `HANDLE CONDITION CONTAINERERR(SUB-NOCONT)`, then `DELETE CONTAINER('COUNT')` with no RESP:
    COUNT is gone, CONTAINERERR RESP2 10 [DELETE], and control goes to SUB-NOCONT [HANDLE], which
    logs EIBRESP / EIBRESP2 (`HND1 110 010`) and RETURNs to level 1.

`CACHAN` again:

17. `LNK1`: the LINK's RESP, NORMAL.
18. `GET CONTAINER('REPLY') CHANNEL(WS-CHAN)`: the container CACHSUB created is in the caller's
    channel [CURRENT]: 11 bytes, `DONE-BY-SUB`.
19. `GET CONTAINER('COUNT') ... NODATA`: CACHSUB deleted it: CONTAINERERR RESP2 10. FLENGTH is
    not logged (see Avoided ambiguities).
20. `XCTL PROGRAM('CACHXB') CHANNEL(WS-CHAN)`: XCTL is one of the commands that set the target's
    current channel [CURRENT] [XCTL]. NORMAL; the XCTL event has length 0, commarea null.

`CACHXB` (current channel `CAREQUEST`, same level):

21. `ASSIGN CHANNEL`: `CAREQUEST`.
22. `GET CONTAINER('REPLY')` through the current channel: `DONE-BY-SUB`, 11.
23. `PUT CONTAINER('FINAL') CHANNEL('CANEWCHAN') FROM(WS-OWN)`: a new channel is created [PUT];
    the container, given no data type, is BIT ("the default value, unless FROMCCSID or
    FROMCODEPAGE option is specified" [PUT]).
24. `GET CONTAINER('FINAL') CHANNEL('CANEWCHAN') NODATA FLENGTH`: 10.
25. `RETURN` at level 1: the task ends normally.

### `unhandled-containererr` (`CA06`)

`CACHERR` puts container `ONE` in a new channel `CAERRCHAN` (NORMAL, logged `PUTE`), then GETs
`TWO` from it with neither RESP nor NOHANDLE and no HANDLE CONDITION: CONTAINERERR, whose
default action abends the task with AEZJ, "CONTAINERERR condition not handled" [AEZJ]. There is
no HANDLE ABEND exit: the task is terminated. `BAD2` is never written.

## What a correct port must do

* Keep channels as shared, mutable sets of byte containers: a LINK passes the channel itself.
* Resolve a command without CHANNEL to the current channel, the one the program was LINKed or
  XCTLed with, and give INVREQ RESP2 4 when there is none.
* Keep container data byte for byte: lengths exact, BIT data unconverted, APPEND concatenating.
* Implement FLENGTH as in-out on GET (the most taken; then the container's length, also on
  LENGERR) and NODATA.
* Raise CONTAINERERR (110), CHANNELERR (122), LENGERR and INVREQ with IBM's RESP2 values through
  RESP, HANDLE CONDITION and the default action (AEZJ / AEZV).

## Avoided ambiguities

* **FLENGTH after a condition other than LENGERR.** IBM documents FLENGTH's output as "the length
  of the data in the container"; it does not say what happens to it when the container or channel
  is not found. No log depends on it (GET0, GET2, GET7, GET8 do not log WS-LEN).
* **INTO bytes past the data.** IBM does not say whether a GET shorter than INTO changes the rest
  of the area. Every log moves only INTO's first FLENGTH bytes (reference modification), and the
  4-byte GET4 fills its area exactly.
* **Changing a container's data type.** PUT CONTAINER says DATATYPE "applies only to new
  containers" and also lists INVREQ RESP2 33, "An attempt was made to change the data-type of an
  existing container". The APPEND in step 4 and the PUT in step 15 name no data type, and no PUT
  names a type for an existing container.
* **Channels not passed on XCTL.** IBM's scope tables show a channel passed on XCTL in the scope of
  both programs [SCOPE], but not what happens to other channels the XCTLing program created.
  CACHAN creates only the channel it passes.
* **Character conversion.** Every container is put and got without FROMCCSID, INTOCCSID or a code
  page, so both sides are the region's CCSID (SPEC 2: 037) and nothing is converted.
* **Channel and container names.** Every name is plain upper-case letters, so CHANNELERR /
  CONTAINERERR "illegal character" (RESP2 1 / 18) cannot arise. No name starts with DFH ("Do not
  use container names that begin with DFH" [PUT]).

## Citations

* [PUT] CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL) (CHANNEL "If the channel does not exist, it is created"; APPEND; DATATYPE BIT / CHAR; the current channel; conditions): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [GET] CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (FLENGTH in / out, NODATA, INTOCCSID's default; CHANNELERR 2, CONTAINERERR 10, INVREQ 4, LENGERR 11): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [DELETE] CICS TS 6.x, EXEC CICS DELETE CONTAINER (CHANNEL) (CONTAINERERR RESP2 10): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delete-container-channel
* [LINK] CICS TS 6.x, EXEC CICS LINK (CHANNEL "a channel that is to be made available to the called program"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-link
* [XCTL] CICS TS 6.x, EXEC CICS XCTL (CHANNEL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-xctl
* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (CHANNEL: "the 16-character name of the current channel of the program, if one exists; otherwise, blanks"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
* [CURRENT] CICS TS 5.6, The current channel (set by LINK, XCTL, START and a pseudo-conversational RETURN with CHANNEL; a LINKed program "can also return containers to the calling program"): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=channels-current-channel
* [SCOPE] CICS TS 6.x, The scope of a channel: https://www.ibm.com/docs/en/cics-ts/6.x?topic=channels-scope-channel
* [HANDLE] CICS TS 6.x, EXEC CICS HANDLE CONDITION: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
* [AEZJ] CICS TS 6.x, abend code AEZJ ("CONTAINERERR condition not handled"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aezj
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (CONTAINERERR 110, CHANNELERR 122): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [LENGTH] CICS TS 5.6, LENGTH options in CICS commands (a FROM area's length is the default): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=format-length-options-in-cics-commands
