# cics-crucible

An adversarial benchmark for CICS-to-Java translation. Each case is a small, original CICS
COBOL application: programs, BMS maps, CSD definitions, copybooks, and scripted terminal
scenarios. With every scenario ships a **hand-written expected event log**: what IBM CICS
Transaction Server would do, derived from IBM's documentation and cited in the case's
`NOTES.md`.

It is the oracle for [GitGalaxy](https://github.com/squid-protocol/gitgalaxy)'s
`cobol_to_java` CICS pipeline (epic
[squid-protocol/gitgalaxy#3989](https://github.com/squid-protocol/gitgalaxy/issues/3989)).
Two things run against these logs: the generated Spring Boot port, and the COBOL itself on
gitgalaxy's stub CICS runtime.

## The oracle principle

The expected logs are **not** tool output. They are not produced by the gitgalaxy stub
runtime, by a Java port, or by an emulator. Each one is reasoned line by line from the
program and the IBM CICS documentation for the commands it issues. Every non-obvious
behaviour is cited in `NOTES.md`. Where CICS behaviour is release-dependent or not pinned
down by the documentation, the case is built so that no scenario reaches it, and `NOTES.md`
says what was avoided.

A tool disagreeing with a log is a finding about the tool, not about the log. A log changes
only with a documented reason recorded in the case's `NOTES.md` (see
[AGENTS.md](AGENTS.md)).

## The five traps

| Trap | What it attacks |
|---|---|
| `condition-handling` | HANDLE CONDITION / HANDLE ABEND as GO TO (with COBOL fall-through and PERFORM-range semantics), IGNORE CONDITION, RESP overriding handlers, handler scope across LINK levels, abend-exit search, PUSH/POP HANDLE, HANDLE CONDITION ERROR, HANDLE AID (a key's label, ANYKEY, RESP, CLEAR / PA keys with no data), the conditions of terminal RECEIVE (LENGERR, EOC) |
| `hex-attributes` | raw 3270 attribute bytes in BMS symbolic maps: DFHBMSCA names vs hex literals, the bit meanings, non-graphic bytes, bit arithmetic, the bytes BMS ignores, extended colour/highlight bytes, symbolic cursor positioning, input justification |
| `commarea-mismatch` | LINK/XCTL COMMAREA lengths shorter or longer than the receiver declares, EIBCALEN, by-reference LINK storage, version upgrades by length, LENGERR and PGMIDERR |
| `ghost-tasks` | START (INTERVAL, TIME and the six-hour rule, TERMID, REQID, PROTECT) with FROM data, RETRIEVE (ENDDATA, LENGERR), one task for several terminal STARTs, CANCEL |
| `pseudo-conversational` | RETURN TRANSID COMMAREA chains across screens, EIBCALEN = 0 first entry, MAPFAIL, CLEAR, PF3, HANDLE AID, XCTL vs RETURN TRANSID, state lost by a RETURN without COMMAREA |

## Status

Format `cics-crucible/1` ([SPEC.md](SPEC.md)). 18 cases and 85 scenarios. No release tag
yet (see [RELEASING.md](RELEASING.md)).

| Trap | Case | Scenarios | What it pins down |
|---|---|---|---|
| condition-handling | [`hc-perform-range`](cases/condition-handling/hc-perform-range) | 4 | handler labels inside a PERFORM THRU range fall through and return; ERROR catch-all outside it; RESP, IGNORE, HANDLE-after-IGNORE; LENGTH in/out → LENGERR |
| condition-handling | [`hc-terminal-receive`](cases/condition-handling/hc-terminal-receive) | 7 | unformatted terminal RECEIVE: LENGTH in/out, LENGERR by RESP, by HANDLE CONDITION and by default (AEIV); MAXLENGTH NOTRUNCATE keeps the rest for the next RECEIVE; SET(ADDRESS OF); SEND CONTROL with CURSOR |
| condition-handling | [`hc-terminal-eoc`](cases/condition-handling/hc-terminal-eoc) | 3 | an LUTYPE2 terminal's RECEIVE raises EOC: by RESP, by HANDLE CONDITION, and ignored by default |
| condition-handling | [`hc-handle-aid`](cases/condition-handling/hc-handle-aid) | 9 | HANDLE AID after a terminal RECEIVE: a key's own label, ANYKEY (not ENTER), a key deactivated by a HANDLE AID without a label, RESP ignoring the AID, PUSH / POP HANDLE, CLEAR and PA1 starting a task whose first RECEIVE returns no data |
| condition-handling | [`hc-ignore-error`](cases/condition-handling/hc-ignore-error) | 9 | one LENGERR under IGNORE CONDITION, HANDLE CONDITION ERROR, a condition's own label or IGNORE before ERROR, IGNORE overriding HANDLE, PUSH HANDLE suspending IGNORE and ERROR (AEIV), POP HANDLE restoring; POP HANDLE with nothing pushed (INVREQ to ERROR) |
| condition-handling | [`hc-deedit-uctranst`](cases/condition-handling/hc-deedit-uctranst) | 3 | `EXEC CICS BIF DEEDIT` (IBM's two examples, a trailing minus, a 1-byte field, a zoned rightmost byte, LENGERR RESP 22 and its default abend AEIV); `INQUIRE` / `SET TERMINAL UCTRANST` with `DFHVALUE` CVDAs (450 / 451 / 452), INVREQ RESP2 43 for a bad CVDA, TERMIDERR RESP2 1 / 23 |
| condition-handling | [`hc-resp-options`](cases/condition-handling/hc-resp-options) | 3 | `FORMATTIME` with `RESP` / `RESP2` (INVREQ RESP2 1 for an ABSTIME below zero) after `ASKTIME NOHANDLE` with and without `ABSTIME`; `READQ TS ... LENGTH(LENGTH OF area)` (a longer item truncated with LENGERR, length 20; a fitting one whole); `RECEIVE MAP ... ASIS` keeps lower case on a `UCTRAN(YES)` terminal |
| condition-handling | [`hc-eoc-error`](cases/condition-handling/hc-eoc-error) | 2 | HANDLE CONDITION ERROR does not take EOC, whose default action is to ignore it; EOC's own label does |
| condition-handling | [`hc-abend-link`](cases/condition-handling/hc-abend-link) | 5 | handlers not inherited by a LINKed program and restored on return; the caller's abend exit catches the callee's AEYH; a callee's own exit recovering; PUSH/POP HANDLE suspends HANDLE ABEND too |
| hex-attributes | [`hx-attr-bytes`](cases/hex-attributes/hx-attr-bytes) | 4 | 3270 attribute bytes by name, literal, non-graphic X'3C', X'40'+1, X'80' input flag; null-first-byte data; MDT set by the program changes the next input; DATAONLY omissions; MAPONLY; a PA key sends no MDT fields (MAPFAIL) |
| hex-attributes | [`hx-extended-cursor`](cases/hex-attributes/hx-extended-cursor) | 3 | colour/highlight bytes vs the attribute byte (X'F1' = blink / blue / autoskip+MDT); map → field extended-attribute defaults; -1 length + CURSOR; NUM JUSTIFY=(RIGHT,ZERO) |
| commarea-mismatch | [`ca-link-lengths`](cases/commarea-mismatch/ca-link-lengths) | 4 | LINK LENGTH 100 vs a 500-byte DFHCOMMAREA; LENGTH 500 over a 100-byte item (the callee writes the caller's neighbouring storage); no COMMAREA; PGMIDERR RESP2 1 |
| commarea-mismatch | [`ca-xctl-versions`](cases/commarea-mismatch/ca-xctl-versions) | 4 | XCTL of a 10-byte V1 area to an 80-byte V2 reader that upgrades by EIBCALEN; LENGTH 80 over a 10-byte item carries the caller's neighbouring fields; LENGERR RESP2 11; the reader entered directly with EIBCALEN 0 |
| commarea-mismatch | [`ca-channel-containers`](cases/commarea-mismatch/ca-channel-containers) | 2 | A channel in place of a COMMAREA: CHAR and BIT containers, APPEND, LINK / XCTL CHANNEL and the callee's current channel, FLENGTH in / out and NODATA, CONTAINERERR / CHANNELERR / LENGERR / INVREQ by RESP and HANDLE CONDITION, AEZJ by default |
| ghost-tasks | [`gt-start-retrieve`](cases/ghost-tasks/gt-start-retrieve) | 6 | background STARTs: INTERVAL(0), no data (ENDDATA first), TIME in the past within six hours runs first, RETRIEVE LENGERR, PROTECT vs an abending starter; an unknown mode starts nothing |
| ghost-tasks | [`gt-terminal-coalesce`](cases/ghost-tasks/gt-terminal-coalesce) | 4 | three terminal STARTs → one task retrieving all three; staggered expiry → two tasks; CANCEL REQID in time (NORMAL) and too late (NOTFND) |
| ghost-tasks | [`gt-start-options`](cases/ghost-tasks/gt-start-options) | 7 | START data options RTRANSID / RTERMID / QUEUE and RETRIEVE's ENVDEFERR, RETRIEVE with no INTO, AFTER / AT and a TIME past 23 hours, INVREQ's RESP2 4 / 5 / 6, a REQID reused with FROM (IOERR); RUN TRANSID's child and TRANSIDERR |
| ghost-tasks | [`gt-assign-startcode`](cases/ghost-tasks/gt-assign-startcode) | 3 | ASSIGN STARTCODE `TD` / `SD` / `S` for terminal input, a pseudo-conversational RETURN TRANSID and STARTs with and without FROM; USERID the default user; FACILITY / SCRNHT / SCRNWD on a terminal task, INVREQ RESP2 5 without one, AEIP when unhandled |
| ghost-tasks | [`gt-send-text-terminal`](cases/ghost-tasks/gt-send-text-terminal) | 1 | SEND TEXT ... TERMINAL WAIT FREEKB ERASE: TERMINAL, the default disposition, records the same event as SEND TEXT without it; a START TERMID task sends to the terminal the START named; a task with no terminal sends nothing |
| ghost-tasks | [`gt-urimap-browse`](cases/ghost-tasks/gt-urimap-browse) | 2 | `INQUIRE URIMAP START / NEXT / END`: a browse of the four installed URIMAPs (name, PATH, TRANSACTION) counted without relying on the order, ILLOGIC RESP2 1 for a START inside a browse, END RESP2 2 past the last, one START for the definition whose name and path qualify, `WRITE OPERATOR` (a new `WRITE-OPERATOR` event); the second run shows END closed the browse |
| pseudo-conversational | [`pc-wizard`](cases/pseudo-conversational/pc-wizard) | 6 | a 3-screen wizard over PC01/PC02/PC03 with state in the COMMAREA; MAPFAIL, CLEAR on each screen, PF3 in either program, an inactive PF key, PF7 back via XCTL under the same transid, a program-written amount not retransmitted |
| pseudo-conversational | [`pc-return-immediate`](cases/pseudo-conversational/pc-return-immediate) | 4 | `RETURN TRANSID COMMAREA IMMEDIATE` attaches the next task at once, with the COMMAREA, leaving the next operator step for what it RETURNs; INVREQ RESP2 2 below the highest logical level and RESP2 1 with no terminal; `LINK ... SYNCONRETURN` is ignored on a local link |
| pseudo-conversational | [`pc-aid-menu`](cases/pseudo-conversational/pc-aid-menu) | 4 | HANDLE AID labels with fall-through, unhandled PF keys, CLEAR before RECEIVE, XCTL vs RETURN TRANSID to a detail screen, EIBCALEN = 0 after a RETURN without COMMAREA, an invalid option |

### Lower-confidence expected behaviour

Every log is cited, but these points rest on a reading of IBM's documentation that no single
sentence states outright. They are the first places to look if a real CICS region disagrees.

| Case / scenario | Point | Basis |
|---|---|---|
| ca-*, gt-* (all scenarios) | A terminal `RECEIVE INTO` in a task started by typing `TTTT x` on a **cleared** screen returns exactly `TTTT x` (transid included, no AID or cursor bytes). Later `text` steps assume the operator pressed CLEAR first (SPEC 5). | "Reading from a 3270 terminal" (the read header goes to EIBAID/EIBCPOSN) and "Unformatted mode" (an unformatted read returns the buffer from position 0) |
| hx-attr-bytes (all) | BMS writes a program attribute byte unchanged even when it is not an EBCDIC graphic (X'3C', X'41'). | "Building the output screen" takes any program value except X'00', X'80', X'02', X'82'; nothing says BMS normalises it |
| hx-attr-bytes / echo-dataonly | The 3270 honours the MDT bit of X'41' and so transmits TWIDDLE on ENTER (this is a scenario *input*). | GA23-0059: bits 0-1 of an attribute are derived from bits 2-7 and carry no meaning |
| hc-abend-link / sub-unhandled | When the level-1 exit is used for an abend at level 2, the level-2 program is discarded and level 1 resumes at its label. | "Abnormal termination recovery": upward search, first active exit gets control |
| gt-start-retrieve / protect-abend | A START without PROTECT still runs when its issuer abends afterwards. | Implied by the PROTECT description (only PROTECTed requests are cancelled by an abend before syncpoint) |
| hx-attr-bytes / pa-key-mapfail | After MAPFAIL on a PA key the INTO area is unchanged (the program's LOW-VALUES stay, so DATAONLY sends only STAT). | RECEIVE MAP: on MAPFAIL "the receiving data area contains the unmapped input data stream" and "the input map is not set to nulls"; a PA key's unmapped data has length zero |
| hc-terminal-eoc (all) | A 3270 display logical unit's (LUTYPE2) input message of a few bytes is a single-RU chain, so the RECEIVE returning it raises EOC; the reference region's 3270 logical unit raises none. | RECEIVE (LUTYPE2/LUTYPE3) lists EOC ("an RU ... received with end-of-chain-indicator set"), RECEIVE (3270 logical) does not; that an inbound 3270 message is one chain is SNA's, not a CICS sentence |
| ca-xctl-versions / long-overread | XCTL copies LENGTH bytes from the named area even when LENGTH exceeds the item. | Implied by XCTL LENGERR RESP2 28 ("LENGTH ... greater than the length of the data area ... while that data was being copied ...") |
| ca-channel-containers / round-trip | After a GET CONTAINER that raises LENGERR, FLENGTH holds the container's full length (13), as after a NORMAL GET. | GET CONTAINER (CHANNEL): "As an output field, FLENGTH returns the length of the data in the container", stated for the option, not per condition |
| gt-assign-startcode (all) | With security off and nobody signed on, ASSIGN USERID returns `CICSUSER`, DFLTUSER's default, in terminal and started tasks alike. | ASSIGN USERID: "If no user is explicitly signed on, CICS returns the default user ID"; DFLTUSER's default is CICSUSER. No sentence ties these to SEC=NO. |
| hc-deedit-uctranst / uctranst | `UCTRAN(YES)` on the terminal's TYPETERM gives `INQUIRE TERMINAL UCTRANST` the CVDA UCTRAN (450), `NO` NOUCTRAN, `TRANID` TRANIDONLY. | INQUIRE TERMINAL: the value "comes from the UCTRAN option of the associated TYPETERM definition"; the page does not tabulate YES / NO / TRANID against the three CVDAs |
| hc-deedit-uctranst / deedit | A trailing minus sign puts the negative zone X'D' in the rightmost byte of the field after its digits are right-aligned (`123-` in 4 bytes: X'F0F1F2D3'). | BIF DEEDIT: "If the field ends with a minus sign ... a negative zone (X'D') is placed in the rightmost (low-order) byte"; no example shows it |
| hc-resp-options / formattime | After a FORMATTIME that raised INVREQ the case reads neither output area, and the logged ABSTIME is a packed-decimal -1. | FORMATTIME: INVREQ RESP2 1 "The ABSTIME value is less than zero or not in packed-decimal format"; the page does not say what the output areas hold afterwards |
| hc-resp-options / asis | Without ASIS the same input would be upper-cased on this UCTRAN(YES) terminal; the case only reads the ASIS result. | RECEIVE MAP: ASIS "specifies that lowercase characters in the 3270 input data stream are not translated to uppercase"; the page does not tie the default translation to the TYPETERM's UCTRAN |
| pc-return-immediate / immediate | The task a RETURN IMMEDIATE attaches runs at the same virtual time as the task that RETURNed, on the same terminal, with `eibaid` null, ahead of everything else, and does not use up an operator step. | RETURN IMMEDIATE: "attached as the next transaction regardless of any other transactions enqueued by ATI for this terminal. The next transaction starts immediately and appears to the operator as having been started by terminal data"; the page says nothing of EIBAID or of virtual time, so SPEC 4 states both and the case reads neither |
| gt-urimap-browse (all) | The URIMAP definitions the CSD defines are the ones installed in the region, and a browse returns each of them once; the case uses no order. | "You can also browse through all the URIMAP definitions installed in the region, using the browse options (START, NEXT, and END)"; IBM states no browse order |

## Known gaps (future work)

* **Validator cross-checks not yet implemented:**
  * `color`/`hilight` with `*_from: "map"` are not checked against the DFHMDF → DFHMDI →
    DFHMSD `COLOR=`/`HILIGHT=` chain.
  * `data` with `data_from: "map"` is not checked against `INITIAL`.
  * A `{"kind": "start"}` task trigger is not checked against the START it names
    (transid/termid, `at` ≥ `expires`), including the other requests of a coalesced
    terminal start.
* **Coverage:** no case uses `FLENGTH` (the fullword LENGTH form) yet. `DATALENGTH` is
  avoided on purpose (it matters only for DPL). File control (READ against a KSDS) is in the
  format but not in a case yet.

## Layout

```
SPEC.md                    the case format (cics-crucible/1), event vocabulary, execution model
schema/                    JSON Schemas: case.schema.json, expected.schema.json
tools/validate.py          schema + cross-reference validator (stdlib only)
tools/syntax_check.py      optional GnuCOBOL syntax check (EXEC CICS stubbed out)
tools/stubs/               DFHAID / DFHBMSCA / DFHEIBLK stand-ins for the syntax check only
cases/<trap>/<case-id>/    case.json, NOTES.md, src/, copy/, bms/, csd/, expected/
```

## Running the checks

```bash
python3 tools/validate.py                     # every case; exit 1 on any problem
python3 tools/validate.py cases/ghost-tasks/gt-terminal-coalesce
python3 tools/syntax_check.py                 # needs cobc on PATH, or Docker
GNUCOBOL_IMAGE=gitgalaxy-gnucobol:3 python3 tools/syntax_check.py
```

`validate.py` checks the following ([SPEC section 8](SPEC.md#8-what-toolsvalidatepy-checks)):
* the schemas;
* that every program, transaction, mapset, map, copybook and layout resolves (source ↔ CSD
  ↔ BMS ↔ copybooks);
* the symbolic-map copybooks against their BMS source, byte for byte;
* COMMAREA fields for existence, completeness, fit and PICTURE;
* `SEND-MAP` attribute bytes against their decoded meaning and the map's ATTRB;
* that every `NOTES.md` has its sections and IBM citations.

CI (`.github/workflows/validate.yml`) runs both on every push and pull request.

## What phase 2 (the gitgalaxy runner) needs beyond today's harness

gitgalaxy's `tests/tools/equivalence_cics.py` and `tests/equivalence/cics/ggcics.c` run
**one task per scenario**. They compare SEND MAP data fields, SEND TEXT, RETURN, XCTL and
ABEND. They log READ and RECEIVE MAP but do not compare them. They record HANDLE ABEND only
as an event. Driving this crucible needs:

1. **Multi-task scenarios.** A step list per terminal, with the pending RETURN TRANSID and
   COMMAREA carried from task to task. The first-entry path has EIBCALEN = 0. CLEAR, PA and
   PF keys start the pending transaction (EIBAID set). Unformatted `text` input goes to
   terminal `RECEIVE`.
2. **A virtual clock and interval control.** START (INTERVAL, TIME with the six-hour rule,
   TERMID, REQID, PROTECT, FROM), RETRIEVE (NORMAL / LENGERR with truncation / ENDDATA),
   CANCEL, and one-task-per-terminal coalescing. Also non-terminal tasks and the dispatch
   order of SPEC section 4.
3. **LINK** with a by-reference COMMAREA and EIBCALEN = LENGTH. XCTL and RETURN COMMAREA
   copy LENGTH bytes from the named address, beyond the item if asked. Per-level handler
   tables, restored on return. PGMIDERR (RESP2 1) for undefined programs. LENGERR RESP2 11.
4. **Condition machinery.**
   * HANDLE CONDITION / IGNORE CONDITION / ERROR as a per-program table, and RESP/NOHANDLE
     per command. The transfer must be a real COBOL GO TO: the translator should emit
     `GO TO ... DEPENDING ON` as IBM's does, not `GOBACK`.
   * HANDLE ABEND LABEL with the upward exit search, deactivation on entry, and ASSIGN
     ABCODE.
   * PUSH/POP HANDLE.
   * HANDLE AID, applied after RECEIVE and suppressed by RESP.
   * Condition → AEIx/AEYx abend codes.
   * The current translator raises `Unsupported` for most of these.
5. **TS queues.** WRITEQ TS and READQ TS (ITEM, LENGTH in/out, ITEMERR, QIDERR, LENGERR),
   with per-scenario seeding and the `final` state compared.
6. **BMS fidelity.**
   * Output: per-field attribute resolution (program vs map ATTRB; X'00'/X'80'/X'02'/X'82'
     ignored), the first-byte-null data rule, DATAONLY omission, MAPONLY, extended
     attributes through the field → map → mapset chain, and symbolic cursor positioning.
     The physical-map defaults are needed at run time, so the harness must read the BMS
     source, not only the symbolic copybook.
   * Input: L/F/I per transmitted field, JUSTIFY (NUM → RIGHT,ZERO), and MAPFAIL when
     nothing is transmitted.
   * gitgalaxy's harness stand-ins (`tests/equivalence/cics/DFHBMSCA.cpy` and `DFHAID.cpy`)
     hold *characters* (`VALUE '-'`), whose ASCII bytes differ from the EBCDIC values. This
     repo's `tools/stubs/` use hex EBCDIC values. Attribute bytes must be compared as EBCDIC
     bytes (SPEC 6.3), so an ASCII runtime needs an explicit mapping.
7. **Comparison.** The comparison must be exact rather than the current trailing-blank and
   null-tolerant text comparison. The logs give text padded to known lengths and hex where
   bytes matter. The runner may report a looser view as well, but the oracle is exact.

## Licence

Apache-2.0: see [LICENSE](LICENSE) and [NOTICE](NOTICE). Every program, map, copybook and
log here is original. Nothing is copied from CardDemo, GenApp, CBSA, IBM samples or anywhere
else. The files in `tools/stubs/` are written for this repository; they are not IBM's
copybooks, only stand-ins with the documented values, used for syntax checking.

## The GitGalaxy constellation

This repo is one strand of the web of repos around
[GitGalaxy](https://github.com/squid-protocol/gitgalaxy). See gitgalaxy's `docs/ecosystem.md`
for the map. Its sibling benchmark is
[language-crucible](https://github.com/squid-protocol/language-crucible) (real hostile code
for the parser). This one is synthetic, hostile CICS semantics for the translator.
