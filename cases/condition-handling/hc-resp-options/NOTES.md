# hc-resp-options: RESP on FORMATTIME, ASKTIME NOHANDLE, READQ TS LENGTH(LENGTH OF), RECEIVE MAP ASIS

## The trap

`HCOPT` (transactions `HC51`, `HC52`) is typed with a mode after `HC51` and logs what each command did to TS queue `HCLOG`
(ASKTIME and FORMATTIME are not events, SPEC 6.2):

* **F** issues `EXEC CICS ASKTIME NOHANDLE` (no `ABSTIME`: the command only refreshes EIBDATE and EIBTIME), then
  `ASKTIME ABSTIME(area) NOHANDLE`, then `FORMATTIME ABSTIME(area) DDMMYYYY(..) DATESEP('/') TIME(..) TIMESEP(':')
  RESP(..) RESP2(..)`, and the same FORMATTIME after `MOVE -1` to the (packed) ABSTIME. Item format: tag (3), the date (10),
  a blank, the time (8), ` R=`, RESP (2), ` 2=`, RESP2 (2, `--` for the NORMAL one): 32 bytes.
* **Q** writes a 20-byte item and a 12-byte item to queue `HCQ`, then reads each with
  `READQ TS ... INTO(12-byte area) LENGTH(LENGTH OF area) ITEM(n) RESP(..)`. Item format: tag (3), the area (12), ` R=`,
  RESP (2): 20 bytes. (`LENGTH OF` is a compile-time constant, not a data area: the program cannot receive the length
  back.)
* **A** (`HC51 A`) sends map `HCM1` and RETURNs `TRANSID('HC52')`; the operator types `Mixed cAsE` in the field `NAME`;
  `HC52` issues `RECEIVE MAP('HCM1') MAPSET('HCSET1') INTO(..) ASIS` and logs the field. Item: tag (3), the field (12).

## Why a naive translation breaks

* A port that ignores `RESP` on FORMATTIME, or formats a negative ABSTIME, never reports INVREQ RESP2 1.
* A port that treats `NOHANDLE` after `ASKTIME` as part of the verb (`ASKTIME NOHANDLE`), or insists on `ABSTIME`, cannot
  translate the command at all.
* A port that moves the length CICS returns into `LENGTH OF area` does not compile, and one that sizes the read by anything
  but the area truncates wrongly or not at all: the 20-byte item must be cut to 12 bytes with LENGERR, the 12-byte one read
  whole.
* A port that upper-cases the received field (the terminal is `UCTRAN(YES)`) turns `Mixed cAsE` into `MIXED CASE`: ASIS says
  lower case is not translated.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display whose TYPETERM `CRU3278` says `UCTRAN(YES)`. A task takes zero
time, so ASKTIME returns the virtual time at which the task was dispatched. Every scenario starts at 10:00:00 on
2026-03-02 with `HC51 <mode>` typed on T001. The code page is EBCDIC CCSID 037.

* **`formattime`** (F):
  * ASKTIME returns 2026-03-02 10:00:00 as milliseconds since 1900-01-01 (SPEC 4; IBM, ABSTIME: "the number of
    milliseconds since 00:00 on 1 January 1900" [ASKTIME]). ASKTIME without ABSTIME "updates the date (EIBDATE) and ...
    time-of-day clock (EIBTIME) fields in the EIB" [ASKTIME] and raises no condition (the page lists none, so NOHANDLE has
    nothing to suppress).
  * F1: `DDMMYYYY` with `DATESEP('/')` is `02/03/2026`, `TIME` with `TIMESEP(':')` is `10:00:00` [FORMATTIME]. RESP NORMAL
    (0). Item: `F1 02/03/2026 10:00:00 R=00 2=--`.
  * F2: ABSTIME -1: "INVREQ ... RESP2 1: The ABSTIME value is less than zero or not in packed-decimal format"
    [FORMATTIME]. INVREQ is 16 [RESP-CODES]. RESP is given, so no abend. The output areas are not read afterwards
    (IBM does not say whether they are left alone); the program blanks the logged copies. Item:
    `F2 ` + 19 blanks + ` R=16 2=01`.
  * The program sends `DONE OK` and RETURNs.
