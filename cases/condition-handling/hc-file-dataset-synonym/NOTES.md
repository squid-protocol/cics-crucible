# hc-file-dataset-synonym: WRITE, REWRITE and DELETE that name the file with DATASET (the older spelling of FILE); DUPREC, INVREQ RESP2 30, NOTFND RESP2 80

## The trap

`HCDSET` (transid `HC90`) is typed with a mode after `HC90`. It works on file `HCDS`, a KSDS seeded from `data/HCDS.dat` (three 16-byte
records: key 4, name 8, quantity 4: `K001`, `K002`, `K003`), and logs each command's result to TS queue `HCLOG`. Every file command
(`WRITE`, `REWRITE`, `DELETE`, and the `READ` that checks it) names the file with `DATASET('HCDS')`, never `FILE`. Item format, 33
bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3, zero unless RESP is not NORMAL; never carried for DUPREC), ` D=`, a 16-byte
record (the record a READ returned; blanks for any other command). Every READ and REWRITE passes `LENGTH(16)`.

* **W**: `WRITE` of the new key `K004`, `READ` of it, `WRITE` of `K002` (already in the file), `READ` of `K002`.
* **R**: `REWRITE` with no `READ UPDATE` yet, `READ UPDATE` of `K002`, `REWRITE` of it with quantity `0099`, `READ` of `K002`.
* **D**: `DELETE` of `K003`, `READ` of `K003`, `DELETE` of `K003` again, `READ` of `K001`.

## Why a naive translation breaks

* The earlier file cases (`hc-file-delete`, `hc-file-unlock`, `hc-file-write-keylength`) write `FILE(...)`. A port whose `WRITE`,
  `REWRITE` or `DELETE` handler looks only for `FILE` finds no file name here and refuses, or acts on no file: every event after
  `RECEIVE` is missing or wrong.
* A port that takes the file from `DATASET` on `READ` only (the form `hc-file-into-browse` exercises) but not on the update commands
  answers NORMAL for the reads and drops the writes: the final file equals the seed in all three scenarios.
* The outcomes are the ones `FILE` gives: a second `WRITE` of a key is DUPREC and keeps the stored record; a `REWRITE` with no held
  `READ UPDATE` is INVREQ RESP2 30; a `DELETE` of an absent key is NOTFND RESP2 80.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCDS` is local, VSAM KSDS, not recoverable, enabled, opened on first use, allowing add, delete,
read and update; each scenario starts at 10:00:00 on 2026-03-02 with `HC90 <mode>` typed on T001. The event log names the file in
`file` whichever spelling the program used. NOTFND is RESP 13, DUPREC RESP 14, INVREQ RESP 16 [RESP-CODES].

* **`write`** (W): W1 `WRITE` of `K004DELTA   0040` under RIDFLD `K004` is NORMAL: WRITE "Write a record" to a file [WRITE]. W2 `READ`
  of `K004` returns it. W3 `WRITE` of `K002` is DUPREC (RESP 14): the key already exists in the file's primary index, so the record is
  not added [WRITE]; the log carries no RESP2 for it (see below). W4 `READ` of `K002` returns the original `K002BRAVO   0020`. Final
  file: seed plus `K004`.
* **`rewrite`** (R): R1 `REWRITE` with no earlier `READ UPDATE` is INVREQ RESP 16, RESP2 30: "No token was supplied, and no earlier
  READ for UPDATE without a token can be found" [REWRITE] (the same condition as `hc-file-unlock` U3 / N2; asserted only before any
  `READ UPDATE`). R2 `READ UPDATE` of `K002` is NORMAL and returns the record [READ]. R3 `REWRITE` of the held record is NORMAL:
  REWRITE updates the record the earlier READ UPDATE obtained [REWRITE]. R4 `READ` of `K002` returns `K002BRAVO   0099`. Final file: seed
  with `K002` at quantity `0099`.
* **`delete`** (D): D1 `DELETE` of `K003` by RIDFLD is NORMAL [DELETE]. D2 `READ` of `K003` is NOTFND RESP2 80: "An attempt to
  retrieve a record based on the search argument provided is unsuccessful." [READ]. D3 the same `DELETE` is NOTFND RESP2 80: "An
  attempt to delete a record based on the search argument provided is unsuccessful." [DELETE]. D4 `READ` of `K001` returns it
  unchanged. Final file: `K001`, `K002`.

The quotes are as in `hc-file-delete` and `hc-file-unlock` NOTES (same IBM pages, read 2026-11-10 through a page-extraction tool;
the wording is as extracted, not guaranteed byte-for-byte; re-check against the live page when a quote is relied on).

## What a correct port must do

* Accept `DATASET(name)` as the file name on `WRITE`, `REWRITE`, `DELETE` and `READ`, exactly as `FILE(name)`.
* Answer DUPREC for a `WRITE` of an existing key and leave the stored record alone; INVREQ RESP2 30 for a `REWRITE` with no held
  `READ UPDATE`; NOTFND RESP2 80 for a `DELETE` of an absent key.
* Report the file under `file` in the `WRITE`, `REWRITE`, `DELETE` and `READ` events.

## Avoided ambiguities

* **That `DATASET` is a synonym of `FILE`:** the syntax diagrams of the pages cited below did not survive the page-extraction tool, so
  no sentence is quoted for it; it rests on IBM's command syntax and on the existing cases that already use `DATASET` for reads
  (`hc-file-into-browse`). It is listed in the README's lower-confidence table.
* **RESP2 of DUPREC:** the program zeroes `RESP2` after each `WRITE`, so no scenario asserts one.
* **A second `REWRITE` after one `READ UPDATE`**, **`REWRITE` after `UNLOCK`**, **`DELETE` with no RIDFLD**, **GENERIC**, **NUMREC**,
  **TOKEN**, **MASSINSERT**, **RLS**, **recoverable files**, **NOTOPEN / DISABLED**: not used.
* **Default action of NOTFND / DUPREC / INVREQ** (terminate the task abnormally): the program passes `RESP`, so the task is not abended.
* **Order of records**: the final file lists records in key order (a KSDS).

## Citations

All CICS TS 6.x (IBM Documentation, SSJL4D_6.x).

* [WRITE] EXEC CICS WRITE, DUPREC:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_write.html
* [REWRITE] EXEC CICS REWRITE, INVREQ RESP2 30:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_rewrite.html
* [DELETE] EXEC CICS DELETE, NOTFND RESP2 80:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_delete.html
* [READ] EXEC CICS READ, UPDATE and NOTFND RESP2 80:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [RESP-CODES] Response codes of EXEC CICS commands (NOTFND 13, DUPREC 14, INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes),
`RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the
length and position of the key field of the records in a key-sequenced data set".
