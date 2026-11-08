# hc-file-write: WRITE to a KSDS adds a record under a new key; a key already in the file is DUPREC and changes nothing

## The trap

`HCWRIT` (transaction `HC92`) is typed with a mode after `HC92`. It works on file `HCWF`, a KSDS seeded from `data/HCWF.dat`
(three 16-byte records: key 4, name 8, quantity 4), and logs each command's result to TS queue `HCLOG`. Item format, 27 bytes: tag (3),
` R=`, RESP (2), ` D=`, a 16-byte record (the record READ returned; blanks for any other command). Every command passes `LENGTH(16)`.

* **N**: `WRITE` of a record with the new key `K004`, then `READ` of `K004`.
* **D**: `WRITE` of a record with key `K002`, which is in the file (`K002NEWNAME 0099`), then `READ` of `K002`.
* **T**: `WRITE` of a new record with key `K006` twice, then `READ` of `K006`.

## Why a naive translation breaks

* A port that implements WRITE as a map `put` overwrites `K002` in mode D (answers NORMAL, the READ returns `NEWNAME`); IBM raises
  DUPREC and keeps the stored record.
* A port that answers the second WRITE in T with NORMAL stores the record twice or replaces it; IBM raises DUPREC for the second.
* A port that drops the WRITE's RESP (treats an unchecked condition as an abend or ignores it) loses the DUPREC the program logs.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCWF` is local, VSAM KSDS, not recoverable, enabled, opened on first use, and its definition
allows add (`ADD(YES)`); each scenario starts at 10:00:00 on 2026-03-02 with `HC92 <mode>` typed on T001.

* **`write-new`** (N): N1 `WRITE` of `K004DELTA   0040` with `RIDFLD` `K004` is NORMAL: "WRITE writes a new record to a file" and for a
  KSDS "the record is added in the location specified by the associated key" [WRITE]. The key in the record equals RIDFLD, as IBM
  requires ("the key in the record and the key in the RIDFLD identification field must be the same" [WRITE]). N2 `READ` of `K004` returns
  the record just written. Final file: seed plus `K004`, in key order.
* **`write-duplicate`** (D): D1 `WRITE` of `K002`: DUPREC (RESP 14), "an attempt is made to add a record ... in which the same key
  already exists" [WRITE]; the page lists RESP2 150 for it, which the case does not assert (see Avoided ambiguities). D2 `READ` of `K002`
  returns the original `K002BRAVO   0020`: the failed WRITE changed nothing. Final file: unchanged.
* **`write-twice`** (T): T1 as N1 for `K006`: NORMAL. T2 the same WRITE again: DUPREC, the key now exists. T3 `READ` returns
  `K006FOXTROT 0060`. Final file: seed plus one `K006`.
* In every scenario the program sends `DONE OK` and RETURNs. DUPREC is RESP 14 [RESP-CODES].

## What a correct port must do

* Add the record only when no record has that key; otherwise raise DUPREC (RESP 14) and leave the file unchanged.
* Report the RESP of every WRITE in the event log (`WRITE` event: `file`, `ridfld`, the FROM `data`, `resp`).

## Avoided ambiguities

* **RESP2 of DUPREC**: the WRITE page lists RESP2 150; the SPEC says `resp2` is given only where IBM documents the value, and this
  case asserts RESP only, so the DUPREC events carry none. Not relied on.
* **Key in the record differing from RIDFLD** (INVREQ RESP2 23), **KEYLENGTH**, **LENGTH other than the record length** (LENGERR),
  **WRITE to a file whose definition disallows add** (INVREQ RESP2 20), **MASSINSERT**, **RLS**, recoverable files and syncpoint locks,
  remote files, **NOTOPEN / DISABLED**: not used. The file is enabled, allows add, and no other task touches it.
* **Default action of DUPREC** ("terminate the task abnormally"): the program passes `RESP`, so the task is not abended.
* **Write ordering inside the data set**: the final file lists records in key order (a KSDS), not insertion order.

## Citations

* [WRITE] CICS TS 6.x, EXEC CICS WRITE (file control), description, RIDFLD, FROM, LENGTH, conditions (DUPREC RESP2 150):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_write.html
* [READ] CICS TS 6.x, EXEC CICS READ (file control):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (DUPREC 14):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes, the length every `RIDFLD` of the case names), `RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the length and position of the key field of the records in a key-sequenced data set".
