# ca-channel-browse: browse, MOVE, QUERY and DELETE a channel

## The trap

`CABROW` (transaction `CA07`) builds a channel `CABROWSEME` with three CHAR containers (`ALPHA`,
`BETA`, `GAMMA`) and then works on it only through the channel commands, always naming CHANNEL (the
terminal task has no current channel):

1. `QUERY CHANNEL` counts the containers: 3.
2. `STARTBROWSE CONTAINER`, three `GETNEXT CONTAINER` (each NORMAL), a fourth (END, RESP2 2),
   `ENDBROWSE CONTAINER`, then a `GETNEXT` and a second `ENDBROWSE` with the token the first
   `ENDBROWSE` ended (TOKENERR, RESP2 3).
3. `MOVE CONTAINER('ALPHA') AS('ALPHA2') CHANNEL('CABROWSEME') TOCHANNEL('CABMOVED')`: the target
   channel is created; the source channel keeps two containers, the target one. A second MOVE of
   `ALPHA` finds no source (CONTAINERERR, RESP2 10).
4. `DELETE CHANNEL` takes the channel and every container in it: `QUERY CHANNEL`, `GET CONTAINER`
   and a second `DELETE CHANNEL` all answer CHANNELERR RESP2 2. A `PUT CONTAINER` naming it makes a
   new channel that holds only that container (count 1; `ALPHA` is gone).

Containers are not events, so each command's RESP / RESP2 (and a count or length) is written to TS
queue `CALOG` (copybook `CALOG`, 31 bytes), as in `ca-channel-containers`.

`CABRERR` (transaction `CA08`) deletes a channel that does not exist, with neither RESP nor
HANDLE CONDITION: CHANNELERR's default action abends the task AEZV.

## Why a naive translation breaks

* A port that keeps a channel as a copy (not one shared, mutable set of containers) loses what
  MOVE and DELETE CHANNEL change; a port that forgets a deleted channel's containers returns
  `ALPHA` after the channel is re-created.
* A port that lets a browse token outlive its ENDBROWSE answers NORMAL where IBM says TOKENERR.
* A port that returns the containers in a fixed order and logs the names makes a log that only
  holds for that order: IBM calls the order undefined, so this case logs only that each of the
  three names came back once.

## Expected behaviour

### `browse-move-delete` (`CA07`)

Log text is tag, RESP (3 digits), RESP2 (3), length (5), as in the copybook; RESP 0 NORMAL, 83 END,
110 CONTAINERERR, 112 TOKENERR, 122 CHANNELERR.

1. Three `PUT CONTAINER ... CHANNEL('CABROWSEME') CHAR`: the first creates the channel [PUT]. `PUT1` `PUT2` `PUT3`, all NORMAL.
2. `QUERY CHANNEL`: CONTAINERCNT 3 [QUERY]. `QCH1`, length 3.
3. `STARTBROWSE CONTAINER CHANNEL(...)`: NORMAL [START]. `SBR1`.
4. Three `GETNEXT CONTAINER`: NORMAL each, one name per call, order undefined [NEXT]. `GNX1` `GNX2` `GNX3`;
   `NAMS` logs 3, the number of distinct names among ALPHA / BETA / GAMMA the three returned.
