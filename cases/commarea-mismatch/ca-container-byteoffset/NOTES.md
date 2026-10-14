# ca-container-byteoffset: reading a container from an offset

## The trap

`GET CONTAINER ... BYTEOFFSET` returns a container's data starting at an offset, not at byte
zero. `CABOFF` (transaction `CA09`) puts a 10-byte BIT container `DATA` (`ABCDEFGHIJ`, EBCDIC)
in channel `BOCHAN` and reads it with an `INTO` area of 16 bytes and `FLENGTH` 16 (a maximum, see
below) at several offsets. `CABOFFX` (`CA0A`) reads at and past the end. The bytes each GET
returns go to TS queue `BORAW` (as hex, exactly `FLENGTH` bytes), what each command returned
(tag, RESP, RESP2, FLENGTH) goes to `BOLOG` (copybook `CCLOG`, 31 bytes). Containers are not
events (SPEC 6.2).

The container is BIT, so no code page conversion applies and the offset is a plain byte offset
(for CHAR, IBM counts it in the requested code page).

## Why a naive translation breaks

* A port that ignores BYTEOFFSET returns byte zero onward every time.
* A port that leaves FLENGTH as the requested 16, rather than the length returned, writes the
  wrong number of bytes (`GET2`, `GET4`).
* A port that treats FLENGTH as an exact length, or a too-long FLENGTH as an error, fails
  `GET4`: IBM caps the length at the container length minus the offset.
* A port that clamps an offset at or past the end to an empty NORMAL read (or throws a Java
  index exception) hides LENGERR RESP2 12.
* A port that rejects or wraps a negative offset gets `GET5` wrong.
* A port that makes PREPEND a no-op, or an APPEND, changes what offset 0 and 10 read.

## Expected behaviour

### `read` (`CA09`, `CABOFF`)

1. `PUT CONTAINER('DATA') CHANNEL(BOCHAN) FROM(10 bytes) BIT`: the channel is created [PUT].
   NORMAL.
2. `BYTEOFFSET(0)`: "The data returned begins at the offset specified by the BYTEOFFSET
   value"; "On output ... CICS sets the data area to the length of the data returned" [GET].
   All 10 bytes, FLENGTH 10 (`GET1`).
3. `BYTEOFFSET(3)`: `DEFGHIJ`, FLENGTH 7. `BYTEOFFSET(9)`: `J`, FLENGTH 1.
4. `BYTEOFFSET(7)`, FLENGTH 16: "The maximum length returned is equal to the length of the data
   in the container minus the BYTEOFFSET value" [GET]: `HIJ`, FLENGTH 3, NORMAL. The 16-byte
   area is not shorter than the container, so RESP2 11 does not apply.
5. `BYTEOFFSET(-1)`: "If the value specified is less than zero, zero is assumed" [GET]: all
   10 bytes, FLENGTH 10.
6. `PUT CONTAINER('DATA') FROM('XY') BIT PREPEND`: "the data passed to the container is
   prepended to the existing data in the container" [PUT]: the container is `XYABCDEFGHIJ`.
7. `BYTEOFFSET(0)`: all 12 bytes (`E7E8` then the 10). `BYTEOFFSET(10)`: `IJ` (`C9D1`), FLENGTH 2:
   offset 10 was past the end of the 10-byte container and is now inside the 12-byte one.
8. `RETURN` at level 1.

### `past-end` (`CA0A`, `CABOFFX`)

1. `PUT` of the 10-byte BIT container; NORMAL.
2. `BYTEOFFSET(9)`: the last byte, `J`, FLENGTH 1, NORMAL.
3. `BYTEOFFSET(10)`, the container length: LENGERR (22) RESP2 12, "The offset is greater than, or
   equal to, the length of the container" [GET] [RESP-CODES]. FLENGTH and the area are not logged.
4. `BYTEOFFSET(15)`, past the end: LENGERR RESP2 12 again.
5. `BYTEOFFSET(0)`: all 10 bytes, FLENGTH 10; the failed reads did not change the container.

## What a correct port must do

* Return data from the offset, set FLENGTH to the length returned (at most container length
  minus offset, at most the FLENGTH given), and treat a negative offset as 0.
* Raise LENGERR RESP2 12 for an offset greater than or equal to the container length.
* Make PREPEND put the new data in front of the old, so later offsets see the new layout.

## Avoided ambiguities

* **FLENGTH smaller than what is left.** Every read gives FLENGTH 16, at least what remains,
  so the "area shorter than the data" truncation (LENGERR RESP2 11) and what FLENGTH holds
  after it, with a BYTEOFFSET, never arise.
* **FLENGTH and the area after LENGERR 12.** Not logged; the page states FLENGTH per option,
  not per condition. No `BORAW` write follows a condition.
* **Bytes of the INTO area beyond the length returned.** Only `FLENGTH` bytes are written to
  `BORAW` (`WRITEQ TS ... LENGTH`).
* **CHAR containers and CCSIDs.** The container is BIT, so no conversion, and the offset is
  never in a converted code page.
* **DATATYPE on PREPEND.** The container is BIT and the PREPEND names BIT, the type it already
  has ("its data type was established when it was created and cannot be changed" [PUT]).
* **PREPEND release.** PREPEND is documented as "6.2 and later" [PUT]; the case needs a 6.2+
  region. APPEND is covered by ca-channel-containers and is not repeated.
* **The unhandled LENGERR.** Every GET uses RESP, so the default action is never reached.

## Citations

* [GET] CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (BYTEOFFSET: "Specifies, as a fullword binary value, the offset in bytes where the data returned starts" and "If the value specified is less than zero, zero is assumed"; FLENGTH with BYTEOFFSET: "On input, FLENGTH specifies the maximum length of the data that the program accepts", "The data returned begins at the offset specified by the BYTEOFFSET value", "On output ... CICS sets the data area to the length of the data returned", "The maximum length returned is equal to the length of the data in the container minus the BYTEOFFSET value"; LENGERR RESP2 11 and 12 "The offset is greater than, or equal to, the length of the container"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [PUT] CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL) (BIT; PREPEND "6.2 and later": "Specifies that the data passed to the container is prepended to the existing data in the container"; "If the container exists, its data type was established when it was created and cannot be changed"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (LENGERR 22): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