* **`readq-length`** (Q): items 1 (`ABCDEFGHIJKLMNOPQRST`, 20 bytes) and 2 (`abcdefghijkl`, 12) go to `HCQ`.
  * Q1: `LENGTH(LENGTH OF WS-SMALL)` is 12: "If you specify INTO, LENGTH defines the maximum length of data that the
    program accepts ... If the length of the data exceeds the value that is specified, the data is truncated to that value
    and the LENGERR condition occurs. On completion of the retrieval operation, the data area is set to the original
    length of the data record" [READQ-TS]: `ABCDEFGHIJKL` is stored, LENGERR (22 [RESP-CODES]), the length is 20. The READQ-TS
    event carries `length` 20. Item: `Q1 ABCDEFGHIJKL R=22`.
  * Q2: item 2 is 12 bytes, not more than 12: NORMAL, the whole item, length 12. Item: `Q2 abcdefghijkl R=00`.
  * The program sends `DONE OK` and RETURNs.
* **`asis`** (A): task 1 sends `HCM1` (the field `NAME` is `ATTRB=(UNPROT,NORM,IC,FSET)`: attribute X'C1', SPEC 6.3) and
  RETURNs `TRANSID('HC52')`. At 10 s the operator types `Mixed cAsE` and presses ENTER. Task 2 (`HC52`) RECEIVEs the map
  `ASIS`: "lowercase characters in the 3270 input data stream are not translated to uppercase" [RECEIVE-MAP], so the field
  is `Mixed cAsE` (12 bytes, blank padded). Item: `A1 Mixed cAsE  `.

## What a correct port must do

* Honour `RESP` / `RESP2` on FORMATTIME with INVREQ RESP2 1 for an ABSTIME below zero.
* Accept `NOHANDLE` after ASKTIME, and ASKTIME without ABSTIME.
* Treat `LENGTH(LENGTH OF area)` as the number of bytes READQ TS takes (item longer: truncated with LENGERR; shorter or equal:
  whole), and not try to store a length back into it.
* Deliver RECEIVE MAP ... ASIS input as typed.

## Avoided ambiguities

* **The output areas of a FORMATTIME that raised INVREQ**: IBM does not say; the program does not read them.
* **"Not in packed-decimal format"**: the ABSTIME field is `PIC S9(15) COMP-3`, always valid packed decimal.
* **The cursor after a LENGERR READQ**: items are read by explicit ITEM number.
* **What a RECEIVE MAP without ASIS does** on this terminal (upper-case translation of what was typed depends on the
  terminal's UCTRAN, INQUIRE TERMINAL says so): no scenario reads without ASIS.
* **EIBDATE / EIBTIME after ASKTIME**: nothing here reads them (the virtual clock does not move, SPEC 4).
* **STRINGFORMAT** (FORMATTIME INVREQ RESP2 2) is not used.
* **A FORMATTIME with an ABSTIME below zero and no RESP** (INVREQ's default action, abend AEIP, or a HANDLE CONDITION label): no scenario issues it.

## Citations

* [FORMATTIME] CICS TS 6.x, EXEC CICS FORMATTIME (DDMMYYYY, DATESEP, TIME, TIMESEP, INVREQ RESP2 1 and 2):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-formattime
* [ASKTIME] CICS TS 6.x, EXEC CICS ASKTIME (ABSTIME, EIBDATE / EIBTIME, NOHANDLE as a common option):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-asktime
* [READQ-TS] CICS TS 6.x, EXEC CICS READQ TS (INTO, LENGTH, ITEM, LENGERR):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-readq-ts
* [RECEIVE-MAP] CICS TS 6.x, EXEC CICS RECEIVE MAP (ASIS):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-receive-map
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, LENGERR 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
