# hc-file-write-keylength: WRITE with KEYLENGTH naming the file's full key length adds a record under a new key; a key already in the file is DUPREC and changes nothing

## The trap

`HCWKLN` (transaction `HC99`) is `hc-file-write` with one difference: every `WRITE` names `KEYLENGTH`, the length of the key given
in `RIDFLD`, which is the full 4-byte key of the file. Production programs add `KEYLENGTH(n)` to a keyed `WRITE` and expect it
to change nothing when `n` is the key's length. The program is typed with a mode after `HC99`. It works on file `HCWK`, a KSDS seeded
from `data/HCWK.dat` (three 16-byte records: key 4, name 8, quantity 4), and logs each command's result to TS queue `HCLOG`. Item format,
27 bytes: tag (3), ` R=`, RESP (2), ` D=`, a 16-byte record (the record READ returned; blanks for any other command). Every command passes
`LENGTH(16)`.

* **N**: `WRITE ... RIDFLD(K004) KEYLENGTH(4)` of a new record, then `READ` of `K004`.
* **D**: `WRITE ... KEYLENGTH(4)` of a record with key `K002`, which is in the file (`K002NEWNAME 0099`), then `READ` of `K002`.
* **T**: `WRITE ... KEYLENGTH(WS-KLEN)` of a new record with key `K006` twice (`WS-KLEN` is a halfword with VALUE 4), then `READ` of `K006`.

## Why a naive translation breaks

* A port that refuses or ignores a `WRITE` carrying `KEYLENGTH` loses the whole command: no `WRITE` event, no DUPREC for the program to log.
* A port that treats `KEYLENGTH` as a partial (generic) key length, or compares only a prefix, mismatches on `K002` / `K006` handling.
* As in `hc-file-write`, a port that implements WRITE as a map `put` overwrites `K002` in mode D, or answers the second WRITE in T with NORMAL.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCWK` is local, VSAM KSDS, not recoverable, enabled, opened on first use, and its definition
allows add (`ADD(YES)`); each scenario starts at 10:00:00 on 2026-03-02 with `HC99 <mode>` typed on T001.

* **`write-new`** (N): N1 `WRITE` of `K004DELTA   0040` with `RIDFLD` `K004` and `KEYLENGTH(4)` is NORMAL: KEYLENGTH "specifies the length
  (halfword binary) of the key that has been specified in the RIDFLD option" [WRITE]; 4 is the key's length, and "when adding records to a
  keyed data set, the field must contain the complete key" [WRITE]. N2 `READ` of `K004` returns the record. Final file: seed plus `K004`.
* **`write-duplicate`** (D): D1 `WRITE` of `K002` with `KEYLENGTH(4)`: DUPREC (RESP 14) [WRITE, RESP-CODES]; the page lists RESP2 150, not asserted
  (see Avoided ambiguities). D2 `READ` of `K002` returns the original `K002BRAVO   0020`. Final file: unchanged.
* **`write-twice`** (T): T1 `WRITE` of `K006` with `KEYLENGTH(WS-KLEN)` (value 4): NORMAL. T2 the same: DUPREC. T3 `READ` returns
  `K006FOXTROT 0060`. Final file: seed plus one `K006`.
* In every scenario the program sends `DONE OK` and RETURNs. The `WRITE` event carries `file`, `ridfld`, `data` and `resp`; KEYLENGTH is
  not an event key, so the log is the one `hc-file-write` has: the case proves the command is accepted and behaves the same.

## What a correct port must do

* Accept `KEYLENGTH` on a keyed `WRITE` when it equals the file's key length, as a literal and as a data item, and behave as without it.
* Add the record only when no record has that key; otherwise raise DUPREC (RESP 14) and leave the file unchanged.

## Avoided ambiguities

* **RESP2 of DUPREC**: the WRITE page lists RESP2 150; the SPEC gives `resp2` only where IBM documents the value and this case asserts RESP only.
* **A KEYLENGTH that is not the key's length** (INVREQ RESP2 26: "The KEYLENGTH option is specified, and the specified length does not equal the
  length defined" [WRITE]), **a key in the record differing from RIDFLD** (INVREQ 23), **LENGTH other than the record length** (LENGERR),
  **MASSINSERT**, **RLS**, recoverable files, remote files, **NOTOPEN / DISABLED**: not used.
* **Default action of DUPREC**: the program passes `RESP`, so the task is not abended.
* **Write ordering inside the data set**: the final file lists records in key order (a KSDS).

## Citations

* [WRITE] CICS TS 6.x, EXEC CICS WRITE (file control), KEYLENGTH, RIDFLD, FROM, LENGTH, conditions (DUPREC RESP2 150, INVREQ RESP2 26):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_write.html
* [READ] CICS TS 6.x, EXEC CICS READ (file control):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (DUPREC 14):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes, the length every `RIDFLD` and `KEYLENGTH` of the case names), `RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the length and position of the key field of the records in a key-sequenced data set".
