# hc-run-channel: RUN TRANSID CHANNEL, the child's copy of a channel, a channel that does not exist, and an unacceptable name

## The trap

HCRP (HCRPAR) reads its mode from the terminal input (`HCRP C`, `N`, `B`). It logs 45-byte records to TS queue HCRLOG
(`LG-WHO` `P`, the channel name, RESP and RESP2 as three digits each, a five-digit length, 16 bytes of data). HCRD
(HCRCHD), the RUN TRANSID child, logs the same record (`LG-WHO` `C`) to TS queue HCRCLOG: the name `ASSIGN CHANNEL`
gives it and what `GET CONTAINER('PAYLOAD')` returns on its current channel. A channel's name and a container are not
SPEC events, so what the child received is observed through these records, as in `hc-fetch-child`.

* `C`: `PUT CONTAINER('PAYLOAD') CHANNEL('HCRCHAN') FROM('ORDER-0042')`, then `RUN TRANSID('HCRD') CHILD() CHANNEL('HCRCHAN')`,
  then `PUT CONTAINER('PAYLOAD')` again with `CHANGED-01`, `FETCH CHILD` (waits for the child), then `GET CONTAINER('PAYLOAD')`
  on the parent's own channel.
* `N`: `RUN TRANSID('HCRD') CHANNEL('HCRNEW')`, a channel that was never created; `FETCH CHILD`.
* `B`: `RUN TRANSID('HCRD') CHANNEL('BAD*NAME') RESP RESP2`.

## Why a naive translation breaks

* A port that hands the child the parent's channel (a reference, not a copy) lets the child read `CHANGED-01` in `C`:
  the child's record shows `CHANGED-01` instead of `ORDER-0042`.
* A port that ignores CHANNEL on RUN (the child starts with no channel) gets `C` and `N` wrong: the child's `ASSIGN
  CHANNEL` is blank and its GET is INVREQ RESP2 4, not the channel's name and a value or CONTAINERERR.
* A port that refuses a channel it does not know (CHANNELERR in `N`) gets `N` wrong: IBM creates it.
* A port that accepts any name in `B` runs the child; IBM refuses the RUN (CHANNELERR RESP2 1) and no task 2 exists.

## Expected behaviour

Model (SPEC sections 2 and 4): one region, terminal T001, clock 2026-03-02T10:00:00. Each scenario is one operator step
(`HCRP <mode>`) at time 0. The parent is task 1; the child, when there is one, is task 2 with trigger `{"kind": "run",
"task": 1, "event": 1}` (the RUN is the parent's second event, after the RECEIVE).

* **`copy-at-run`** (`C`): the channel is created by the first PUT [PUT]. "The child task is given a _copy_ of the
  channel's containers (and the data that they contain)." and "The copy is made when the RUN TRANSID command is issued."
  [RUN-TRANSID]. The second PUT replaces the parent's PAYLOAD (no APPEND) after the copy was made, so the child's
  `GET CONTAINER('PAYLOAD')` on its current channel reads the value the RUN copied: `C HCRCHAN         000000 00010 ORDER-0042`
  (`ASSIGN CHANNEL` gives the child the name of the channel it was given, [ASSIGN] [RUN-TRANSID]). FETCH CHILD returns
  when the child is complete [FETCH-CHILD]. The parent's own channel holds its latest value:
  `P HCRCHAN         000000 00010 CHANGED-01` [GET].
* **`new-channel`** (`N`): "If the channel does not exist, it is created." [RUN-TRANSID] and "Name a channel that does not
  currently exist. A new empty channel is created." [RUN-TRANSID]. The child's current channel is HCRNEW and it holds no
  container: `GET CONTAINER('PAYLOAD')` is CONTAINERERR (110) with RESP2 10, "The container named on the CONTAINER option
  could not be found" [GET] [RESP-CODES]. The child logs `C HCRNEW          110010 00000` and blanks.
* **`bad-name`** (`B`): the acceptable characters are `A-Z a-z 0-9 $ @ # ./-\_ % & ? ! : | " = ¬ , ; < >` [RUN-TRANSID]:
  `*` is not among them. CHANNELERR RESP2 1: "The channel specified on the CHANNEL option contains an incorrect character or
  combination of characters." [RUN-TRANSID]. DFHRESP(CHANNELERR) = 122 [RESP-CODES]. The RUN event has `resp`
  CHANNELERR and `resp2` 1; the request is refused, so no child task exists and the parent logs
  `P BAD*NAME         122001 00000` and blanks.

## What a correct port must do

* Give the child its own copy of the named channel's containers as they stand when the RUN is issued; a later PUT by
  the parent is invisible to it.
* Make the named channel the child's current channel (a channel that does not exist is created empty).
* Return CHANNELERR RESP2 1 from RUN for a name with a character outside IBM's list, and start no child.

## Avoided ambiguities

* IBM does not say whether a container the child PUTs on its copy reaches the parent. The child here only reads, and the
  parent never reads what the child could have written. Reply channels are not used: FETCH CHILD CHANNEL (the reply channel,
  a name CICS generates) is left out.
* The name check uses `*`, a character absent from IBM's list of acceptable characters. Blanks (the page says leading and
  embedded blanks are not permitted) and the portability advice for names shipped between regions are not used.
* Where the child runs relative to the parent's second PUT is not observable: the copy was made at the RUN and the child
  logs only to its own queue (SPEC section 3 keeps a child's order against its parent unobservable). The parent's FETCH CHILD
  waits, so both queues are complete when the task ends.
* `DFHTRANSACTION`, `NOSTART`, `DISABLED`, `NOTAUTH` and `TRANSIDERR` are not used.
* CVDA values are not read: COMPSTATUS and ABCODE are fetched only to complete the FETCH.

## Citations

* [RUN-TRANSID] IBM CICS TS for z/OS 6.x (page header "CICS Transaction Server for z/OS 6.x"; the 6.x page names no minor
  release), EXEC CICS RUN TRANSID, CHANNEL, CHILD and Conditions (CHANNELERR RESP2 1), read 2026-11-10:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-run-transid
* [FETCH-CHILD] IBM CICS TS 6.x, EXEC CICS FETCH CHILD ("FETCH CHILD will return when the child task is completed."):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-fetch-child
* [PUT] IBM CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [GET] IBM CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (CONTAINERERR RESP2 10): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [ASSIGN] IBM CICS TS 6.x, EXEC CICS ASSIGN (CHANNEL: "the 16-character name of the current channel of the program, if one exists; otherwise, blanks"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
* [RESP-CODES] IBM CICS TS 6.x, Response codes of EXEC CICS commands (CONTAINERERR 110, CHANNELERR 122): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
