# hc-file-token: READ UPDATE TOKEN, then REWRITE TOKEN / DELETE TOKEN; INVREQ RESP2 47

## The trap

`HCTOKN` (transid `HC70`) is typed with a mode after `HC70`. It works on file `HCTK`, a KSDS seeded from `data/HCTK.dat` (five 16-byte
records: key 4, name 8, quantity 4: `A100`, `A200`, `A300`, `B100`, `B300`), and logs each command's result to TS queue `HCLOG`. Item
format, 33 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3, zero unless RESP is not NORMAL), ` D=`, a 16-byte record (the record a READ
returned; blanks for any other command). Every READ passes `LENGTH(16)`. `WS-NOTOK` is a fullword the program never passes to a READ: it stays zero.

* **R**: `REWRITE TOKEN(WS-NOTOK)` before any READ UPDATE, `READ UPDATE TOKEN(WS-TOK)` of `A200`, `REWRITE TOKEN(WS-TOK)` with
  quantity 0099, plain `READ` of `A200`.
* **D**: `DELETE TOKEN(WS-NOTOK)` before any READ UPDATE, `READ UPDATE TOKEN(WS-TOK)` of `B100`, `DELETE TOKEN(WS-TOK)` (no RIDFLD),
  plain `READ` of `B100`.

## Why a naive translation breaks

* A port that ignores TOKEN on REWRITE / DELETE and applies the command to "the held record" answers NORMAL (or INVREQ RESP2 30 / 31)
  for the first command of each scenario; IBM raises INVREQ RESP2 47 for a token no READ UPDATE returned.
* A port that does not treat TOKEN as implying UPDATE fails the REWRITE / DELETE after `READ ... TOKEN` with no UPDATE in the READ's
  hold bookkeeping; here the case also spells `UPDATE`, so the failure shows only as a wrong RESP, not a wrong record.
* A port that writes no token back into `WS-TOK` makes the following REWRITE / DELETE carry a zero token and answer 47 where IBM says NORMAL.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCTK` is local, VSAM KSDS, not recoverable, enabled, opened on first use, allowing delete, read and
update; each scenario starts at 10:00:00 on 2026-03-02 with `HC70 <mode>` typed on T001. INVREQ is RESP 16, NOTFND RESP 13 [RESP-CODES].

* **`rewrite`** (R): R1 `REWRITE TOKEN` with a zero token while no READ UPDATE has returned one: INVREQ RESP2 47, "A REWRITE instruction
  includes a token whose value cannot be matched against any token that is in use for an existing READ for UPDATE request" [REWRITE]
  (trimmed quote). R2 `READ UPDATE TOKEN` of `A200` is NORMAL: TOKEN is "a unique identifier for this READ UPDATE request",
  "If you specify TOKEN it implies update" [READ]. R3 `REWRITE TOKEN(WS-TOK)` is NORMAL: TOKEN on REWRITE is "used to associate it with a
  previous READ" [REWRITE]. R4 plain `READ` returns the rewritten record. Final file: `A200` quantity 0099.
* **`delete`** (D): D1 `DELETE TOKEN` with a zero token and none in use: INVREQ RESP2 47, "includes a token whose value cannot be matched
  against any token in use for an existing read for UPDATE request" [DELETE]. D2 `READ UPDATE TOKEN` of `B100` is NORMAL [READ]. D3
  `DELETE TOKEN(WS-TOK)` without RIDFLD is NORMAL: TOKEN is used "to associate the delete request with a record returned on a previous
  READ UPDATE" and a delete of a record read for update must not specify RIDFLD [DELETE]. D4 plain `READ` of `B100` is NOTFND RESP2 80
  [READ]. Final file: seed minus `B100`.

Quotes were read from the IBM pages on 2026-11-10 through a page-extraction tool, so the wording is as extracted, not guaranteed
byte-for-byte; re-check against the live page when a quote is relied on.

## What a correct port must do

* Return a fullword token from `READ ... UPDATE TOKEN(area)` and accept it on the matching REWRITE / DELETE.
* Answer INVREQ RESP2 47 to a REWRITE / DELETE whose token matches no READ UPDATE in use.
* Report RESP / RESP2 in the event log (`READ` with `update`, `REWRITE`, `DELETE`); the token value is not logged (it is IBM's unique id).

## Avoided ambiguities

* **Several READ UPDATE TOKEN holds on one file at once**, **a token reused after its REWRITE / DELETE** (stale token), **whether TOKEN is
  RLS only**: the three IBM pages state none of these, so no scenario relies on them. One hold exists at a time, and the 47 probes run
  before any READ UPDATE in the task, when no token can be in use.
* **The value of the token**: never logged or compared; the 47 probe uses a never-written zero fullword, which no READ UPDATE returned
  (IBM says only that the id is unique; a probe is not made after a hold, so a collision cannot arise).
* **UNLOCK TOKEN**, **READNEXT / READPREV UPDATE TOKEN** (RLS), **RIDFLD with TOKEN on DELETE**, **NOSUSPEND / RLS options**, recoverable files,
  remote files: not used.
* **Default action of INVREQ** (terminate the task abnormally): the program passes `RESP`, so the task is not abended.

## Citations

* [READ] CICS TS 6.x, EXEC CICS READ (file control), TOKEN, UPDATE, NOTFND:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [REWRITE] CICS TS 6.x, EXEC CICS REWRITE (file control), TOKEN, INVREQ RESP2 47:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_rewrite.html
* [DELETE] CICS TS 6.x, EXEC CICS DELETE (file control), TOKEN, INVREQ RESP2 47, RIDFLD:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_delete.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NOTFND 13, INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes),
`RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the
length and position of the key field of the records in a key-sequenced data set".
