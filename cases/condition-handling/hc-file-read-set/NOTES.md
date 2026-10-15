# hc-file-read-set: READ SET and STARTBR / READNEXT / READPREV SET over a seeded KSDS; NOTFND (RESP2 80) and ENDFILE (RESP2 90)

## The trap

`HCRDST` (transaction `HC83`) is typed with a mode after `HC83`. It works on file `HCRS`, a KSDS seeded from `data/HCRS.dat` (five
16-byte records: key 4, name 8, quantity 4; keys `K010`, `K020`, `K030`, `K040`, `K050`) and logs each command's result to TS queue
`HCLOG`. Every read is the `SET` form: CICS supplies the buffer and the program addresses the record through `SET(ADDRESS OF
LS-REC)`; no `INTO` and no `LENGTH` is used. Item format, 40 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` K=`, the `RIDFLD` key
after the command (4; blank unless the command was a NORMAL read), ` D=`, the 16-byte record the pointer addressed (blank unless NORMAL).
RESP2 is logged only for a command that failed.

* **R**: `READ SET` of `K030`, of `K035` (not in the file, no `GTEQ`), of `K050`.
* **F**: `STARTBR GTEQ` of `K015` (not in the file), five `READNEXT SET`, `ENDBR`.
* **B**: `STARTBR GTEQ` of `K040`, five `READPREV SET`, `ENDBR`.
* **N**: `STARTBR GTEQ` of `K060` (past the last key), `STARTBR EQUAL` of `K025`, `STARTBR EQUAL` of `K030`, `READNEXT SET`, `ENDBR`.

## Why a naive translation breaks

* A port that implements only `INTO` has no record to hand out for `SET`; one that keeps the pointer past the next `READ` shows the
  wrong record (the program copies the record at once, as IBM requires).
* A port that treats `GTEQ` as `EQUAL` fails the `STARTBR` of `K015` with NOTFND instead of positioning on `K020`.
* A port that does not update `RIDFLD` on each `READNEXT` / `READPREV` loses the `K=` column.
* A port that wraps at the end of the file, returns NOTFND instead of ENDFILE, or drops RESP2 90 / 80, differs in the last record
  read of F and B and in R2, N1, N2.
* A port that browses only forward has no `READPREV`.

## Expected behaviour

Model (SPEC section 2): file `HCRS` is a local VSAM KSDS, enabled, opened on first use, `BROWSE(YES)`; each scenario starts at
10:00:00 on 2026-03-02 with `HC83 <mode>` typed on T001. NOTFND is RESP 13, ENDFILE RESP 20 [READPREV].

* **`read-set`** (R): R1 returns `K030CHARLIE 0030`: the `SET` option "indicates that CICS is to supply a buffer where the record is
  read" [READ] and the pointer "is valid until the next READ command for the same file" (the program reads it at once); "If you
  specify the SET option, you do not need to specify the LENGTH option" [READ]. R2: no `GTEQ`/`EQUAL` is coded, and `EQUAL` "specifies
  that the search is satisfied only by a record having the same key" [READ]; `K035` is absent, so NOTFND, RESP2 80, "An attempt to
  retrieve a record based on the search argument provided is unsuccessful" [READ]. R3 returns `K050ECHO    0050`.
* **`browse-fwd`** (F): F0 `STARTBR GTEQ` of `K015`: "if the search for a record that has the same key ... is unsuccessful, the first
  record that has a greater key satisfies the search" [STARTBR], so the browse is positioned on `K020`; NORMAL. F1..F4 `READNEXT` return
  `K020`, `K030`, `K040`, `K050` in key order ("READNEXT can be used repeatedly to read records in sequential order" [READNEXT]);
  "CICS, on completion of each READNEXT command, places the complete identifier of the record just retrieved into the RIDFLD data
  area" [READNEXT], hence the `K=` column. F5: ENDFILE, RESP2 90, "An end-of-file condition is detected during the browse"
  [READNEXT]; no record. F6 `ENDBR` NORMAL [ENDBR].
