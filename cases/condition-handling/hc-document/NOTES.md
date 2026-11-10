# hc-document: DOCUMENT CREATE and DOCUMENT RETRIEVE with RESP

## The trap

`HCDOCU` (transaction `HC95`) creates two documents from `TEXT`, then retrieves each by its own `DOCTOKEN`, logging to
TS queue `HCLOG` (DOCUMENT is not an event, SPEC 6.2). Items: `C1 R=00` (tag, ` R=`, RESP: 7 bytes) and
`R1 L=0012 ORDER 000417` (tag, ` L=`, LENGTH after the retrieve, space, first 12 bytes of the INTO area: 22 bytes).

* **C1** `DOCUMENT CREATE DOCTOKEN(..) TEXT(..) LENGTH(12)`: document A, `ORDER 000417`.
* **C2** the same for document B, `SHIPPED 9` (9 bytes), with `DOCSIZE(..)` (the value is not logged).
* **R1** `DOCUMENT RETRIEVE DOCTOKEN(A) INTO(..) LENGTH(..) MAXLENGTH(40)`, issued after B was created.
* **R2** the same for B.

## Why a naive translation breaks

* A port that keeps one "current document" instead of one per token returns B's text at R1 (the token is what selects
  the document, not the last CREATE).
* A port that leaves LENGTH as the INTO area size (40) instead of the length of the data returned fails both R items.
* A port that rejects `DOCSIZE` on CREATE, or `MAXLENGTH` with `INTO`, fails C2 or the retrieves.

## Expected behaviour

* [CREATE] Each CREATE builds a document from the `TEXT` data of `LENGTH` bytes and returns a token that identifies it
  in `DOCTOKEN`. Both are NORMAL: `C1 R=00`, `C2 R=00`.
* [RETRIEVE] Each RETRIEVE copies the document identified by `DOCTOKEN` into `INTO`, and `LENGTH` is set to the length
  of the data returned. The documents hold plain ASCII-range text with no conversion-sensitive characters, so the bytes
  come back as written. A: `L=0012`, `ORDER 000417`. B: `L=0009`, `SHIPPED 9` (the area was cleared to spaces, so the
  12 logged bytes are `SHIPPED 9` and three spaces).
* The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Keep each document under its own token, return LENGTH as the data length, accept DOCSIZE and MAXLENGTH, write the six
  items in order, send `DONE OK` and RETURN.

## Avoided ambiguities

* **DOCSIZE's value:** accepted but never logged (whether it counts only the text or any control information is not
  relied on).
* **TEMPLATE, SYMBOLLIST, DELIMITER, BINARY, DATAONLY, HOSTCODEPAGE, CHARACTERSET:** not used. Templates need DOCTEMPLATE
  definitions, and code-page conversion depends on the region's host code page.
* **Failure paths** (a MAXLENGTH below the document length, an invalid DOCTOKEN, INVREQ, LENGERR): not used; each would
  need an event row SPEC 6.2 does not have, and some RESP2 values are not documented.
* **The token's value, DOCUMENT INSERT / SET, and a document outliving the task:** not read.
* The documents are never freed; the case does not read what task end does with them.

## Citations

* [CREATE] CICS TS 6.x, EXEC CICS DOCUMENT CREATE (DOCTOKEN, TEXT, LENGTH, DOCSIZE, conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-document-create
* [RETRIEVE] CICS TS 6.x, EXEC CICS DOCUMENT RETRIEVE (DOCTOKEN, INTO, LENGTH, MAXLENGTH, conditions):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-document-retrieve
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