5. A fourth `GETNEXT`: END, RESP2 2 [NEXT]. `GNX4`, RESP 083 RESP2 002.
6. `ENDBROWSE CONTAINER`: NORMAL [END]. `EBR1`.
7. `GETNEXT` with that token: TOKENERR, RESP2 3 [NEXT]. `GNX5`, 112 / 003.
8. `ENDBROWSE CONTAINER` again: TOKENERR, RESP2 3 [END]. `EBR2`, 112 / 003.
9. `MOVE CONTAINER('ALPHA') AS('ALPHA2') CHANNEL('CABROWSEME') TOCHANNEL('CABMOVED')`: NORMAL, CABMOVED created [MOVE]. `MOV1`.
10. `QUERY CHANNEL` of the source: 2 [MOVE]. `QCH2`. Of the target: 1. `QCH3`.
11. `GET CONTAINER('ALPHA2') CHANNEL('CABMOVED') NODATA FLENGTH`: 5 [GET]. `GET1`, length 5.
12. `GET CONTAINER('ALPHA')` in the source: CONTAINERERR, RESP2 10 [MOVE]. `GET2`, 110 / 010.
13. A second `MOVE` of `ALPHA`: CONTAINERERR, RESP2 10 [MOVE]. `MOV2`, 110 / 010.
14. `DELETE CHANNEL('CABROWSEME')`: NORMAL, its two containers go [DELETE]. `DCH1`.
15. `QUERY CHANNEL` of it: CHANNELERR, RESP2 2 [QUERY]. `QCH4`, 122 / 002, no count logged.
16. `GET CONTAINER('BETA')` in it: CHANNELERR, RESP2 2 [GET]. `GET3`. A second `DELETE CHANNEL`: CHANNELERR, RESP2 2 [DELETE]. `DCH2`.
17. `PUT CONTAINER('BETA')` naming it: a new channel [PUT]. `PUT4`. `QUERY CHANNEL`: 1 [DELETE]. `QCH5`, length 1.
18. `GET CONTAINER('ALPHA')` in it: CONTAINERERR, RESP2 10, the old containers went with the old channel [DELETE]. `GET4`.
19. `DELETE CHANNEL('CABMOVED')`: NORMAL [DELETE]. `DCH3`. `RETURN`.

### `unhandled-channelerr` (`CA08`)

`CABRERR` puts container `ONE` in a new channel (NORMAL, logged `PUTE`), then `DELETE CHANNEL('CABNOCHAN')` with
neither RESP nor NOHANDLE and no HANDLE CONDITION: CHANNELERR, whose default action abends the task with AEZV
[AEZV]. There is no HANDLE ABEND exit. `BAD2` is never written.

## What a correct port must do

* Count a channel's containers (QUERY CHANNEL CONTAINERCNT), move a container to a channel it
  creates, and take a channel with all its containers on DELETE CHANNEL.
* Answer CHANNELERR 2, CONTAINERERR 10, END 2 and TOKENERR 3 through RESP, and abend AEZV for an
  unhandled CHANNELERR.

## Avoided ambiguities

* **The browse order.** IBM: "The order of returned containers is undefined and may change." The
  log holds no name, only how many distinct known names came back (3).
* **CONTAINERCNT on a condition.** IBM does not say what it holds on CHANNELERR: it is logged only
  after a NORMAL QUERY.
* **A GETNEXT after END.** IBM does not say whether the token stays valid: none is issued.
* **The order of MOVE's conditions** (INVREQ 4, CHANNELERR 2, CONTAINERERR 10 are not ranked): the
  one failing MOVE has both channels and fails only on its missing source.
* **Deleting the current channel** (IBM's CHANNELERR 4 / 5 / 6 do not say which): the task has no
  current channel and deletes only channels it created.
* **Changing a container's data type.** Every PUT is CHAR into a container that is new.

## Citations

* [PUT] CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL) ("If the channel does not exist, it is created"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [GET] CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (NODATA, FLENGTH; CHANNELERR 2, CONTAINERERR 10): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [MOVE] CICS TS 6.x, EXEC CICS MOVE CONTAINER (CHANNEL) (AS, TOCHANNEL "If the channel does not exist, CICS creates it"; CONTAINERERR 10): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-move-container-channel
* [START] CICS TS 6.x, EXEC CICS STARTBROWSE CONTAINER (CHANNEL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-startbrowse-container-channel
* [NEXT] CICS TS 6.x, EXEC CICS GETNEXT CONTAINER (CHANNEL) (END 2, TOKENERR 3, "The order of returned containers is undefined"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-getnext-container-channel
* [END] CICS TS 6.x, EXEC CICS ENDBROWSE CONTAINER (CHANNEL) (TOKENERR 3): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-endbrowse-container-channel
* [DELETE] CICS TS 6.x, EXEC CICS DELETE CHANNEL ("deleting the channel also deletes every container it holds"; CHANNELERR 2): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delete-channel
* [QUERY] CICS TS 6.x, EXEC CICS QUERY CHANNEL (CONTAINERCNT; CHANNELERR 2): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-query-channel
* [AEZV] CICS TS 6.x, abend code AEZV ("CHANNELERR condition not handled"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aezv
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (CONTAINERERR 110, TOKENERR 112, CHANNELERR 122, END 83): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
