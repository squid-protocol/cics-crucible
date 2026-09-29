# ca-link-lengths: LINK COMMAREA length vs the callee's declaration

## The trap

`CALINK` (transaction `CA01`) builds a 100-byte request header (`WS-CA100`, copybook
`CAHDR`) at the front of a 500-byte group `WS-BLOCK`. It LINKs to `CASUB`, whose
`DFHCOMMAREA` is declared as 500 bytes: the same header plus a 400-byte extension. The mode
letter typed after the transaction id picks the LINK:

| Mode | LINK | CASUB sees |
|---|---|---|
| S | `COMMAREA(WS-CA100) LENGTH(100)` | EIBCALEN 100. It checks, and leaves the extension alone. |
| L | `COMMAREA(WS-CA100) LENGTH(500)` | EIBCALEN 500. The extension is the caller's `WS-AFTER`, and the callee writes it. |
| Z | no COMMAREA | EIBCALEN 0. It writes a TS trace record and returns. |
| P | `PROGRAM('CAGONE')`, not defined | none: the LINK fails with PGMIDERR (RESP2 1), which the caller tests with RESP |

The caller reports what it sees afterwards (RC, the callee's EIBCALEN, the reply, and the
first bytes of its own WS-AFTER) with SEND TEXT.

## Why a naive translation breaks

* A port that generates a typed DTO per COMMAREA and copies it in and out has several
  failure modes:
  * It passes a 100-byte object where the callee wants 500 bytes: it pads, truncates, or
    throws.
  * With LENGTH(500) it passes only the 100 bytes named by `COMMAREA(WS-CA100)`. Real CICS
    passes the **address** of WS-CA100 with length 500. The callee therefore addresses the
    caller's next 400 bytes, and its writes (`Y`, `CALLEE-WROTE-HERE`) appear in the
    caller's WS-AFTER.
* EIBCALEN is the length the caller gave, not the size of the callee's declaration. A port
  that sets EIBCALEN to the DTO size breaks the callee's `IF EIBCALEN >= LENGTH OF
  DFHCOMMAREA` check.
* With no COMMAREA, a port must still run the callee with EIBCALEN = 0, and it must not
  invent a zero-filled area for the callee to write into.
* A LINK to an undefined program is a runtime condition (PGMIDERR), not a compile or link
  error. A port that binds program calls statically cannot express it.

## Expected behaviour

Every scenario: `CA01 x` typed on a cleared screen. EIBCALEN is 0, and `RECEIVE
INTO(WS-INPUT) LENGTH(WS-INLEN)` returns the 6 characters typed, `CA01 x`, with WS-INLEN
set to 6 [RECEIVE]. The header starts as INITIALIZE leaves it (CA-SEEN-LEN 0, the rest
blanks), then EYE `CAHD`, VERSION `1` and REQUEST `PING` are set.

* **`short-100`**: LINK LENGTH(100). "LENGTH specifies ... the length in bytes of the
  COMMAREA", and the callee "must verify that the EIBCALEN field ... matches what the program
  expects" [LINK]. CASUB sees EIBCALEN = 100, stores 100 in CA-SEEN-LEN, sets REPLY `PONG`,
  and, since 100 < 500, RC `04`. It does not touch CA-EXT. The caller's WS-AFTER is still
  `N` / `CALLER-OWNED`.
* **`long-500`**: LINK COMMAREA(WS-CA100) LENGTH(500). CICS passes the COMMAREA address and
  the length: "the address of the area is passed to the program that is receiving control",
  and the linking program can "receive results from that program" through it [COMMAREA]. The callee's 500-byte DFHCOMMAREA therefore overlays the
  caller's whole WS-BLOCK (WS-CA100 is its first 100 bytes, WS-AFTER the next 400, contiguous
  in one 01 group). CASUB sees EIBCALEN = 500, sets RC `00`, flag `Y` and data
  `CALLEE-WROTE-HERE`. The caller reports `AFTER=Y CALLEE-WROTE-HERE`.
* **`no-commarea`**: LINK without COMMAREA. EIBCALEN = 0. CASUB writes `NO COMMAREA` to TS
  queue CATRACE (item 1 [WRITEQ-TS]) and RETURNs. The caller's header is unchanged: RC
  blank, SEEN 0000.
* **`undefined-program`**: LINK PROGRAM('CAGONE'). No definition is installed and program
  autoinstall is off (SPEC section 2), so PGMIDERR with RESP2 = 1 [LINK]. Because RESP is
  specified, there is no abend (AEI0 otherwise [AEIA]). DFHRESP(PGMIDERR) = 27
  [RESP-CODES], so the report ends `RESP=27/01`.

## What a correct port must do

* Pass a local LINK COMMAREA as a **view of the caller's storage** at the named address,
  with the given length. It must not be a copy of the named item.
* Set EIBCALEN to the LENGTH passed (0 with no COMMAREA), independent of the callee's
  declaration.
* Resolve LINK targets at run time against the resource definitions and raise PGMIDERR
  (RESP2 1) for an undefined one.

## Avoided ambiguities

* **Addressing mode.** CICS makes a COMMAREA addressable by the receiver's addressing mode
  (for XCTL it creates it "in an area that conforms to the addressing mode of the receiving
  program" [COMMAREA]); an AMODE(24) receiver could get a below-the-line copy. Both programs
  here are AMODE(31), so `long-500` relies on true by-reference storage.

* **Reading beyond EIBCALEN.** IBM says the callee must check EIBCALEN. What the bytes
  beyond it hold depends on the caller's storage layout. CASUB never reads or writes past
  EIBCALEN. In `long-500`, the extra 400 bytes are well defined only because the caller
  named the first item of a contiguous 01 group. A LENGTH that runs past the end of the
  caller's 01 (into unrelated storage) is not used.
* **DATALENGTH** (a DPL optimisation) and remote (DPL) links, where the COMMAREA *is*
  copied, are not used. The whole case is local LINK.
* LINK LENGTH(0) with a COMMAREA ("unpredictable" [LINK]) is not used.
* The exact bytes RECEIVE returns for unformatted 3270 input (the transaction id and the
  typed parameter, with no AID or cursor address) are an assumption shared by several cases.
  They are listed in the README.

## Citations

* [COMMAREA] CICS TS 6.x, COMMAREA in LINK and XCTL commands (address passed, results returned through it, addressing mode): https://www.ibm.com/docs/en/cics-ts/6.x?topic=transaction-commarea-in-link-xctl-commands
* [LINK] CICS TS 6.x, EXEC CICS LINK (COMMAREA, LENGTH, EIBCALEN check, PGMIDERR RESP2 values): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-link
* [RECEIVE] CICS TS 5.5, EXEC CICS RECEIVE (z/OS Communications Server default: INTO, LENGTH, LENGERR): https://www.ibm.com/docs/en/cics-ts/5.5.0?topic=summary-receive-zos-communications-server-default
* [WRITEQ-TS] CICS TS 6.x, EXEC CICS WRITEQ TS: https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (PGMIDERR = 27): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [AEIA] CICS TS 6.x, abend codes AEIA group (PGMIDERR = AEI0): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-aeia
* Enterprise COBOL for z/OS Language Reference (SC27-8713): subordinate items of a group occupy contiguous storage in declaration order.
