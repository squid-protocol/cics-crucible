# ca-getmain-pointer: GETMAIN SET(ptr), SET ADDRESS OF, pointer arithmetic, FREEMAIN

## The trap

A COBOL program can get storage that has no declaration: `GETMAIN SET(ptr) FLENGTH(n)` hands back a
pointer, `SET ADDRESS OF item TO ptr` lays a LINKAGE item over it, and `FREEMAIN` gives it back.
`CAGMPT` (transaction `CA0B`) gets 16 bytes initialised to `Z` (`INITIMG`), views them as a
`LS-AREA` (`LS-HEAD` X(4), `LS-BODY` X(12)), writes through it, reaches `LS-BODY`'s bytes a second
way by adding 4 to a copy of the pointer (through a binary `REDEFINES`) and a third way with
`SET pointer TO ADDRESS OF LS-BODY`, writes through the third view, and frees the storage.
`CAGMZ` (`CA0C`) asks for a length below 1 three ways. GETMAIN and FREEMAIN are not events
(SPEC 6.2), so every result is a record in TS queue `GMLOG` (copybook `GMLOG`, 26 bytes: tag X(4),
RESP 9(3), RESP2 9(3), data X(16); RESP2 is logged only when the command raised a condition).

## Why a naive translation breaks

* A port that models GETMAIN as a plain `new byte[n]` and a `SET ADDRESS OF` as a typed copy
  loses the aliasing: three views of one area must see each other's writes (`GM07`).
* A port that ignores `INITIMG` leaves zeros (or garbage) where IBM guarantees the byte given
  (`GM02`, `VIEW`).
* A port that cannot add to a pointer, or that gives `ADDRESS OF` a subordinate item a fresh
  copy instead of its offset into the parent, gets `GM04` / `GM05` / `GM06` wrong.
* A port that treats FLENGTH 0 as an empty successful allocation, or throws a Java exception,
  hides LENGERR RESP2 1 and the zeroed pointer (`GMF0`, `GMFN`, `GML0`).
* A port that frees only the length of the FREEMAIN data area, or reports INVREQ for a view
  that starts at the storage's first byte, fails `FM01`.

## Expected behaviour

### `alloc` (`CA0B`, `CAGMPT`)

1. `GETMAIN SET(WS-PTR) FLENGTH(16) INITIMG(WS-FILL)` with `WS-FILL` = `Z`: "GETMAIN gets a main
   storage area of the size that is indicated by the FLENGTH option. The address of the area is
   returned in the pointer reference that is supplied in the SET option" [GETMAIN]. NORMAL
   (`GM01`, `000000`).
2. `SET ADDRESS OF LS-AREA TO WS-PTR`: the item is now at the storage's address [SET5] [ADDROF].
   "If you specify INITIMG, CICS sets every byte of the acquired storage to the bit string you
   provide" [GETMAIN]: `LS-AREA` is sixteen `Z` (`GM02`).
3. `LS-HEAD` = `HEAD`, `LS-BODY` = `ABCDEFGHIJKL`: `LS-AREA` reads `HEADABCDEFGHIJKL` (`GM03`).
4. `SET WS-PTR2 TO WS-PTR`, `ADD 4 TO WS-PTR2-N` (a binary item that REDEFINES the pointer: "A
   pointer data item can be the subject or object of a REDEFINES clause" [POINTER]),
   `SET ADDRESS OF LS-TAIL TO WS-PTR2`: the view starts 4 bytes in, where `LS-BODY` is, so it
   reads `ABCDEFGHIJKL` (`GM04`). This reads the pointer as a byte address (README lower-confidence
   table).
5. `SET WS-PSUB TO ADDRESS OF LS-BODY`: "identifier-7 must name an item of any level except 66 or
   88 in the LINKAGE SECTION, the WORKING-STORAGE SECTION, or the LOCAL-STORAGE SECTION" and
   "ADDRESS OF identifier-7 contains the address of the identifier, and not the content of the
   identifier" [SET5]. `SET ADDRESS OF LS-SUB TO WS-PSUB` gives a 12-byte view that reads
   `ABCDEFGHIJKL` (`GM05`).
6. "Pointer data items can be compared for equality" [POINTER]: `WS-PSUB` equals `WS-PTR2` (base
   plus 4) and is not equal to `WS-PTR` (the base): `EQ=Y NEBASE=Y` (`GM06`).
7. `MOVE 'MNOPQRSTUVWX' TO LS-SUB`: the three views are one area, so `LS-AREA` reads
   `HEADMNOPQRSTUVWX` (`GM07`).
8. `FREEMAIN DATA(LS-AREA)`: "FREEMAIN releases ... Main storage that was acquired by a GETMAIN
   command that is issued by the application", and the INVREQ RESP2 1 case is storage "not
   storage that is acquired by a GETMAIN command" [FREEMAIN]. `LS-AREA` is at the first byte of
   what GETMAIN returned, so NORMAL (`FM01`). `RETURN` at level 1.

### `zero-length` (`CA0C`, `CAGMZ`)

Each GETMAIN starts with `WS-PTR` set to the address of `WS-DUMMY` (non-zero); `ZERO=` says
whether the pointer, copied to `WS-PTR2` and read through its binary REDEFINES, is zero.

1. `PRE0`: before any GETMAIN `ZERO=N`.
2. `FLENGTH(0)`: LENGERR (22), RESP2 1: "The FLENGTH value is less than 1 or greater than the
   length of the target dynamic storage area from which the request is to be satisfied"
   [GETMAIN] [RESP-CODES]. "A LENGERR condition that results from a zero or negative value that
   is specified for FLENGTH or LENGTH sets ptr-ref to zero" [GETMAIN]: `ZERO=Y` (`GMF0`).
3. `FLENGTH(-1)`: a negative value, so LENGERR RESP2 1 and `ZERO=Y` (`GMFN`).
4. `LENGTH(0)` (halfword): "If the value of LENGTH is zero, a LENGERR condition occurs"; RESP2 1
   "Also occurs if the LENGTH value is zero"; pointer zero (`GML0`).
5. A valid `FLENGTH(8) INITIMG('Q')` after the failures: NORMAL, `ZERO=N` (`GMOK`); the view reads
   `QQQQQQQQ` (`VIEW`); `FREEMAIN DATA(LS-CHK)` NORMAL (`FMOK`).

## What a correct port must do

* Return a pointer to a fresh area of exactly the requested length, every byte `INITIMG` when
  given, and make every `SET ADDRESS OF` view of it, and every pointer derived from it by adding
  an offset or by `ADDRESS OF` a subordinate item, alias the same bytes.
* Compare pointers by address.
* Raise LENGERR RESP2 1 for FLENGTH or LENGTH below 1 and leave the pointer zero.
* Accept FREEMAIN of an item that starts where a GETMAIN's storage starts.

## Avoided ambiguities

* **Pointer size.** The arithmetic needs a 4-byte pointer: "If LP(32) is in effect, 4 bytes are
  allocated for the item" [POINTER]. The case assumes LP(32) (so that the 4-byte binary
  REDEFINES covers the whole pointer); under LP(64) it would not. GnuCOBOL has no POINTER-32,
  the one type that is 4 bytes under both options, so it is not used.
