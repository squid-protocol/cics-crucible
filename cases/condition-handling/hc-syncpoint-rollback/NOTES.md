# hc-syncpoint-rollback: SYNCPOINT ends a READ UPDATE hold; SYNCPOINT ROLLBACK backs out nothing on a non-recoverable file

## The trap

`HCSYNC` (transaction `HC91`) is typed with a mode after `HC91`. It works on file `HCSF`, a KSDS seeded from `data/HCSF.dat`
(three 16-byte records: key 4, name 8, quantity 4; not recoverable, SPEC section 2), and logs each command's result to TS queue
`HCLOG`. Item format, 27 bytes: tag (3), ` R=`, RESP (2), ` D=`, a 16-byte record (the record READ returned; blanks otherwise).

* **R**: `READ UPDATE` of `K002`, `REWRITE` it with quantity `0099`, `SYNCPOINT ROLLBACK`, `READ` it again.
* **C**: `READ UPDATE` of `K002`, `SYNCPOINT`, `REWRITE` (the hold is gone), `READ` it again.
* **L**: as R up to the REWRITE, then `LINK` to `HCSYNB`, which logs, issues `SYNCPOINT ROLLBACK`, logs and RETURNs; the caller `READ`s again.

## Why a naive translation breaks

* A port that treats SYNCPOINT ROLLBACK as "undo every write of the task" restores `0020` in R and L; here the file is not
  recoverable and the record stays `0099`.
* A port that keeps a READ UPDATE hold across SYNCPOINT answers the REWRITE in C with NORMAL and stores `0099`; the hold is over,
  so the REWRITE is INVREQ and the record keeps `0020`.
* A port that does not record SYNCPOINT / SYNCPOINT ROLLBACK as events loses the unit-of-work boundary the log asserts.

## Expected behaviour

Model (SPEC sections 2 and 4): file `HCSF` is local, VSAM KSDS, not recoverable, enabled, opened on first use; each scenario
starts at 10:00:00 on 2026-03-02 with `HC91 <mode>` typed on T001.

* **`rollback-keeps`** (R): R1 `READ UPDATE` returns `K002BRAVO   0020`; R2 `REWRITE` with `0099` is NORMAL (and ends the hold);
  `SYNCPOINT ROLLBACK` is NORMAL (R3). R4 `READ` returns `K002BRAVO   0099`: IBM backs out "changes to recoverable resources"
  [SYNCPOINT], and `HCSF` is not one (SPEC section 2), so nothing is backed out. Final file: `K002` has `0099`.
* **`commit-ends-hold`** (C): C1 `READ UPDATE` returns `0020`; `SYNCPOINT` is NORMAL (C2). The `REWRITE` that follows has no hold:
  INVREQ (RESP 16), RESP2 30, as after an UNLOCK (hc-file-unlock) [REWRITE]; the READ page names SYNCPOINT beside REWRITE, DELETE
  and UNLOCK as the commands that end the hold (INVREQ RESP2 28) [READ]. C3 logs R=16; C4 `READ` returns `0020`. Final file unchanged.
* **`link-rollback`** (L): L1 `READ UPDATE`, L2 `REWRITE` `0099`; `LINK` to `HCSYNB` (a local LINK: same task, same unit of work);
  B1, `SYNCPOINT ROLLBACK` NORMAL, B2, RETURN to the caller; L3 logs R=00; L4 `READ` returns `0099`. The callee's rollback does not
  end the caller: the program goes on.
* Each scenario sends `DONE OK` and RETURNs. The `SYNCPOINT` / `SYNCPOINT-ROLLBACK` events carry `resp` NORMAL (SPEC 6.2).

## What a correct port must do

* Record `SYNCPOINT` and `SYNCPOINT ROLLBACK` as events with their RESP.
* End the READ UPDATE hold at SYNCPOINT (and ROLLBACK); the next REWRITE without a hold is INVREQ RESP2 30.
* Leave the records of a non-recoverable file as they are on ROLLBACK.

## Avoided ambiguities

* **Rollback of a non-recoverable file is a reading.** The SYNCPOINT page speaks only of changes to recoverable resources; no sentence
  says "a non-recoverable file is not backed out". The SYNCPOINT page fetched for this case shows no ROLLBACK option, and no
  separate SYNCPOINT ROLLBACK page was opened: R and L rest on this reading (SPEC 6.2 says so); C does not.
* **Recoverable files** (backout, syncpoint locks, log(UNDO)), **a ROLLBACK after a SYNCPOINT in one task**, **DPL** (SYNCPOINT in a
  program LINKed from a remote system: INVREQ RESP2 200 [SYNCPOINT]; a local LINK to a DPLSUBSET program is not used), **ROLLEDBACK
  (82)**, **TS / TD queues in the unit of work**: not used. `HCLOG` is main TS, not recoverable, so its items survive the rollbacks.

## Citations

* [SYNCPOINT] CICS TS 6.x, EXEC CICS SYNCPOINT ("all changes to recoverable resources made by the task since its last syncpoint are
  to be committed"; ROLLEDBACK: "All changes made to recoverable resources in the current unit of work are backed out"; INVREQ RESP2 200):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_syncpoint.html
* [READ] CICS TS 6.x, EXEC CICS READ (INVREQ RESP2 28: a second READ UPDATE "without an intervening REWRITE, DELETE without RIDFLD
  specified, UNLOCK, or SYNCPOINT command"):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [REWRITE] CICS TS 6.x, EXEC CICS REWRITE (INVREQ RESP2 30, no earlier READ for UPDATE):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_rewrite.html

## Stated key

`jcl/DEFVSAM.jcl` is the IDCAMS DEFINE CLUSTER for the CSD file's DSNAME: INDEXED, `KEYS(4 0)` (the key is the first 4 bytes, the length every `RIDFLD` of the case names), `RECORDSIZE(16 16)` (the seed record width). IBM (z/OS DFSMS Access Method Services, DEFINE CLUSTER): KEYS(length offset) "specifies the length and position of the key field of the records in a key-sequenced data set".
