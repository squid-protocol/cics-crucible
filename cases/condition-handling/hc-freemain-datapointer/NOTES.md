# hc-freemain-datapointer: FREEMAIN DATAPOINTER(ptr) releases what GETMAIN returned; an address GETMAIN never returned is INVREQ RESP2 1

## The trap

`FREEMAIN DATAPOINTER(ptr)` names the storage to release by the pointer GETMAIN put in `ptr`. The sibling case
`ca-getmain-pointer` frees through `FREEMAIN DATA(area)` only; this one covers the pointer form. GETMAIN and FREEMAIN are
not events (SPEC 6.2), so every result is a record in TS queue `FMLOG` (copybook `FMLOG`, 26 bytes: tag X(4), RESP 9(3),
RESP2 9(3), data X(16); RESP2 is logged only when the command raised a condition).

`HCFMRL` (transaction `HCFM`) gets two 8-byte blocks (`INITIMG` `A` and `B`), views them with `SET ADDRESS OF`, writes
`FIRST-01` through the first view, frees the first block with `FREEMAIN DATAPOINTER(WS-P1)`, writes `LATER-02` through
the second view and frees it the same way.
`HCFMIV` (transaction `HCFN`) frees the address of one of its own WORKING-STORAGE items (`SET WS-PWS TO ADDRESS OF
WS-KEEP`), then does a GETMAIN and a FREEMAIN to show the failure left the task's storage commands working.

## Why a naive translation breaks

* A port that models FREEMAIN as a no-op, or that frees every block the task holds, breaks the second block in `HCFMRL`
  (`VW03` must read `LATER-02`, and `FR02` must be NORMAL).
* A port that answers NORMAL for any pointer, because "freeing" only drops a map entry, hides INVREQ RESP2 1 for the address of
  a program's own item (`IV01`).
* A port that raises a Java exception or abends the task on that INVREQ, or that lets it clear the item, fails `IV01` /
  `IV02`.
* A port whose pointer lookup breaks after a failed FREEMAIN fails `GM01` / `VW01` / `FR01` of `HCFMIV`.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal `T001`, the clock 2026-03-02T10:00:00, program autoinstall off.

* **`release`** (`HCFM`, `HCFMRL`):
  1. `GETMAIN SET(WS-P1) FLENGTH(8) INITIMG('A')`: NORMAL (`GM01`). The same with `WS-P2` and `'B'` (`GM02`). "FREEMAIN
     releases ... Main storage that was acquired by a GETMAIN command that is issued by the application" [FREEMAIN].
  2. `SET ADDRESS OF LS-FIRST TO WS-P1`, `SET ADDRESS OF LS-SECOND TO WS-P2` [SET5]; `MOVE 'FIRST-01' TO LS-FIRST`:
     `VW01` reads `FIRST-01`; `VW02` reads `BBBBBBBB`: the blocks are separate, every byte the `INITIMG` value [GETMAIN].
  3. `FREEMAIN DATAPOINTER(WS-P1)`: the storage `WS-P1` addresses was acquired by GETMAIN, so NORMAL (`FR01`).
  4. `MOVE 'LATER-02' TO LS-SECOND`: the second block was not released, so `VW03` reads `LATER-02`. `FREEMAIN
     DATAPOINTER(WS-P2)`: NORMAL (`FR02`). `RETURN` at level 1.
* **`invreq`** (`HCFN`, `HCFMIV`):
  1. `SET WS-PWS TO ADDRESS OF WS-KEEP`: "ADDRESS OF identifier-7 contains the address of the identifier" [SET5], an item of
     the program's WORKING-STORAGE. `FREEMAIN DATAPOINTER(WS-PWS) RESP RESP2`: that address is not storage a GETMAIN
     acquired, so INVREQ (16), RESP2 1 [FREEMAIN] [RESP-CODES] (`IV01`, `016001`).
  2. `WS-KEEP` is unchanged: `KEEPME!!` (`IV02`).
  3. `GETMAIN SET(WS-PGM) FLENGTH(8) INITIMG('Q')`: NORMAL (`GM01`); the view reads `QQQQQQQQ` (`VW01`); `FREEMAIN
     DATAPOINTER(WS-PGM)`: NORMAL (`FR01`). `RETURN` at level 1.

## What a correct port must do

* Release exactly the block the pointer addresses (its first byte), leaving every other block of the task usable.
* Answer INVREQ RESP2 1 for an address GETMAIN did not return, with RESP and RESP2 set and no abend (RESP is given), the
  item's bytes untouched, and later GETMAIN / FREEMAIN working.

## Avoided ambiguities

* **A null pointer.** IBM's page names storage "not acquired by GETMAIN"; what a null address does is not stated, so the
  INVREQ is provoked with the address of a real WORKING-STORAGE item instead.
* **A second FREEMAIN of the same storage, and any use of a view after its block is freed.** IBM does not say what either
  does (INVREQ, reused storage or a program check); no view is touched after its block is released and no block is freed twice.
* **A pointer into the middle of a block** (an offset from the first byte): not freed.
* **Pointer size and the numeric value of any pointer.** Pointers are only set, copied to `SET ADDRESS OF` and passed to
  FREEMAIN; no arithmetic or comparison.
* **Storage location and key.** No BELOW, USERDATAKEY or CICSDATAKEY; nothing depends on the DSA that supplies the bytes.
* **The unhandled INVREQ.** Every FREEMAIN uses RESP, so the default action (task abend) is never reached.

## Citations

* [GETMAIN] CICS TS 6.x, EXEC CICS GETMAIN (SET: the pointer is set to the first byte of the acquired storage; INITIMG: "CICS
  sets every byte of the acquired storage to the bit string you provide"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-getmain
* [FREEMAIN] CICS TS 6.x, EXEC CICS FREEMAIN (description; DATAPOINTER; INVREQ RESP2 1 for storage not acquired by GETMAIN): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-freemain
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (INVREQ 16): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [SET5] Enterprise COBOL for z/OS 6.3 Language Reference, Format 5: SET for USAGE IS POINTER data items ("ADDRESS OF
  identifier-7 contains the address of the identifier, and not the content of the identifier"): https://www.ibm.com/docs/SS6SG3_6.3.0/lr/ref/rlpssete.html
* cics-crucible condition-handling / hc-freemain-datapointer
