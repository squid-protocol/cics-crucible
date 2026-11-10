# hc-file-into-browse: READ / STARTBR / READNEXT / READPREV / ENDBR in the INTO form with DATASET, LENGTH and KEYLENGTH; NOTFND (RESP2 80) and ENDFILE (RESP2 90)

## The trap

`HCRDIN` (transaction `HC84`) is typed with a mode after `HC84`. It works on file `HCRI`, a KSDS seeded from `data/HCRI.dat` (five
16-byte records: key 4, name 8, quantity 4; keys `K110`, `K120`, `K130`, `K140`, `K150`) and logs each command's result to TS queue
`HCLOG`. Where `hc-file-read-set` covers the `SET` form, every read here is the `INTO` form: `DATASET` names the file (the synonym of
`FILE`), `INTO` gives the area, `RIDFLD` the key and `KEYLENGTH(4)` the full key length. `READ` also passes `LENGTH` as a data area (set
to 16 before each command); `READNEXT` / `READPREV` pass `LENGTH(16)` as a literal that equals the area. Item format, 45 bytes: tag
(3), ` R=`, RESP (2), ` S=`, RESP2 (3), ` K=`, the `RIDFLD` key after the command (4), ` L=` the length after a `READ` (2; `00` for a
browse command), ` D=`, the 16-byte record (blank unless NORMAL).

* **R**: `READ DATASET INTO` of `K130`, of `K135` (absent), of `K150`.
* **F**: `STARTBR GTEQ` of `K115` (absent), five `READNEXT INTO`, `ENDBR`.
* **B**: `STARTBR GTEQ` of `K140`, five `READPREV INTO`, `ENDBR`.

## Why a naive translation breaks

* A port that accepts only `FILE` does not know `DATASET`; one that implements only `SET` has no `INTO` area to fill.
* A port that ignores `KEYLENGTH(4)` or `LENGTH` on a browse command refuses the statement or takes the wrong key.
* A port that does not return the length read in `LENGTH` after `READ` loses the `L=` column.
* A port that treats `GTEQ` as `EQUAL` fails the `STARTBR` of `K115`; one that wraps at the end of the file, returns NOTFND instead of
  ENDFILE, or drops RESP2 90 / 80, differs in the last record read of F and B and in R2.

## Expected behaviour

Model (SPEC section 2): file `HCRI` is a local VSAM KSDS, enabled, opened on first use, `BROWSE(YES)`, `READ(YES)`; each scenario
starts at 10:00:00 on 2026-03-02 with `HC84 <mode>` typed on T001. NOTFND is RESP 13, ENDFILE RESP 20 [READPREV].

* **`read-into`** (R): R1 returns `K130HOTEL   0130` into the area, `LENGTH` 16: `INTO` "specifies the data area into which the
  record is read" and `LENGTH` "specifies the length of the data area" and, on return, the length of the record read [READ]. R2:
  `K135` is absent, no `GTEQ` is coded, so NOTFND RESP2 80 [READ]. R3 returns `K150JULIET  0150`.
* **`browse-fwd`** (F): F0 `STARTBR GTEQ` of `K115` positions on `K120` [STARTBR]. F1..F4 `READNEXT` return `K120`, `K130`, `K140`,
  `K150` in key order, `RIDFLD` updated each time [READNEXT]. F5: ENDFILE RESP2 90 [READNEXT]. F6 `ENDBR` NORMAL [ENDBR].
* **`browse-back`** (B): B0 `STARTBR GTEQ` of `K140` (it exists, as READPREV requires [READPREV]). B1..B4 `READPREV` return `K140`,
  `K130`, `K120`, `K110` (see README on the first record). B5: ENDFILE RESP2 90 [READPREV]. B6 `ENDBR` NORMAL.
* In every scenario the program sends `DONE OK` and RETURNs; the file is never changed, so `final.files` is the seed.

## What a correct port must do

* Accept `DATASET` as `FILE`, fill `INTO`, return the record length in `LENGTH` after `READ`.
* Accept `KEYLENGTH` (the full key) and `LENGTH` (the area's own size) on every browse command.
* Position `STARTBR GTEQ` on the first record at or above the key; step `READNEXT` up and `READPREV` down; answer ENDFILE RESP2 90 at
  either end and NOTFND RESP2 80 for an absent `EQUAL` read.

## Avoided ambiguities

* **LENGERR / a short area**: `INTO` is always 16 bytes, the record width; no truncation or LENGERR is provoked.
* **KEYLENGTH other than the full key, GENERIC, `READ GTEQ`**: not used (generic reads update `RIDFLD`; the SPEC READ row has no
  mode key).
* **LENGTH on a browse command that differs from the area**: not used.
* **RIDFLD after a failed command or after ENDFILE**: the log's `K=` is the key after the command; IBM states the update only for a
  retrieved record, and a browse event's `ridfld` is the key on entry.
* **A browse reversing direction**, **`READNEXT` after ENDFILE**, **`RESETBR`**, **`REQID`**, a second browse, `UPDATE` / `REWRITE`:
  not used.
* **Recoverable files, locks, RLS, LOCKED / RECORDBUSY / NOTOPEN / DISABLED / IOERR**: the file is not recoverable and enabled, and
  no other task touches it.

## Citations

All CICS TS 6.x (IBM Documentation, SSJL4D_6.x, fetched 2026-11-10).

* [READ] EXEC CICS READ, DATASET, INTO, LENGTH, KEYLENGTH, NOTFND (RESP2 80):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [STARTBR] EXEC CICS STARTBR, DATASET, KEYLENGTH, GTEQ:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_startbr.html
* [READNEXT] EXEC CICS READNEXT, INTO, LENGTH, KEYLENGTH, ENDFILE (RESP2 90):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_readnext.html
* [READPREV] EXEC CICS READPREV, INTO, LENGTH, KEYLENGTH, ENDFILE (RESP 20, RESP2 90):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_readprev.html
* [ENDBR] EXEC CICS ENDBR:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_endbr.html

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes, the
length every `RIDFLD` and `KEYLENGTH` of the case names), `RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method
Services, DEFINE CLUSTER): KEYS(length offset) "specifies the length and position of the key field of the records in a key-sequenced
data set". A CICS file definition carries no key, so the case states it here.
