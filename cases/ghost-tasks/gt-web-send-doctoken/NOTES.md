# gt-web-send-doctoken: server WEB SEND DOCTOKEN and DOCSTATUS

The `DOCTOKEN` form of the server `WEB SEND` of `gt-web-server-send`: the response body is a CICS document, not a `FROM` area. Peer model
and request keys as `gt-http-inbound` (SPEC sections 2, 4, 5 and 6).

## The trap

`GTWDOCS` is the program of SERVER URIMAP `DOCURI` (`HOST(*) PATH(/gt/doc)`, alias transaction `GT88`). For each request it `WEB READ
HTTPHEADER`s `X-Crucible-Mode`, `DOCUMENT CREATE`s a document from `TEXT` (the text and its length differ per mode), and `WEB SEND`s it
with `DOCTOKEN` and no `FROM`. The `DOCSTATUS` differs per mode. After the send it `DOCUMENT RETRIEVE`s the same token and writes the RESP
to TS queue `GTDOCLOG` (`DOCUMENT` is not an event, SPEC 6.2), so whether the document outlived the send is observable.

One scenario, **`send`** (`client-a`), three `GET`s at 10:00:00, :05 and :10:

| Request | Mode | Document text | Length | DOCSTATUS | Media type | Retrieve after the send |
|---|---|---|---|---|---|---|
| 0 | `1` | `alpha=111` | 9 | not given | `text/plain` | NORMAL (`M1 R=00`) |
| 1 | `2` | `<b>bravo</b>` | 12 | `DOCDELETE` | `text/xml` | NOTFND (`M2 R=13`) |
| 2 | `3` | `c=3` | 3 | `NODOCDELETE` | `text/plain` | NORMAL (`M3 R=00`) |

## Why a naive translation breaks

* Sending nothing, or a stale `FROM` area, for a `DOCTOKEN` send: the body is the document's bytes, and its length is the document's
  length (9, 12, 3), not a program field's.
* Deleting the document on every send, or on none: only `DOCDELETE` deletes it, the default and `NODOCDELETE` keep it.
* Not honouring the delete: after `DOCDELETE` a later use of the token is NOTFND.

## Expected behaviour

Model: as `gt-http-inbound`: the CSD is installed, the clock is 2026-03-02T10:00:00, a task takes no time, each request starts its own
`GT88` task with no terminal and no EIBAID, and a `GET` has no body.

* **`WEB SEND DOCTOKEN`** is NORMAL, status 200, text `OK`. DOCTOKEN "Specifies the 16-byte binary token of a document to be sent as the
  message body" [WEBSEND]. The `WEB-SEND` event's `from` is therefore the document's bytes, and `from.length` is the document's length
  (SPEC section 6, `WEB-SEND`: additive clarification made with this case); the peer's stated `body` repeats them.
* **DOCSTATUS.** DOCDELETE: "CICS deletes the document after the document contents are saved for sending ... If you make subsequent
  requests for the document, these generate a NOTFND response". NODOCDELETE: "CICS does not delete the document during processing of the
  WEB SEND command. This is the default value for DOCSTATUS" [WEBSEND]. So `DOCUMENT RETRIEVE` after the send is NORMAL in modes 1 and 3
  and NOTFND (RESP 13) in mode 2. The log item is `M<mode> R=<RESP>`, one item per task in order (items 1, 2, 3).
* The `DOCUMENT RETRIEVE` finds the document's bytes unchanged in the NORMAL cases; the program logs only the RESP.

The peer script is in `case.json` (`peers`); the validator checks the `WEB-SEND` against it. Logs: `expected/*.json`.

## What a correct port must do

* Send the bytes of the document named by `DOCTOKEN` as the response body, with the given status, text and media type.
* Delete the document only for `DOCSTATUS(DOCDELETE)`, so a later `DOCUMENT RETRIEVE` of it is NOTFND; keep it otherwise.

## Avoided ambiguities

* **An invalid or deleted token on `WEB SEND`.** IBM lists NOTFND RESP2 1 ("The document has not been created, or has been deleted, or the
  name is incorrectly specified" [WEBSEND]), but the failed send would be the only `WEB SEND` of an http task with nothing delivered to the
  peer, which section 2 does not model; the NOTFND is shown on `DOCUMENT RETRIEVE` instead, from the page's own sentence. The RESP2 of that
  `DOCUMENT RETRIEVE` is not asserted.
* **`FROM` together with `DOCTOKEN`.** IBM calls FROM "an alternative way to create a message body" and states no error for both: never
  used.
* **Code page.** `SRVCONVERT` with `CHARACTERSET('iso-8859-1')` is stated and `HOSTCODEPAGE` is not: "If a CICS document is used to form
  the response body (DOCTOKEN option), do not specify the HOSTCODEPAGE option, because CICS identifies the host code page from the CICS
  document domain's record" [WEBSEND]. The host code page of the document is the region's, as for `gt-http-inbound` (037); the document
  texts are plain ASCII-range characters.
* **Chunking.** `CHUNKING` cannot be used with `DOCTOKEN` [WEBSEND]: not used.
* **`ACTION`.** Every send says `ACTION(IMMEDIATE)`, as `gt-web-server-send`.
* **DOCUMENT INSERT / SET, templates, document size limits:** not used. The token's value is not shown.
* **Headers.** No `WEB WRITE HTTPHEADER`: the peer's responses state no `headers`.

## Citations

* [WEBSEND] IBM CICS TS 6.x, EXEC CICS WEB SEND (server): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-send-server
  (DOCTOKEN, DOCSTATUS DOCDELETE / NODOCDELETE, HOSTCODEPAGE with DOCTOKEN, CHUNKING, NOTFND RESP2 1; read 2026-11-11).
* [WEBRHDR] IBM CICS TS 6.x, EXEC CICS WEB READ HTTPHEADER: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-web-read-httpheader
  (the request header `X-Crucible-Mode`).
* [DOCCREATE] IBM CICS TS 6.x, EXEC CICS DOCUMENT CREATE and DOCUMENT RETRIEVE: as `hc-document`.
* [URIMAP]: as `gt-http-inbound`.
