# hc-file-delete: DELETE of a KSDS record by key and of a held record, NOTFND RESP2 80, INVREQ RESP2 31, and WRITE of a deleted key

## The trap

`HCDELE` (transaction `HC93`) is typed with a mode after `HC93`. It works on file `HCDF`, a KSDS seeded from `data/HCDF.dat`
(three 16-byte records: key 4, name 8, quantity 4), and logs each command's result to TS queue `HCLOG`. Item format, 33 bytes: tag (3),
` R=`, RESP (2), ` 2=`, RESP2 (3; zero unless RESP is not NORMAL), ` D=`, a 16-byte record (the record READ returned; blanks for any
other command, and for a READ that is not NORMAL). Every record command passes `LENGTH(16)`.

* **K**: `DELETE` with `RIDFLD` `K002`, then `READ` of `K002`, then `READ` of `K003`.
* **U**: `READ ... UPDATE` of `K002`, then `DELETE` with no `RIDFLD`, then `READ` of `K002`.
* **M**: `DELETE` with `RIDFLD` `K005` (not in the file), then `READ` of `K003`.
* **I**: `DELETE` with no `RIDFLD` and no `READ UPDATE` before it, then `READ` of `K001`.
* **R**: `DELETE` of `K002`, then `WRITE` of a new `K002` record, then `READ` of `K002`.

## Why a naive translation breaks

* A port that answers a DELETE of a missing key with NORMAL (a map `remove` returns quietly) loses the NOTFND the program logs (M).
* A port that requires RIDFLD on every DELETE, or that deletes the last record read whether or not it was read for UPDATE, gets U or I
  wrong: IBM deletes the held record only after a READ UPDATE, and raises INVREQ otherwise (I).
* A port that keeps a deleted key as a tombstone answers DUPREC to the WRITE in R; IBM's file has no record under that key, so the
  WRITE adds one.
* A port that deletes the neighbour, or every record under a key prefix (a generic delete), breaks K.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCDF` is local, VSAM KSDS, not recoverable, enabled, opened on first use, and its definition
allows add, delete and update (`ADD(YES)`, `DELETE(YES)`, `UPDATE(YES)`); each scenario starts at 10:00:00 on 2026-03-02 with
`HC93 <mode>` typed on T001.

* **`delete-key`** (K): K1 `DELETE` of `K002`: NORMAL; DELETE "deletes a record" of a KSDS, RIDFLD identifying it [DELETE]. K2 `READ`
  of `K002`: NOTFND, RESP2 80 [READ]. K3 `READ` of `K003` returns it unchanged. Final file: `K001`, `K003`.
* **`delete-held`** (U): U1 `READ UPDATE` of `K002` is NORMAL. U2 `DELETE` with no RIDFLD: NORMAL; "a single record previously read for
  update" is deleted without RIDFLD [DELETE]. U3 `READ` of `K002`: NOTFND, RESP2 80. Final file: `K001`, `K003`.
* **`delete-missing`** (M): M1 `DELETE` of `K005`: NOTFND, RESP2 80, an attempt to delete a record by the search argument that is
  unsuccessful [DELETE]. M2 `READ` of `K003` returns it. Final file: the seed.
* **`delete-no-hold`** (I): I1 `DELETE` with no RIDFLD: INVREQ, RESP2 31, "DELETE without RIDFLD is issued for a file with no previous
  READ UPDATE" [DELETE]. I2 `READ` of `K001` returns it. Final file: the seed.
* **`delete-then-write`** (R): R1 `DELETE` of `K002`: NORMAL. R2 `WRITE` of `K002NEWNAME 0099` with RIDFLD `K002`: NORMAL, the key is
  no longer in the file (WRITE adds a record under a key not in the file, DUPREC otherwise [WRITE]). R3 `READ` returns the new record.
  Final file: `K001`, `K002NEWNAME 0099`, `K003`.
* In every scenario the program sends `DONE OK` and RETURNs. NOTFND is RESP 13 and INVREQ RESP 16 [RESP-CODES].

## What a correct port must do

* DELETE by RIDFLD removes exactly the record with that key (NOTFND, RESP2 80, when there is none) and nothing else.
* DELETE with no RIDFLD removes the record the task's READ UPDATE holds; with none held it is INVREQ RESP2 31 and changes nothing.
* A deleted key is free: a later WRITE of it adds a record.
* Report each DELETE in the event log (`DELETE` event: `file`, `ridfld` only when the command has RIDFLD, `resp`, `resp2` where
  IBM documents it).

## Avoided ambiguities

* **GENERIC, KEYLENGTH, NUMREC, TOKEN, RBA / RRN**: not used. IBM's generic delete locks every matched record until syncpoint.
* **The default action of NOTFND and INVREQ** ("terminate the task abnormally"): the program passes `RESP`, so the task is not abended.
* **RESP2 of a NORMAL command**: IBM states a RESP2 per condition, not for NORMAL; the program logs RESP2 only after a non-NORMAL RESP.
* **INVREQ RESP2 20** (delete not allowed by the definition), **NOTOPEN / DISABLED / LOCKED / RECORDBUSY / RLS**, recoverable files and
  syncpoint locks, remote files and data tables: not used. The file is enabled, allows delete, and no other task touches it.
* **Whether a DELETE of a held record releases the hold for a second DELETE**: no scenario issues a second DELETE after a READ UPDATE.

## Citations

* [DELETE] CICS TS 6.x, EXEC CICS DELETE (file control), description, RIDFLD, conditions (NOTFND RESP2 80; INVREQ RESP2 20 and 31):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_delete.html
* [READ] CICS TS 6.x, EXEC CICS READ (file control), UPDATE, NOTFND RESP2 80:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [WRITE] CICS TS 6.x, EXEC CICS WRITE (file control), DUPREC:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_write.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NOTFND 13, INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes, the length every `RIDFLD` of the case names), `RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the length and position of the key field of the records in a key-sequenced data set".
