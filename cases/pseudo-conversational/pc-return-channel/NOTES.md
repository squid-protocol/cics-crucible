# pc-return-channel: RETURN TRANSID ... CHANNEL carries a channel and its containers into the next task

## The trap

`PCRCA` (transaction `PC61`) is typed with a mode after the transid and logs what it saw to TS queue `PCRLOG` (item: a
4-byte tag, RESP and RESP2 in 3 digits each, a 5-digit length and a 16-byte text: 31 bytes, trailing blanks trimmed in
the log's `text`). `PCRCB` (`PC62`) is the next task of the conversation. A COMMAREA is a copy of a data area, but a
**channel** is a named set of containers: `RETURN TRANSID(x) CHANNEL(c)` makes `c` available to the next program, which
reads it with no channel name at all.

* **C** `PUT CONTAINER('STATE') CHANNEL('PCCHAN') FROM('CARRY-A1') CHAR`, then `RETURN TRANSID('PC62')
  CHANNEL('PCCHAN')`. The next ENTER starts `PC62` (`PCRCB`), which does `ASSIGN CHANNEL`, then `GET CONTAINER('STATE')`
  with no CHANNEL, and RETURNs.
* **M** the same with `1MODIFY0` (a stage byte and 7 bytes of text). `PCRCB` acts on the stage: stage 1 replaces `STATE`
  (`2CHANGED`), creates `EXTRA` and RETURNs `TRANSID('PC62') CHANNEL(<ASSIGN CHANNEL's name>)`; stage 2 reads `EXTRA`,
  deletes it, replaces `STATE` (`3AGAIN-2`) and RETURNs the channel again; stage 3 reads `STATE` and tries `EXTRA`.
* **L** `LINK PROGRAM('PCRCL')` without a channel or COMMAREA. `PCRCL` puts a container in `PCCHAN` and issues
  `RETURN TRANSID('PC62') CHANNEL('PCCHAN') RESP(..) RESP2(..)` in a program below the highest logical level.

## Why a naive translation breaks

* A port that treats `CHANNEL` like `COMMAREA(WS-CA)` (a by-value DTO, or ignoring the option) leaves `PC62` with no
  current channel: `ASSIGN CHANNEL` returns blanks and `GET CONTAINER` is INVREQ RESP2 4 instead of the carried
  container, and in `modify` every turn after the first reads nothing.
* A port that gives each task a fresh channel, or keeps the container as it was at the first PUT, loses the changes of
  the previous turn: stage 2 would read `1MODIFY0` and still find no `EXTRA`, and stage 3 would find `EXTRA`.
* A port that lets `RETURN CHANNEL` end a LINKed program (the way a level-1 RETURN ends the task) misses the INVREQ,
  skips `RET1` and `LNK1`, and drops the caller.
* A port that gives the next task an EIBCALEN for the channel, or a COMMAREA made from it, differs in `EIBCALEN`: a
  channel is not a communication area.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is the one terminal; every program is local. Every scenario starts at 10:00:00 with
`PC61 <mode>` typed on T001.

* **`carry`** (C, steps at 0 and 10): task 1 RECEIVEs `PC61 C`; `PUT CONTAINER CHANNEL('PCCHAN')` on a channel that does
  not exist creates it: "If the channel does not exist, it is created" [PUT]; NORMAL, logged `PUT1`. The RETURN names
  `TRANSID('PC62')` and `CHANNEL('PCCHAN')`: CHANNEL "specifies the name (1-16 characters) of a channel that is to be
  made available to the next program that receives control" [RETURN], and TRANSID "the transaction identifier to be used
  with the next input message entered from the terminal" [RETURN], so the ENTER at step 1 starts task 2 (`PC62`),
  with no COMMAREA (EIBCALEN 0: none was given). Its `ASSIGN CHANNEL` "returns the 16-character name of the current
  channel of the program, if one exists; otherwise, blanks" [ASSIGN]: `PCCHAN` (reading 1, README). `GET CONTAINER('STATE')`
  with no CHANNEL uses the current channel [GET] and returns the 8 bytes `CARRY-A1`, FLENGTH 8, NORMAL (`GETB`).
* **`modify`** (M, steps at 0, 10, 20, 30): task 1 as in `carry`, with `1MODIFY0`. Task 2 (`PC62`, stage 1): ASSIGN
  gives `PCCHAN`, GET gives `1MODIFY0`. `PUT CONTAINER('STATE')` of an existing container: "If the named container
  exists, its previous contents are overwritten, unless you specify the APPEND or PREPEND option" [PUT]; `PUT
  CONTAINER('EXTRA')` creates a container in the current channel. `RETURN TRANSID('PC62') CHANNEL(WS-CUR)` passes the
  channel by the name ASSIGN returned: the issuing program "can specify its current channel by name" [RETURN]. Task 3
  (step 2, stage 2): GET gives `2CHANGED` (reading 2, README) and `EXTRA` is there (`GETX`, length 5); `DELETE
  CONTAINER('EXTRA')` is NORMAL [DELETE]; STATE is replaced by `3AGAIN-2` and the channel RETURNed again. Task 4 (step 3,
  stage 3): GET gives `3AGAIN-2`; `GET CONTAINER('EXTRA')` is CONTAINERERR (110) RESP2 10, "The container named on the
  CONTAINER option could not be found" [GET] (logged `GETX` with RESP 110, RESP2 010, no length: FLENGTH is not read after a failure). The
  plain RETURN ends the conversation.
* **`link-level2`** (L): `PCRCA` LINKs `PCRCL` with no COMMAREA (`length` 0). `PCRCL`'s PUT is NORMAL (`PUT2`). Its
  `RETURN TRANSID('PC62') CHANNEL('PCCHAN')` is INVREQ RESP2 2: "A RETURN command with the CHANNEL, COMMAREA, or
  IMMEDIATE option is issued by a program that is not at the highest logical level" [RETURN]. INVREQ is 16
  [RESP-CODES]. The command returns to the program (RESP is given), which logs `RET1` with RESP 016, RESP2 002; its plain RETURN
  goes back to `PCRCA` (level 2, `caller_commarea` null), which logs `LNK1` (NORMAL) and ends the task with a plain
  RETURN: no next transaction, so there is no second step. The failed RETURN is an event with `channel`, `transid`,
  `resp` and `resp2` and no area.

## What a correct port must do

* Keep a channel as a set of named containers that the next task of a RETURN TRANSID CHANNEL receives as its current
  channel; ASSIGN CHANNEL names it and GET CONTAINER without CHANNEL reads it.
* Carry the containers as they were when the RETURN was issued, so a channel the next task changes and RETURNs again is
  seen changed (replaced, created and deleted containers alike) by the task after it.
* Not turn the channel into a COMMAREA: the next task's EIBCALEN is 0 (no COMMAREA was given).
* Raise INVREQ RESP2 2 for CHANNEL below the highest logical level, and let the program go on.

## Avoided ambiguities

* **COMMAREA and CHANNEL together** on one RETURN: IBM's page does not say whether they may be combined (it lists both
  as valid only at the highest level); no program gives both, and the validator rejects a RETURN CHANNEL event that
  passes a commarea.
* **IMMEDIATE with CHANNEL**, and a `DFHTRANSACTION` transaction channel: not used (the channel names are plain, and
  none is a transaction channel; "A transaction channel does not go out of scope when the link level changes" [RETURN]).
* **What a channel RETURN does if the next input is not for TRANSID** (a different transaction typed, CLEAR): every
  step after a RETURN CHANNEL is a bare ENTER, which starts the RETURN's transaction.
* **When the channel's storage is freed** after the last task of the conversation, and a channel that outlives the task
  that RETURNed it by more than one turn without being RETURNed again: no scenario runs a task that is not given the
  channel by the RETURN before it.
* **Order of checks** in a failed RETURN CHANNEL (INVREQ against CHANNELERR for the name): the channel name is a valid
  one (`PCCHAN`), so only INVREQ RESP2 2 applies. Remote regions (INVREQ RESP2 203) and first-stage PLT programs are not
  modelled.
* **The INVREQ with no TRANSID**: `RETURN CHANNEL` always gives TRANSID. `PCRCL` creates `PCCHAN` first so the channel
  exists when the RETURN fails; IBM states no difference for a channel that does not exist.
* **FLENGTH after a failed GET**: `GETX` reads no length after CONTAINERERR.

## Citations

* [RETURN] CICS TS 6.x, EXEC CICS RETURN (CHANNEL "specifies the name (1-16 characters) of a channel that is to be made
  available to the next program that receives control"; TRANSID; INVREQ RESP2 2; the issuing program "can specify its
  current channel by name"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [ASSIGN] CICS TS 6.x, EXEC CICS ASSIGN (CHANNEL: "the 16-character name of the current channel of the program, if one
  exists; otherwise, blanks"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-assign
* [GET] CICS TS 6.x, EXEC CICS GET CONTAINER (CHANNEL) (the current channel when CHANNEL is omitted; FLENGTH; CONTAINERERR
  RESP2 10, INVREQ RESP2 4): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-get-container-channel
* [PUT] CICS TS 6.x, EXEC CICS PUT CONTAINER (CHANNEL) ("If the channel does not exist, it is created"; an existing
  container is overwritten unless APPEND or PREPEND; CHAR / BIT): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-put-container-channel
* [DELETE] CICS TS 6.x, EXEC CICS DELETE CONTAINER (CHANNEL): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-delete-container-channel
* [PASS] CICS TS 5.6, The current channel ("As well as the LINK and XCTL commands, you can pass channels on the START,
  RUN TRANSID and RETURN commands"): https://www.ibm.com/docs/en/cics-ts/5.6.0?topic=channels-current-channel
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16, CONTAINERERR 110, CHANNELERR 122):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
