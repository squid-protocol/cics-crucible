# ca-receive-retrieve-set: RECEIVE SET and RETRIEVE SET into a POINTER

## The trap

`RECEIVE SET(ptr)` and `RETRIEVE SET(ptr)` do not copy the data into the program: CICS keeps it
and hands back its address, and `SET ADDRESS OF item TO ptr` lays a LINKAGE item over it. The
LENGTH option changes meaning with SET: with INTO it is the size of the program's area, with SET
it is a data area that CICS sets to the length of the data. The LINKAGE item has no length of its
own (here `X(80)` and `X(256)`), so the data is only as long as LENGTH says.

`CARCST` (transaction `CA0D`) RECEIVEs SET into `WS-PTR`, views the input, logs LENGTH and
`LS-IN(1:LENGTH)`, and by the mode letter typed after the transaction id STARTs `CA0E`:
`S` no START, `E` `INTERVAL(0) FROM` 20 bytes (`ORDER 0003 READY`, padded), `N` `INTERVAL(0)`
with no FROM. `CARTWK` (`CA0E`, no terminal) RETRIEVEs SET into `WS-PTR` and logs each result
until the first response that is not NORMAL. Each result is a record in TS queue `RSLOG`
(copybook `RSLOG`, 31 bytes: tag X(4), RESP 9(3), LENGTH 9(4), data X(20)).

## Why a naive translation breaks

* A port that maps SET to a copy into a fixed buffer, or returns the input padded to the
  screen size, gets LENGTH wrong: 6 for the typed `CA0D S`, never 80 (`RC01`).
* A port that treats LENGTH as an input (the INTO meaning) truncates or raises LENGERR from
  whatever the variable held before the command. Here LENGTH starts at 0 (`WS-LEN`).
* A port that cannot return "no data" as a condition throws or returns an empty buffer where
  RETRIEVE gives ENDDATA (29), and loops forever or reads a stale pointer (`RT01` in `enddata`,
  `RT02` in `retrieve-equal`).

## Expected behaviour

### `short-input` (`CA0D S`)

1. `RECEIVE SET(WS-PTR) LENGTH(WS-LEN)`: SET "specifies the pointer reference that is to be set to
   the address of the data read from the logical unit or terminal"; "If you specify the SET
   option, the argument must be a data area. When the data has been received, the data area is
   set to the length of the data" [RECEIVE-3270]. The typed input is the 6 bytes `CA0D S`, so
   NORMAL and LENGTH 6 (`RC01000006CA0D S`).
2. `SET ADDRESS OF LS-IN TO WS-PTR` [SET5]; `LS-IN(1:6)` reads `CA0D S`; byte 6 is the mode `S`,
   so no START. `RETURN`.

### `retrieve-equal` (`CA0D E`)

1. As above, with mode `E`: `START TRANSID('CA0E') INTERVAL(0) FROM(WS-MSG) LENGTH(20)`
   expires at once [START]. `CA0D` returns; `CA0E` runs with no terminal (EIBCALEN 0).
2. `RETRIEVE SET(WS-PTR) LENGTH(WS-LEN)`: SET "specifies the pointer reference to be set to the
   address of the retrieved data"; "If you specify the SET option, the argument must be a data
   area. On completion of the retrieval operation, the data area is set to the length of the
   data" [RETRIEVE]. The data is the 20 bytes started with, so NORMAL and LENGTH 20, equal to
   the FROM length (`RT01000020ORDER 0003 READY    `). No LENGERR: LENGTH is not an
   upper bound with SET, so nothing can be too long for it.
3. The second RETRIEVE: "No more data is stored for the task issuing a RETRIEVE command"
   [RETRIEVE]: ENDDATA (29) [RESP-CODES], logged `RT02029` with LENGTH 0 set by the program
   (the page sets the data area only "on completion of the retrieval operation").

### `enddata` (`CA0D N`)

START `INTERVAL(0)` with no FROM. `CA0E`'s first RETRIEVE SET is ENDDATA: the task "is started by
a START command that did not specify any of the data options FROM, RTRANSID, RTERMID, or QUEUE"
[RETRIEVE]. `RT01029`, LENGTH 0 logged by the program. The program does not set the address of
`LS-DATA`, and reads neither the pointer nor `WS-LEN`, after the failure.

## What a correct port must do

* Return, for SET, a view of the data CICS holds, and set LENGTH to the data's length (6; 20).
* Treat LENGTH as output only with SET, and never raise LENGERR for it.
* Give ENDDATA from the first RETRIEVE for a START without data, and from the next RETRIEVE
  after the data has been retrieved.
* Leave the program's view bounded by LENGTH: the case reads only `(1:LENGTH)`.

## Avoided ambiguities

* **The pointer and LENGTH after ENDDATA.** The page does not say what a failed RETRIEVE leaves
  in either; the program never reads them, and logs 0.
* **The pointer after the next RECEIVE or RETRIEVE.** "The pointer reference is valid until the
  next receive command or the end of task" [RECEIVE-3270]: no view is read after a second
  command of the same kind; `CARTWK`'s view of the first data is not read after its second
  RETRIEVE.
* **Bytes of the LINKAGE item beyond LENGTH.** The items are longer than the data; those bytes
  are never read.
* **RETRIEVE twice after ENDDATA.** The loop stops at the first response that is not NORMAL.
* **START data stored in main or auxiliary storage, and RETRIEVE WAIT.** Not used.
* **The numeric value of any pointer.** Never logged or compared.
* **Where the typed `CA0D` goes.** The unformatted input, from position 0 on a cleared screen,
  is the typed text including the transaction id (SPEC section 5), so LENGTH counts it.

## Spec note

The `RETRIEVE` event's `data` is "the bytes written into INTO"; with SET the event carries the
bytes at the returned address, `length` bytes long. The `RECEIVE` event does the same for SET
(`hc-terminal-receive/set-address`). No new key.

## Citations

* [RECEIVE-3270] CICS TS 5.5, EXEC CICS RECEIVE (3270 logical) (SET: "specifies the pointer reference that is to be set to the address of the data read from the logical unit or terminal"; "The pointer reference is valid until the next receive command or the end of task"; LENGTH: "specifies the length, as a halfword binary value, of the data received", "If you specify the SET option, the argument must be a data area", "When the data has been received, the data area is set to the length of the data"): https://www.ibm.com/docs/en/cics-ts/5.5?topic=summary-receive-3270-logical
* [RETRIEVE] CICS TS 6.x, EXEC CICS RETRIEVE (SET: "specifies the pointer reference to be set to the address of the retrieved data"; LENGTH: "If you specify the SET option, the argument must be a data area. On completion of the retrieval operation, the data area is set to the length of the data", "If you use SET you must also include LENGTH"; ENDDATA: "No more data is stored for the task issuing a RETRIEVE command"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-retrieve
* [START] CICS TS 6.x, EXEC CICS START (INTERVAL, FROM / LENGTH): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-start
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (ENDDATA 29): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [SET5] Enterprise COBOL for z/OS 6.3 Language Reference, Format 5: SET for USAGE IS POINTER data items: https://www.ibm.com/docs/SS6SG3_6.3.0/lr/ref/rlpssete.html
