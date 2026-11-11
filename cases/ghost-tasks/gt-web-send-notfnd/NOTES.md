# gt-web-send-notfnd: server WEB SEND DOCTOKEN, NOTFND RESP2 1 on the send itself

The failure sibling of `gt-web-send-doctoken`: there the NOTFND of a deleted document was shown on `DOCUMENT RETRIEVE`; here it is the
`WEB SEND DOCTOKEN` that fails. Peer model and request keys as `gt-http-inbound` (SPEC sections 2, 4, 5 and 6).

## The trap

`GTWNFS` is the program of SERVER URIMAP `NFURI` (`HOST(*) PATH(/gt/nf)`, alias transaction `GT89`). It `WEB READ HTTPHEADER`s
`X-Crucible-Mode`. Mode `1` `DOCUMENT CREATE`s a document (`alpha=111`) and `WEB SEND`s it with `DOCTOKEN`. Mode `2` skips the
`DOCUMENT CREATE` and `WEB SEND`s the still-unset `DOCTOKEN` (LOW-VALUES). On a non-NORMAL RESP it writes `M<mode> R=<RESP> E=<RESP2>` to
TS queue `GTNFLOG` and answers with `WEB SEND FROM('gone')`, status 404, `Not Found`.

One scenario, **`send`** (`client-a`), two `GET`s at 10:00:00 and :05:

| Request | Mode | Token | `WEB SEND DOCTOKEN` | Delivered to the peer |
|---|---|---|---|---|
| 0 | `1` | created document | NORMAL | 200 `OK`, `alpha=111` |
| 1 | `2` | never created | NOTFND RESP2 1 | nothing; then the fallback: 404 `Not Found`, `gone` |

## Why a naive translation breaks

* Treating a failed `WEB SEND` as the response (or delivering an empty 200): the peer must get the 404 of the second send only.
* Abending or ignoring the RESP: the NOTFND must come back to the program with RESP2 1 so it can log it and answer.
* Reporting a different RESP2: RESP2 1 is the only NOTFND code for a missing document (7 and 83 are code pages).

## Expected behaviour

Model: as `gt-http-inbound`: clock 2026-03-02T10:00:00, a task takes no time, each request starts its own `GT89` task with no terminal and
no EIBAID, a `GET` has no body.

* **Mode 1:** the `WEB-SEND` is NORMAL, `from` the document's bytes (`gt-web-send-doctoken`).
* **Mode 2:** NOTFND, RESP2 1: "The document has not been created, or has been deleted, or the name is incorrectly specified" [WEBSEND].
  The `WEB-SEND` event is `resp` NOTFND, `resp2` 1, `from` null. The log item is `M2 R=13 E=0001` (NOTFND is condition 13 [WEBSEND]).
* **Delivery.** A failed send delivers nothing; the one NORMAL `WEB-SEND` of the task is the response compared with the peer's (SPEC
  section 2, additive clarification made with this case).

## What a correct port must do

* Return NOTFND / RESP2 1 from a `WEB SEND DOCTOKEN` whose document does not exist, and send nothing to the client for it.
* Let the program issue a later `WEB SEND` that is the response.

## Avoided ambiguities

* **What reaches the client after a failed send.** [WEBSEND] states the failure, not what the client receives; for a failed *chunked*
  sequence it says "an error response is returned" without saying what. This case rests on the NOTFND being found before anything is
  sent (the token names no document), so nothing is on the wire and the second send is the first response. Listed in the README's
  lower-confidence table. RESP2 89 ("previous send ... failed", chunking) is not in play: no chunking.
* **Deleted vs never-created token.** Both are NOTFND RESP2 1 by the quoted sentence; only the never-created one is used, as a task
  has one delivered send.
* **The value of an unset token.** LOW-VALUES: "the name is incorrectly specified" [WEBSEND]; no INVREQ is asserted for it.
* **RESP2 after a NORMAL send** is not asserted. **Code page**, **chunking**, **ACTION**: as `gt-web-send-doctoken`.

## Citations

* [WEBSEND] IBM CICS TS 6.x, EXEC CICS WEB SEND (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-send-server
  (DOCTOKEN "Specifies the 16-byte binary token of a document to be sent as the message body"; Conditions: 13 NOTFND RESP2 1; read
  2026-11-11).
* [WEBRHDR] WEB READ HTTPHEADER, [DOCCREATE] DOCUMENT CREATE, [URIMAP]: as `gt-web-send-doctoken`.
