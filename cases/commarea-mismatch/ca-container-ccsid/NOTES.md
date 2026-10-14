# ca-container-ccsid: character conversion of a container

## The trap

A CHAR container is character data that CICS converts between code pages. `CACCSID`
(transaction `CA07`) puts three CHAR containers in channel `CCCHAN` and gets each back in
different CCSIDs:

* `ONE`: `ABC123` put with `FROMCCSID(037)`, got with `INTOCCSID(1208)`, `INTOCCSID(037)` and
  no INTOCCSID.
* `TWO`: the ASCII bytes `X'414243313233'` put with `FROMCCSID(1208)`, got the same three ways.
* `THREE`: `ABC123` put with `DATATYPE(CHAR)` and no CCSID, got with `INTOCCSID(1208)`.

It first issues a GET with `INTOCCSID` and no channel at all. The bytes each GET returns go to
TS queue `CCRAW` (as hex: the 1208 bytes are not EBCDIC text); what each command returned (tag,
RESP, RESP2, FLENGTH) goes to `CCLOG` (copybook `CCLOG`, 31 bytes). Containers are not events
(SPEC 6.2).

`CACCBIT` (`CA08`) puts a BIT container, gets it with INTOCCSID (a condition) and without, and
puts a BIT container with `FROMCCSID` (INVREQ).

Every text is `ABC123`: letters and digits are the same characters in 037 and 1208, so the
only change is the byte values, and the length stays 6.

## Why a naive translation breaks

* A port that keeps a container as a Java String (or any decoded text) cannot say which bytes
  a GET returns: the program asks for EBCDIC bytes or UTF-8 bytes of the same text, and the
  area it gets is bytes.
* A port that ignores INTOCCSID returns the put bytes in every case, wrong for `GET1`,
  `GET4`, `GET6`, `GET7`.
* A port that always converts to a default (UTF-8) returns ASCII for a GET with no INTOCCSID,
  where IBM says the default is the region's CCSID.
* A port that converts a BIT container, or does not raise CCSIDERR for INTOCCSID on one,
  hides data that the program put as raw bytes.

## Expected behaviour

### `convert` (`CA07`, `CACCSID`)

1. `GET CONTAINER('ONE') INTO FLENGTH INTOCCSID(1208)` with no CHANNEL, and no current channel
   (a terminal task): INVREQ RESP2 2, "INTOCCSID is valid only on GET CONTAINER commands that
   specify (explicitly or implicitly) a channel" [GET]. `GET0 016 002`.
2. `PUT CONTAINER('ONE') CHANNEL(CCCHAN) FROM(WS-SRC) FROMCCSID(37)`: the channel is created
   [PUT]; "If the FROMCCSID option is specified, DATATYPE(DFHVALUE(CHAR)) is implied" [PUT].
3. `GET ... INTOCCSID(1208)`: the character data "is converted" into CCSID 1208 [GET]:
   `X'414243313233'`, FLENGTH 6.
4. `GET ... INTOCCSID(037)`: the CCSID it was put in: `X'C1C2C3F1F2F3'`.
5. `GET ...` with no INTOCCSID: "the value for conversion defaults to the CCSID of the region"
   [GET], 037 (SPEC 2): `X'C1C2C3F1F2F3'`.
6. `PUT CONTAINER('TWO') FROM(WS-ASC) FROMCCSID(1208)`: the data is stored as CCSID 1208.
7. `GET TWO INTOCCSID(1208)`: `X'414243313233'`, as put. `INTOCCSID(037)` and no INTOCCSID
   (region, 037): `X'C1C2C3F1F2F3'`.
8. `PUT CONTAINER('THREE') FROM(WS-SRC) DATATYPE(CHAR)`: "If the FROMCCSID and FROMCODEPAGE
   options are not specified, it is assumed that the data is encoded in the CCSID of the
   region" [PUT]. `GET THREE INTOCCSID(1208)`: `X'414243313233'`.
9. `RETURN` at level 1.

### `bit-container` (`CA08`, `CACCBIT`)

1. `PUT CONTAINER('RAWB') ... BIT` from `ABC123` (EBCDIC): "Bit data. The data in the container
   cannot be converted" [PUT]. NORMAL.
2. `GET ... INTOCCSID(1208)`: CCSIDERR (123) RESP2 3, "The data was created with a data type of
   BIT. Code page conversion is not possible", and "the data was returned without any code page
   conversion" [GET] [RESP-CODES]: the area holds `X'C1C2C3F1F2F3'`. FLENGTH is not logged.
3. `GET ...` with no INTOCCSID: nothing to convert, NORMAL, the same bytes.
4. `PUT CONTAINER('BADB') ... BIT FROMCCSID(37)`: INVREQ (16) RESP2 34, "A data-type of BIT is
   invalid with the FROMCCSID option" [PUT]. The container `BADB` is never read.

## What a correct port must do

* Store container data as bytes plus a CCSID (for CHAR) or as raw bytes (BIT).
* Convert on GET to INTOCCSID, defaulting to the region's CCSID (037), and on PUT from
  FROMCCSID, defaulting to the region's.
* Raise CCSIDERR RESP2 3 for INTOCCSID on a BIT container, returning the bytes unconverted;
  INVREQ RESP2 2 for INTOCCSID with no channel; INVREQ RESP2 34 for BIT with FROMCCSID.

## Avoided ambiguities

* **Characters that differ between code pages.** Only `A-Z` and `0-9`, so conversion is a
  byte-for-byte mapping and CCSIDERR RESP2 4 (an unconvertible character) cannot arise.
* **Other CCSIDs and CODEPAGE options.** Only 037 and 1208 (the 037 to 1208 pair IBM's pages
  use); no FROMCODEPAGE / INTOCODEPAGE; no invalid CCSID (RESP2 1) or unsupported pair (RESP2 2),
  whose valid ranges the pages do not list.
* **FLENGTH after a condition.** `GET0` and the BIT `GET1` do not log FLENGTH: IBM states it
  for the option, not per condition (README confidence table, as for ca-channel-containers).
* **Whether the INTO area is filled on a CCSIDERR.** Only the "data was returned without any
  conversion" sentence says so; the log reads that sentence (README confidence table).
* **A container after a failed PUT.** `BADB` is not read, so whether INVREQ RESP2 34 leaves it
  created does not matter.
* **Changing a container's CCSID or data type.** Every container is put once.
* **The unhandled CCSIDERR.** Every GET uses RESP, so the default action is never reached.

## Citations

* [PUT] CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL) (DATATYPE CHAR / BIT; FROMCCSID implies CHAR; INVREQ RESP2 34): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [GET] CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (INTOCCSID, its default; CCSIDERR RESP2 3; INVREQ RESP2 2): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, CCSIDERR 123): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
