# ca-get-container-set: GET CONTAINER SET(ptr) FLENGTH

## The trap

`GET CONTAINER ... SET(ptr) FLENGTH(len)` does not copy the container into a program area: CICS
returns the address of its own copy and the length, and the program lays a LINKAGE item over it
with `SET ADDRESS OF`. `CAGCST` (transaction `CA0F`) PUTs a 20-byte BIT container `DATA`
(`ABCDEFGHIJKLMNOPQRST`) in channel `GCCHAN`, GETs it with SET (FLENGTH preset to junk), reads
the view, GETs it again, replaces it with 8 bytes (`uvwxyz12`) and GETs it a third time.
`CAGCSX` (`CA0G`) fails a GET SET two ways. Containers are not events (SPEC 6.2), so each result
is a record in TS queue `GCLOG` (copybook `GCLOG`, 31 bytes: tag X(4), RESP 9(3), RESP2 9(3),
FLENGTH 9(5), data X(16); the data is the first 16 bytes of the view, or bytes 5 to 20).

## Why a naive translation breaks

* A port that treats FLENGTH as an input maximum (as with INTO) may truncate, raise LENGERR
  RESP2 11, or leave the preset value in place (`GET1`, `GET3`, `GET4`): with SET it is output
  only.
* A port that cannot give a pointer into container data, or gives a view shorter than FLENGTH,
  fails `GET2`.
* A port that returns the old length or the old data for a GET SET after a replacing PUT fails
  `GET4`.
* A port that throws on a missing container or channel hides CONTAINERERR RESP2 10 and
  CHANNELERR RESP2 2 (`CE01`, `CE02`).

## Expected behaviour

### `set` (`CA0F`, `CAGCST`)

1. `PUT CONTAINER('DATA') CHANNEL(GCCHAN) FROM(20 bytes) BIT`: channel created, NORMAL (`PUT1`).
2. `WS-LEN` = 99, `GET CONTAINER('DATA') SET(WS-PTR) FLENGTH(WS-LEN)`: "SET(ptr-ref)
   specifies a data area in which the address of the retrieved data is returned"; "FLENGTH is an
   output-only field" and "On completion of the retrieval operation, the data area is set to the
   actual length of the data in the container" [GET]. NORMAL, FLENGTH 20, not 99. `SET ADDRESS OF
   LS-VIEW TO WS-PTR` [SET5]: the view reads `ABCDEFGHIJKLMNOP` for its first 16 bytes (`GET1`)
   and `EFGHIJKLMNOPQRST` for bytes 5 to 20 (`GET2`), so the data is all 20 bytes.
3. A second GET SET of the same container: NORMAL, FLENGTH 20, same bytes (`GET3`). "CICS maintains
   the data area until ... A subsequent GET CONTAINER ... command with the SET option, for the
   same container in the same channel" [GET]: the second command may invalidate the first
   pointer, so the program uses only the pointer the second command returned (it overwrites
   `WS-PTR` and re-does `SET ADDRESS OF`).
4. `PUT CONTAINER('DATA') FROM(8 bytes) BIT` on the existing container replaces its data
   [PUT] (`PUT2`). The pointer held before the PUT is **not read again**: see Avoided
   ambiguities.
5. `WS-LEN` = 77, GET SET: NORMAL, FLENGTH 8, the view `LS-VIEW2` reads `uvwxyz12` (`GET4`).
   `RETURN` at level 1.

### `errors` (`CA0G`, `CAGCSX`)

1. `PUT` of the 20-byte container `DATA` (`ZYXWVUTSRQPONMLKJIHG`): NORMAL (`PUT1`).
2. `GET CONTAINER('NOSUCH') SET FLENGTH`: CONTAINERERR (110), RESP2 10, "The container named on
   the CONTAINER option could not be found" [GET] [RESP-CODES] (`CE01`).
3. `GET CONTAINER('DATA') CHANNEL('GCNONE') SET FLENGTH`: CHANNELERR (122), RESP2 2, "The channel
   specified on the CHANNEL option could not be found" [GET] (`CE02`).
4. `FLENGTH` preset 55, GET SET of `DATA`: NORMAL, FLENGTH 20, view `ZYXWVUTSRQPONMLK`
   (`OK01`): the failures changed nothing. `RETURN`.
5. FLENGTH, the pointer and the view are not read after `CE01` / `CE02` (their log length is 0).

## What a correct port must do

* Return the address of the container's data and set FLENGTH to its length, ignoring FLENGTH's
  incoming value.
* Let a `SET ADDRESS OF` view of any length up to FLENGTH read the data.
* Give a later GET SET of the same container (also after a replacing PUT) its own current length
  and data.
* Raise CONTAINERERR RESP2 10 and CHANNELERR RESP2 2 as ordinary conditions.

## Avoided ambiguities

* **A PUT that changes the container while the old pointer is held.** The GET CONTAINER page
  lists what ends the data area's life (a later GET SET of the same container, DELETE CONTAINER,
  MOVE CONTAINER, the channel leaving program scope, DELETE CHANNEL) and does not name PUT; it
  does not say whether the held pointer then sees the old data, the new data, or neither. The
  case never reads a pointer after a PUT that changed the container it points into: `GET4`
  reads through a pointer returned by a GET SET issued after the PUT. (A later GET SET also
  ends the old area, so the old one is useless after step 5 in any case.)
* **Writing through the view.** The page tells the program to "move it into its own storage" if
  it needs to keep the data and does not say the area is writable; the case only reads.
* **Pointer values.** No address is printed or compared, and two pointers are not compared.
* **FLENGTH and the pointer after CONTAINERERR / CHANNELERR.** Not read and not logged; the page
  states FLENGTH's output for the completed retrieval only.
* **Zero-length containers, BYTEOFFSET with SET, CHAR containers (code page conversion with the
  SET area), and SET with INTO or NODATA.** Not exercised.
* **Whether a GET SET of a different container ends an earlier pointer.** Only the same-container
  rule is stated; the case holds no pointer across a GET SET of another container (it uses one
  container).
* **DATALOCATION and TASKDATAKEY.** The location and key of the area are not asserted.
* **The unhandled conditions.** Every GET uses RESP, so the default action is never reached.

## Citations

* [GET] CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (SET: "Specifies a data area in which the address of the retrieved data is returned"; FLENGTH with SET: "FLENGTH is an output-only field. It must be present and must be specified as a data-area" and "On completion of the retrieval operation, the data area is set to the actual length of the data in the container"; storage lifetime: "CICS maintains the data area until any of the following occurs: A subsequent GET CONTAINER or GET64 CONTAINER command with the SET option, for the same container in the same channel ...", "Do not issue a FREEMAIN command to release this storage", "If your application needs to keep the data, it should move it into its own storage"; CONTAINERERR RESP2 10 "The container named on the CONTAINER option could not be found"; CHANNELERR RESP2 2 "The channel specified on the CHANNEL option could not be found"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [PUT] CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL) (BIT; an existing container's data is replaced unless APPEND or PREPEND is given): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (CONTAINERERR 110, CHANNELERR 122): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [SET5] Enterprise COBOL for z/OS 6.3 Language Reference, Format 5: SET for USAGE IS POINTER data items ("identifier-5 must be level-01 or level-77 items defined in the LINKAGE SECTION. The addresses of these items are set to the value of the operand specified in the TO phrase"): https://www.ibm.com/docs/SS6SG3_6.3.0/lr/ref/rlpssete.html