* **The numeric value of any pointer.** Only equality, the offset of 4 and zero are asserted,
  never an address.
* **Storage after FREEMAIN.** No view is read after the free, and a second FREEMAIN of the same
  storage (INVREQ RESP2 1 or reused storage) is not issued.
* **INITIMG without the option, and the contents of storage from a failed GETMAIN.** Every
  successful GETMAIN here gives INITIMG; the page says only that without it "CICS does not
  initialize the storage".
* **Storage location and key.** No BELOW, USERDATAKEY or CICSDATAKEY is named; nothing depends
  on which DSA supplies the 16 or 8 bytes.
* **NOSTG, and FLENGTH above the DSA limit** (the other half of LENGERR RESP2 1): not provoked.
* **The unhandled LENGERR.** Every GETMAIN uses RESP, so the default action (task abend) is never
  reached.

## Citations

* [GETMAIN] CICS TS 6.x, EXEC CICS GETMAIN (description; SET: "Sets the pointer reference to the address of the acquired main storage. The pointer is set to the first byte of the storage area. A LENGERR condition that results from a zero or negative value that is specified for FLENGTH or LENGTH sets ptr-ref to zero"; INITIMG: "If you specify INITIMG, CICS sets every byte of the acquired storage to the bit string you provide. Otherwise, CICS does not initialize the storage" and, for COBOL, a data area is used; LENGTH: "If the value of LENGTH is zero, a LENGERR condition occurs"; LENGERR RESP2 1): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-getmain
* [FREEMAIN] CICS TS 6.x, EXEC CICS FREEMAIN (description; DATA: "The length of storage that is released is the length that was obtained by the GETMAIN command and not necessarily the length of the data area"; INVREQ RESP2 1): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-freemain
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (LENGERR 22, INVREQ 16): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [ADDROF] Enterprise COBOL for z/OS 6.5 Language Reference (SC27-8713-04), special registers, ADDRESS OF: "The ADDRESS OF special register references the address of a data item in the LINKAGE SECTION, the LOCAL-STORAGE SECTION, or the WORKING-STORAGE SECTION"; "For 01 and 77 level items in the LINKAGE SECTION, the ADDRESS OF special register can be used as either a sending item or a receiving item. For all other operands, the ADDRESS OF special register can be used only as a sending item"; "The ADDRESS OF special register is implicitly defined as USAGE POINTER": https://www.ibm.com/docs/en/SS6SG3_6.5/pdf/lrmvs.pdf
* [SET5] Enterprise COBOL for z/OS 6.3 Language Reference, Format 5: SET for USAGE IS POINTER data items ("identifier-5 must be level-01 or level-77 items defined in the LINKAGE SECTION. The addresses of these items are set to the value of the operand specified in the TO phrase"; identifier-7 and "ADDRESS OF identifier-7 contains the address of the identifier, and not the content of the identifier"): https://www.ibm.com/docs/SS6SG3_6.3.0/lr/ref/rlpssete.html
* [POINTER] Enterprise COBOL for z/OS 6.3 Language Reference, POINTER phrase ("If LP(32) is in effect, 4 bytes are allocated for the item"; "Pointer data items can be compared for equality or moved to other pointer items"; "A pointer data item can be the subject or object of a REDEFINES clause"): https://www.ibm.com/docs/SS6SG3_6.3.0/lr/ref/rlddepoi.html
