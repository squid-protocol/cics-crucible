# hc-file-unlock: READ UPDATE / REWRITE / UNLOCK on a KSDS, REWRITE after UNLOCK is INVREQ RESP2 30, UNLOCK with nothing held is NORMAL

## The trap

`HCUNLK` (transaction `HC81`) is typed with a mode after `HC81`. It works on file `HCUF`, a KSDS seeded from `data/HCUF.dat`
(three 16-byte records: key 4, name 8, quantity 4) and logs each command's result to TS queue `HCLOG`. Item format, 33 bytes: tag (3),
` R=`, RESP (2), ` S=`, RESP2 (3), ` D=`, a 16-byte record (the record READ returned; blanks for any other command). RESP2 is logged only
for a command that failed.

* **R**: `READ FILE UPDATE` of `K002`, change the quantity to `0099`, `REWRITE`, `READ` it again.
* **U**: `READ FILE UPDATE` of `K002`, `UNLOCK FILE`, `REWRITE` (the update is no longer pending), `READ` it again.
* **N**: `UNLOCK FILE` when no READ UPDATE was issued, `REWRITE` when no READ UPDATE was issued, `READ` of `K001`.

## Why a naive translation breaks

* A port that treats UNLOCK as a no-op (or REWRITE as an independent write) lets the REWRITE in `U` succeed and changes the record
  to `0099`; IBM raises INVREQ because the READ UPDATE is gone.
* A port that has no READ UPDATE state raises an error on the UNLOCK in `N`; IBM answers NORMAL.
* A port that answers the failed REWRITE with a bare INVREQ drops RESP2 30, which tells it apart from the other INVREQ causes.

## Expected behaviour

Model (SPEC section 2): file `HCUF` is local, VSAM KSDS, not recoverable, enabled, opened on first use; each scenario starts at
10:00:00 on 2026-03-02 with `HC81 <mode>` typed on T001. Every command passes `LENGTH(16)`, the record length.

* **`update-rewrite`** (R): R1 `READ ... UPDATE` returns `K002BRAVO   0020` [READ]: UPDATE "specifies that the record is to be
  obtained for updating"; the RIDFLD key is the first 4 bytes. R2 `REWRITE` is NORMAL: the page says a REWRITE "must always follow a
  READ with the UPDATE option" [REWRITE] (it does, with the key unchanged). R3 `READ` without UPDATE ("If this option is omitted, a
  read-only operation is assumed" [READ]) returns the rewritten record `K002BRAVO   0099`. Final file: `K002` holds `0099`.
* **`unlock-rewrite`** (U): U1 as R1. U2 `UNLOCK` is NORMAL: it "releases the exclusive control established in response to a read
  command with the UPDATE option" and, with no TOKEN, is matched to the READ UPDATE issued without a token [UNLOCK]. U3 `REWRITE`:
  INVREQ (RESP 16), RESP2 30, "No token was supplied, and no earlier READ for UPDATE without a token can be found" [REWRITE]: the
  only READ UPDATE this task made was released by U2. U4 `READ` returns the original `K002BRAVO   0020`: the REWRITE changed nothing.
  Final file: unchanged.
* **`unlock-nothing`** (N): N1 `UNLOCK` with no READ UPDATE and no token: "If neither of these is found, no action is taken and a
  NORMAL response is returned" [UNLOCK]. N2 `REWRITE` with no READ UPDATE: INVREQ RESP2 30, the same condition as U3 (no earlier
  READ for UPDATE without a token exists) [REWRITE]. N3 `READ` of `K001` returns `K001ALPHA   0010`. Final file: unchanged.
* In every scenario the program sends `DONE OK` and RETURNs; INVREQ is RESP 16 [RESP-CODES].

## What a correct port must do

* Keep one pending READ UPDATE per file per task; REWRITE needs it and consumes it; UNLOCK releases it.
* Answer UNLOCK with nothing pending NORMAL, and a REWRITE with nothing pending INVREQ RESP2 30, leaving the record untouched.

## Avoided ambiguities

* **RESP2 of a command that completed**: IBM states none, so no event carries it for a NORMAL command.
* **INTO / FROM after a failed command**: the failed REWRITE's FROM is the program's; READ is logged only when NORMAL.
* **LENGTH on a fixed or variable length file**: every command passes the actual record length (16), so no scenario depends on
  which length rules apply (LENGERR RESP2 10 / 13 on READ, 10 / 14 on REWRITE are not provoked).
* **A second READ UPDATE without TOKEN while one is held** (INVREQ on READ), **REWRITE twice after one READ UPDATE**, **REWRITE
  that changes the key**, **TOKEN**, **READ UPDATE of a missing record** (NOTFND 80), recoverable files and syncpoint locks, RLS,
  data tables, browse (STARTBR / READNEXT with UPDATE): not used. The file is not recoverable and no other task touches it.
* **NOTOPEN / DISABLED**: the file is enabled and opens on first reference; no scenario closes it.

## Citations

* [READ] CICS TS 6.x, EXEC CICS READ (file control), UPDATE, RIDFLD, INTO, LENGTH, conditions:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_read.html
* [REWRITE] CICS TS 6.x, EXEC CICS REWRITE, description and conditions (INVREQ RESP2 30): 
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_rewrite.html
* [UNLOCK] CICS TS 6.x, EXEC CICS UNLOCK, description and conditions:
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-applications/commands-api/dfhp4_unlock.html
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
