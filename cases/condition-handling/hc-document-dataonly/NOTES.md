# hc-document-dataonly: DOCUMENT RETRIEVE with DATAONLY, RESP and RESP2

## The trap

`HCDOCD` (transaction `HC89`) creates two documents from `TEXT`, then retrieves them with `DOCUMENT RETRIEVE ... DATAONLY`,
each command with `RESP` and `RESP2`, and logs to TS queue `HCLOG` (DOCUMENT is not an event, SPEC 6.2). Items are
`D1 R=00 E=00 L=0012` (tag, ` R=` RESP, ` E=` RESP2, ` L=` LENGTH after the command: 19 bytes) and
`D1 D=ORDER 000417` (tag, ` D=`, the first 12 bytes of the INTO area: 17 bytes). `LENGTH` is preset to 77 before every
retrieve, so an unset LENGTH shows.

* **D1** document A (`ORDER 000417`, 12 bytes) into a 40-byte area, `MAXLENGTH(40)`: NORMAL, `LENGTH` 12.
* **D2** document A into a 5-byte area, `MAXLENGTH(5)`: the buffer is too short.
* **D3** document A into a 1-byte dummy area, `MAXLENGTH(0)`: the size probe IBM describes.
* **D4** document B (`SHIPPED 9`, 9 bytes), created after A, into the 40-byte area: NORMAL, `LENGTH` 9.

## Why a naive translation breaks

* A port that rejects or ignores `DATAONLY`, or that adds the bookmark / code-page tags a retrieve without it embeds,
  returns more than 12 bytes at D1.
* A port that leaves `LENGTH` at the value it held (77, or the MAXLENGTH) when the buffer is too short fails D2 and D3:
  IBM returns the exact length the whole document needs.
* A port that treats a too-short buffer as NORMAL, or abends, instead of LENGERR, fails D2 and D3 (RESP is given, so the
  task must go on).
* A port that keeps one "current document" instead of one per token returns A's text at D4.

## Expected behaviour

* [CREATE] Both CREATEs are NORMAL (no RESP is taken; a failure would surface as the default abend and the log would be
  empty).
* [DATAONLY] `DATAONLY` "specifies that the data should be retrieved without any imbedded tags", so the documents come
  back as the text they were made from. D1 `R=00 E=00 L=0012`, data `ORDER 000417`.
* [LENGERR] RESP2 2: "The length of the receiving buffer is zero, or is too short to contain the document contents. The
  document is truncated and the exact length required is returned in the LENGTH field." LENGERR is RESP 22. D2 and D3:
  `R=22 E=02 L=0012`. D3 is the sequence IBM names: "issuing a DOCUMENT RETRIEVE with a dummy buffer and a MAXLENGTH of
  zero, then handling the LENGERR condition and using the returned LENGTH value".
* [LENGTH] "If the document is truncated, this is the exact length required to return the whole document."
* D4 `R=00 E=00 L=0009`, data `SHIPPED 9` and three spaces (the area was cleared to spaces).
* The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Accept `DATAONLY`, `RESP2` and `MAXLENGTH` with `INTO`; return LENGERR RESP2 2 with the whole-document LENGTH for a
  too-short or zero-length buffer; keep each document under its own token; write the six items in order, send `DONE OK`
  and RETURN.

## Avoided ambiguities

* **What the truncated INTO holds after D2 / D3:** IBM says the document "is truncated"; the case logs neither the 5-byte
  area nor the dummy byte.
* **A retrieve without DATAONLY:** not used; the layout of the tags CICS embeds is not stated.
* **DOCSIZE, TEMPLATE, BINARY, CHARACTERSET, CLNTCODEPAGE:** not used. Code-page conversion depends on the region's host
  code page; templates need DOCTEMPLATE definitions.
* **Retrieve failures other than LENGERR** (NOTFND RESP2 1, MAXLENGTH below zero LENGERR RESP2 1, INVREQ): not used.
* **The token's value, and a document outliving the task:** not read.

## Citations

* [RETRIEVE] CICS TS 6.x, EXEC CICS DOCUMENT RETRIEVE (DATAONLY, INTO, LENGTH, MAXLENGTH, the dummy-buffer / MAXLENGTH 0
  paragraph, LENGERR RESP2 1 and 2):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-document-retrieve
* [CREATE] CICS TS 6.x, EXEC CICS DOCUMENT CREATE (DOCTOKEN, TEXT, LENGTH):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-document-create
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0, LENGERR 22):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