* **`browse-back`** (B): B0 `STARTBR GTEQ` of `K040` (it exists, as READPREV requires: "your STARTBR command RIDFLD must specify the
  key of a record that exists on the data set" [READPREV]). B1..B4 `READPREV` return `K040`, `K030`, `K020`, `K010` ("READPREV can be
  used repeatedly to read records in reverse sequential order from a VSAM file" [READPREV]; the first one returning the record the
  STARTBR named is a reading, see README), `RIDFLD` updated each time [READPREV]. B5: ENDFILE, RESP2 90 [READPREV]. B6 `ENDBR` NORMAL.
* **`browse-notfnd`** (N): N1 `STARTBR GTEQ` of `K060`: no record has that key or a greater one, so the search is unsuccessful: NOTFND,
  RESP2 80, "An attempt to position on a record based on the search argument provided is unsuccessful" [STARTBR]. N2 `STARTBR EQUAL`
  of `K025`: NOTFND RESP2 80 likewise. N3 `STARTBR EQUAL` of `K030` NORMAL (`EQUAL` "specifies that the search is satisfied only by a
  record having the same key" [STARTBR]). N4 `READNEXT` returns `K030CHARLIE 0030`, the record the browse is positioned on (README).
  N5 `ENDBR` NORMAL: the failed STARTBRs started no browse ("If STARTBR was not successful, you do not need to issue ENDBR" [ENDBR]),
  the one successful STARTBR is ended.
* In every scenario the program sends `DONE OK` and RETURNs; the file is never changed, so `final.files` is the seed.

## What a correct port must do

* Give `READ ... SET` the record, NOTFND RESP2 80 for an `EQUAL` read of an absent key, and treat the pointer as good only until the
  next `READ` of the file.
* Position `STARTBR GTEQ` on the first record at or above the key, `EQUAL` only on a match, NOTFND RESP2 80 when neither exists.
* Step `READNEXT` up and `READPREV` down the key order, update `RIDFLD` with the key of the record returned, and answer ENDFILE
  RESP2 90 once there is no further record in that direction.

## Avoided ambiguities

* **LENGTH**: no command passes `LENGTH`; with `SET` it need not be given [READ]. LENGERR is not provoked.
* **RIDFLD after a failed command, or after ENDFILE**: IBM states the update only for a retrieved record; the log's `K=` is blank
  unless the command was NORMAL. A browse event's `ridfld` is the key on entry.
* **A browse reversing direction** (`READNEXT` then `READPREV`, which repeats a record), **`READNEXT` after ENDFILE**, **`RESETBR`**,
  **`REQID`**, a second browse on the file, generic or `KEYLENGTH` browses, `READ GTEQ` / generic `READ` (they update `RIDFLD`),
  browse with `UPDATE` / `REWRITE`, `ENDBR` with no browse (INVREQ RESP2 35), `STARTBR` with a missing record `EQUAL` followed by
  reads: not used.
* **Recoverable files, locks, RLS, data tables, LOCKED / RECORDBUSY / NOTOPEN / DISABLED / IOERR**: the file is not recoverable and
  enabled, and no other task touches it.
* **Pointer lifetime**: the program copies each record at once; no scenario reads through a pointer after a later command.

## Citations

All CICS TS 6.x (IBM Documentation, SSJL4D_6.x, fetched 2026-10-15).

* [READ] EXEC CICS READ, SET, LENGTH, GTEQ / EQUAL, NOTFND (RESP2 80):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [STARTBR] EXEC CICS STARTBR, description, GTEQ, EQUAL, RIDFLD, NOTFND (RESP2 80):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_startbr.html
* [READNEXT] EXEC CICS READNEXT, SET, RIDFLD update, ENDFILE (RESP2 90), NOTFND:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_readnext.html
* [READPREV] EXEC CICS READPREV, SET, RIDFLD, ENDFILE (RESP 20, RESP2 90):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_readprev.html
* [ENDBR] EXEC CICS ENDBR, description, conditions:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_endbr.html
