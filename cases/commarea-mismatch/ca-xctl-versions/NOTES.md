# ca-xctl-versions: XCTL between two COMMAREA versions

## The trap

`CAXA` (transaction `CA02`) is an old front end that knows only the 10-byte version-1
COMMAREA: version, customer id, visit count. It XCTLs to `CAXB`, which speaks the 80-byte
version-2 layout (copybook `CAV2`: the V1 fields, then tier, a packed balance and a note).
CAXB decides which version it received **by EIBCALEN**. Fewer than 80 bytes means an old
caller: it copies what came and defaults the rest. Exactly 80 bytes means every field is
taken as given. CAXB then continues pseudo-conversationally as transaction `CA03`, passing
the 80-byte area to itself, until PF3.

| Mode | XCTL | Effect |
|---|---|---|
| S | `COMMAREA(WS-V1) LENGTH(10)` | a true V1 area; CAXB upgrades it |
| L | `COMMAREA(WS-V1) LENGTH(80)` | 80 bytes copied from WS-V1's address. The last 70 are CAXA's *next* working storage (`GOLD`, +12345.67, a note), which CAXB takes as V2 fields |
| X | `COMMAREA(WS-BIG) LENGTH(32767)` | outside 0-32763: LENGERR, RESP2 11 |

## Why a naive translation breaks

* **Truncate and pad:** a port that maps COMMAREAs to typed objects converts the V1 object
  to a V2 object when passing it. That loses the distinction CAXB makes from EIBCALEN, so
  there is no `L=0010` and no upgrade. For `long-overread` it gives blank or zero tier and
  balance where real CICS delivers the caller's neighbouring bytes (`GOLD`, 12345.67).
