# hc-file-delete: DELETE of a KSDS record by RIDFLD, after READ UPDATE, and GENERIC with KEYLENGTH; NOTFND RESP2 80, INVREQ RESP2 31

## The trap

`HCDELF` (transid `HC98`) is typed with a mode after `HC98`. It works on file `HCDL`, a KSDS seeded from `data/HCDL.dat` (five 16-byte
records: key 4, name 8, quantity 4: `A100`, `A200`, `A300`, `B100`, `B300`), and logs each command's result to TS queue `HCLOG`. Item
format, 33 bytes: tag (3), ` R=`, RESP (2), ` S=`, RESP2 (3, zero unless RESP is not NORMAL), ` D=`, a 16-byte record (the record a READ
returned; blanks for any other command). Every READ passes `LENGTH(16)`.

* **K**: `DELETE RIDFLD(A200)`, `READ` of `A200`, `DELETE` of `A200` again, `DELETE` of the absent key `Z999`, `READ` of `A100`.
* **U**: `DELETE` with no RIDFLD before any `READ UPDATE`, then `READ UPDATE` of `A300`, `DELETE` with no RIDFLD, `READ` of `A300`.
* **G**: `DELETE GENERIC KEYLENGTH(1)` with RIDFLD `A`, `READ` of `A100`, the same generic `DELETE` again, `DELETE GENERIC KEYLENGTH(2)`
  with RIDFLD `B1`, `READ` of `B300`.

## Why a naive translation breaks

* A port that implements DELETE as a map `remove` that ignores a missing key answers NORMAL for `A200` the second time and for `Z999`;
  IBM raises NOTFND.
* A port that treats the generic key as an exact key deletes nothing for `A` (NOTFND), or one record only; IBM deletes every record whose
  key begins with the KEYLENGTH bytes.
* A port that ignores the held record deletes nothing (or the wrong record) for a DELETE with no RIDFLD, or lets a DELETE with no RIDFLD succeed when
  no READ UPDATE has been issued; IBM raises INVREQ RESP2 31.
* A generic delete that removes `B300` along with `B100` (a prefix of 1 instead of 2) is caught by the final file and by G5.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCDL` is local, VSAM KSDS, not recoverable, enabled, opened on first use, allowing delete, read and
update; each scenario starts at 10:00:00 on 2026-03-02 with `HC98 <mode>` typed on T001. NOTFND is RESP 13, INVREQ RESP 16 [RESP-CODES].

* **`keyed`** (K): K1 `DELETE` of `A200` is NORMAL; the page says "You identify, in the RIDFLD option, the specific record to be deleted"
  (paraphrased: RIDFLD identifies the record) [DELETE]. K2 `READ` of `A200` is NOTFND RESP2 80. K3 the same `DELETE` is NOTFND RESP2 80:
  "An attempt to delete a record based on the search argument provided is unsuccessful." [DELETE]. K4 `Z999` likewise. K5 `READ` of
  `A100` returns it unchanged. Final file: seed minus `A200`.
* **`update`** (U): U1 a `DELETE` with no RIDFLD when no `READ UPDATE` has been issued is INVREQ RESP2 31: "A DELETE command without the
  RIDFLD option is issued ... for which no previous READ UPDATE command has been issued" [DELETE] (the ellipsis joins the page's
  two clauses). The case issues it first, before any READ UPDATE, so no scenario relies on whether a *second* tokenless DELETE after a
  completed one is 31 (the page's NOTFND text covers "a DELETE without RIDFLD" for a record already deleted with RIDFLD, a different
  sequence). U2 `READ UPDATE` of `A300` is NORMAL: UPDATE "specifies that the record is to be obtained for updating or (for VSAM and data
  tables) deletion" [READ]. U3 `DELETE` with no RIDFLD removes the record read for update (the page: omit RIDFLD when deleting the record
  just read for update; paraphrase), NORMAL. U4 `READ` of `A300` is NOTFND RESP2 80: "An attempt to retrieve a record based on the search
  argument provided is unsuccessful." [READ]. Final file: seed minus `A300`.
* **`generic`** (G): G1 `DELETE GENERIC KEYLENGTH(1)` of `A` is NORMAL and deletes `A100`, `A200` and `A300`: GENERIC "Specifies that
  the search key is a generic key with a length specified in the KEYLENGTH option"; KEYLENGTH "must be specified if GENERIC is specified"
  (the page's wording, shortened) and "You must specify this option [RIDFLD] if you have also specified GENERIC" [DELETE]; the page
  describes GENERIC as deleting a group of records. G2 `READ` of `A100` is NOTFND RESP2 80. G3 the same generic delete matches nothing:
  NOTFND RESP2 80 (the NOTFND text above; the page does not name the generic case, see the README lower-confidence table). G4
  `KEYLENGTH(2)` of `B1` deletes `B100` only. G5 `READ` of `B300` returns it. Final file: `B300` only.
* RESP values: NOTFND is RESP 13 and INVREQ RESP 16 [RESP-CODES].

Quotes were read from the IBM pages on 2026-11-10 through a page-extraction tool, so the wording is as extracted, not guaranteed
byte-for-byte; re-check against the live page when a quote is relied on.

## What a correct port must do

* Delete the record RIDFLD names, answering NOTFND RESP2 80 when none matches, and leave every other record alone.
* With GENERIC, delete every record whose first KEYLENGTH bytes equal the generic key; NOTFND RESP2 80 when there are none.
* With no RIDFLD, delete the record a READ UPDATE holds and release it; INVREQ RESP2 31 when no READ UPDATE has been issued.
* Report RESP and RESP2 of every DELETE in the event log (`DELETE` event: `file`, `ridfld` when given, `resp`, `resp2`).

## Avoided ambiguities

* **NUMREC** (the count of records a generic delete removed), **TOKEN**, **MASSINSERT**, **RLS**, recoverable files and syncpoint locks,
  remote files, **ESDS** or **non-KSDS generic** (INVREQ RESP2 21 / 22), **KEYLENGTH not shorter than the key** (RESP2 25), **negative
  KEYLENGTH** (42), **KEYLENGTH without GENERIC** (26), **NOTOPEN / DISABLED**: not used.
* **Whether a generic delete leaves the browse or a READ UPDATE hold**: not used; no hold is open at a generic delete.
* **A second tokenless DELETE after a completed one**: not used (see `update` above); INVREQ RESP2 31 is asserted only before any READ UPDATE.
* **NUMREC and the KEYLENGTH zero value** ("Do not specify a zero value for KEYLENGTH because the results are unpredictable" [DELETE]): not used.
* **Default action of NOTFND / INVREQ** (terminate the task abnormally): the program passes `RESP`, so the task is not abended.
* **Order of records**: the final file lists records in key order (a KSDS).

## Citations

* [DELETE] CICS TS 6.x, EXEC CICS DELETE (file control), description, GENERIC, KEYLENGTH, RIDFLD, conditions (NOTFND RESP2 80, INVREQ
  RESP2 31; the RESP2 list read 2026-11-10):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_delete.html
* [READ] CICS TS 6.x, EXEC CICS READ (file control), UPDATE and NOTFND:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NOTFND 13, INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes),
`RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the
length and position of the key field of the records in a key-sequenced data set".