* **Binary layout:** V2-BALANCE is COMP-3 (5 bytes), sitting between display fields. A port
  that serialises the COMMAREA as text or JSON between turns breaks byte offsets for any
  program that reads the area by position (CAXB's `DFHCOMMAREA(1:EIBCALEN)` move).
* **XCTL is not a call:** after a successful XCTL, CAXA is gone. The code after it (the
  "XCTL FAILED" report) runs only when the XCTL itself fails. A port that makes XCTL a method
  call returns into CAXA and sends a second screen.
* **LENGTH range:** XCTL fails with LENGERR (RESP2 11) for a LENGTH outside 0-32763, even
  though the COBOL item really is 32767 bytes long.
* EIBTRNID stays `CA02` in CAXB after the XCTL (the transaction does not change). CAXB
  checks for PF3 only under `CA03`.

## Expected behaviour

* **`short-upgrade`**
  * Task 1: `CA02 S` typed; RECEIVE returns `CA02 S` (6 bytes). XCTL LENGTH(10) passes the
    10 V1 bytes: "the contents of the data-area are passed" [XCTL], and CAXB runs at the same
    level with EIBCALEN = 10. CAXB INITIALIZEs WS-V2 and defaults TIER `STANDARD`, BALANCE
    0, NOTE `UPGRADED FROM V1`. Since 10 < 80, it copies 10 bytes (VERSION `1`, CUSTID
    `C0042`, VISITS 0007) and sets VERSION `2`. VISITS becomes 8. It sends
    `V=2 C=C0042 N=0008 T=STANDARD   B=+0000000.00 L=0010 UPGRADED FROM V1`, then does
    RETURN TRANSID('CA03') COMMAREA(WS-V2) LENGTH(80) [RETURN].
  * Task 2 (ENTER): transaction CA03 → CAXB with EIBCALEN = 80 [RETURN]. It takes the whole
    area as given, and VISITS becomes 9. Same report with `N=0009 ... L=0080`. RETURN
    TRANSID('CA03') again.
  * Task 3 (PF3): CAXB sends `SESSION ENDED` and RETURNs with no TRANSID.
* **`long-overread`**: XCTL COMMAREA(WS-V1) LENGTH(80). CICS copies LENGTH bytes starting at
  the named area. [XCTL] documents LENGERR RESP2 28 for "LENGTH ... greater than the length
  of the data area ..., and while that data was being copied, a destructive overlap
  occurred", so a LENGTH longer than the item is copied, and fails only on overlap. Here
  there is no overlap: CICS "might copy the specified COMMAREA into a new area of storage,
  because the invoking program ... might no longer be available" [COMMAREA]. WS-V1 is the
  first 10 bytes of the contiguous 01 group WS-BLOCK, so the 80 bytes are WS-BLOCK:
  NB-TIER `GOLD`, NB-BALANCE +12345.67 (packed X'001234567C'), NB-NOTE. CAXB sees
  EIBCALEN = 80 and trusts every field: VERSION stays `1`, TIER `GOLD`, BALANCE 12345.67.
  The report shows `V=1 ... T=GOLD ... B=+0012345.67 L=0080 NEIGHBOUR STORAG`. Task 2 (PF3)
  ends the session.
* **`length-range`**: XCTL LENGTH(32767) → LENGERR, RESP2 11 ("LENGTH outside range 0 to
  32763" [XCTL]). RESP is given, so control continues in CAXA [RESP]. It sends
  `XCTL FAILED RESP=22 RESP2=11` (DFHRESP(LENGERR) = 22 [RESP-CODES]) and RETURNs.
  WS-BIGLEN is `PIC S9(4) COMP-5`: a halfword, as CICS requires for LENGTH, that can hold
  32767 (a `COMP` S9(4) item cannot, under TRUNC(STD)).
* **`direct-entry`**: `CA03` typed on a cleared screen starts CAXB directly (SPEC section 4:
  no TRANSID is pending, so the typed transaction id runs, with no COMMAREA). EIBCALEN
  "contains the length of the communication area that has been passed ... If no
  communication area is passed, this field contains binary zeros" [EIB]. EIBAID is ENTER, so
  the PF3 test is false. CAXB INITIALIZEs WS-V2 (VERSION and CUSTID blank, VISITS 0, BALANCE
  0), sets TIER `STANDARD` and NOTE `UPGRADED FROM V1`, and, since EIBCALEN = 0, never
  touches DFHCOMMAREA (which has no addressability). VISITS becomes 1. It sends
  `V=  C=      N=0001 T=STANDARD   B=+0000000.00 L=0000 UPGRADED FROM V1` (the note claims an
  upgrade that did not happen) and RETURNs TRANSID('CA03') with the 80-byte defaults. Task 2
  (PF3, EIBCALEN 80, EIBTRNID CA03) sends `SESSION ENDED` and RETURNs.

## What a correct port must do

* Pass XCTL and RETURN COMMAREAs as **byte arrays of exactly LENGTH bytes**, read from the
  named item's address in the caller's storage.
* Set EIBCALEN from that length, and let the receiving program overlay its own layout on the
  bytes.
* Make a successful XCTL terminate the calling program.
* Validate the length range and raise LENGERR with RESP2 11.
* Keep EIBTRNID unchanged across XCTL.

## Avoided ambiguities

* LENGTH longer than the named item runs only into the rest of the same 01 group
  (contiguous by COBOL rules), never into unrelated storage. The 32767-byte case uses an
  item that really is 32767 bytes, so a range check that runs after an attempted copy would
  still read only the program's own storage.
* Whether the XCTL copy is made into new storage or the caller's area is passed through
  (for a program passing on its own DFHCOMMAREA) cannot be observed here: CAXA's storage is
  never touched after the XCTL.
* LENGERR RESP2 28 (destructive overlap) is not provoked.
* `direct-entry` never references DFHCOMMAREA when EIBCALEN = 0, so what an unaddressed
  LINKAGE item would contain does not matter.

## Citations

* [COMMAREA] CICS TS 6.x, COMMAREA in LINK and XCTL commands (XCTL may copy; addressing mode): https://www.ibm.com/docs/en/cics-ts/6.x?topic=transaction-commarea-in-link-xctl-commands
* [XCTL] CICS TS 6.x, EXEC CICS XCTL (COMMAREA contents passed; LENGERR RESP2 11/26/28; calling program released): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-xctl
* [RETURN] CICS TS 6.x, EXEC CICS RETURN (TRANSID, COMMAREA up to 32763, EIBCALEN of the next task): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-return
* [RESP] CICS TS 6.1, How to use the RESP and RESP2 options: https://www.ibm.com/docs/en/cics-ts/6.1?topic=code-how-use-resp-resp2-options
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (LENGERR = 22): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [RECEIVE] CICS TS 5.5, EXEC CICS RECEIVE (z/OS Communications Server default): https://www.ibm.com/docs/en/cics-ts/5.5.0?topic=summary-receive-zos-communications-server-default
* [EIB] CICS TS 6.x, EIB fields (EIBCALEN is zero when no COMMAREA is passed): https://www.ibm.com/docs/en/cics-ts/6.x?topic=reference-eib-fields
* Enterprise COBOL for z/OS Language Reference (SC27-8713): group items are contiguous; COMP-3 (packed decimal) representation; INITIALIZE (alphanumeric to spaces, numeric to zero).
