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
| `condition-handling` | HANDLE CONDITION / HANDLE ABEND as GO TO (with COBOL fall-through and PERFORM-range semantics), IGNORE CONDITION, RESP overriding handlers, handler scope across LINK levels, abend-exit search, PUSH/POP HANDLE |
| `hex-attributes` | raw 3270 attribute bytes in BMS symbolic maps: DFHBMSCA names vs hex literals, the bit meanings, non-graphic bytes, bit arithmetic, the bytes BMS ignores, extended colour/highlight bytes, symbolic cursor positioning, input justification |
| `commarea-mismatch` | LINK/XCTL COMMAREA lengths shorter or longer than the receiver declares, EIBCALEN, by-reference LINK storage, version upgrades by length, LENGERR and PGMIDERR |
| `ghost-tasks` | START (INTERVAL, TIME and the six-hour rule, TERMID, REQID, PROTECT) with FROM data, RETRIEVE (ENDDATA, LENGERR), one task for several terminal STARTs, CANCEL |
| `pseudo-conversational` | RETURN TRANSID COMMAREA chains across screens, EIBCALEN = 0 first entry, MAPFAIL, CLEAR, PF3, HANDLE AID, XCTL vs RETURN TRANSID, state lost by a RETURN without COMMAREA |

## Status

Format `cics-crucible/1` ([SPEC.md](SPEC.md)). 10 cases and 37 scenarios. No release tag
yet (see [RELEASING.md](RELEASING.md)).

| Trap | Case | Scenarios | What it pins down |
|---|---|---|---|
| condition-handling | [`hc-perform-range`](cases/condition-handling/hc-perform-range) | 4 | handler labels inside a PERFORM THRU range fall through and return; ERROR catch-all outside it; RESP, IGNORE, HANDLE-after-IGNORE; LENGTH in/out → LENGERR |
| condition-handling | [`hc-abend-link`](cases/condition-handling/hc-abend-link) | 5 | handlers not inherited by a LINKed program and restored on return; the caller's abend exit catches the callee's AEYH; a callee's own exit recovering; PUSH/POP HANDLE suspends HANDLE ABEND too |
| hex-attributes | [`hx-attr-bytes`](cases/hex-attributes/hx-attr-bytes) | 3 | 3270 attribute bytes by name, literal, non-graphic X'3C', X'40'+1, X'80' input flag; null-first-byte data; MDT set by the program changes the next input; DATAONLY omissions; MAPONLY |
| hex-attributes | [`hx-extended-cursor`](cases/hex-attributes/hx-extended-cursor) | 3 | colour/highlight bytes vs the attribute byte (X'F1' = blink / blue / autoskip+MDT); map → field extended-attribute defaults; -1 length + CURSOR; NUM JUSTIFY=(RIGHT,ZERO) |
| commarea-mismatch | [`ca-link-lengths`](cases/commarea-mismatch/ca-link-lengths) | 4 | LINK LENGTH 100 vs a 500-byte DFHCOMMAREA; LENGTH 500 over a 100-byte item (the callee writes the caller's neighbouring storage); no COMMAREA; PGMIDERR RESP2 1 |
| commarea-mismatch | [`ca-xctl-versions`](cases/commarea-mismatch/ca-xctl-versions) | 3 | XCTL of a 10-byte V1 area to an 80-byte V2 reader that upgrades by EIBCALEN; LENGTH 80 over a 10-byte item carries the caller's neighbouring fields; LENGERR RESP2 11 |
| ghost-tasks | [`gt-start-retrieve`](cases/ghost-tasks/gt-start-retrieve) | 5 | background STARTs: INTERVAL(0), no data (ENDDATA first), TIME in the past within six hours runs first, RETRIEVE LENGERR, PROTECT vs an abending starter |
| ghost-tasks | [`gt-terminal-coalesce`](cases/ghost-tasks/gt-terminal-coalesce) | 4 | three terminal STARTs → one task retrieving all three; staggered expiry → two tasks; CANCEL REQID in time (NORMAL) and too late (NOTFND) |
| pseudo-conversational | [`pc-wizard`](cases/pseudo-conversational/pc-wizard) | 3 | a 3-screen wizard over PC01/PC02/PC03 with state in the COMMAREA; MAPFAIL, CLEAR, PF3 in the other program, PF7 back via XCTL under the same transid |
| pseudo-conversational | [`pc-aid-menu`](cases/pseudo-conversational/pc-aid-menu) | 3 | HANDLE AID labels with fall-through, unhandled PF keys, CLEAR before RECEIVE, XCTL vs RETURN TRANSID to a detail screen, EIBCALEN = 0 after a RETURN without COMMAREA |

### Lower-confidence expected behaviour

Every log is cited, but these points rest on a reading of IBM's documentation that no single
sentence states outright. They are the first places to look if a real CICS region disagrees.

| Case / scenario | Point | Basis |
|---|---|---|
| ca-*, gt-* (all scenarios) | A terminal `RECEIVE INTO` in a task started by typing `TTTT x` on a cleared screen returns exactly `TTTT x` (transid included, no AID or cursor bytes). | Standard CICS behaviour for unformatted input; the RECEIVE reference describes LENGTH/LENGERR but not the content |
| hx-attr-bytes (all) | BMS writes a program attribute byte unchanged even when it is not an EBCDIC graphic (X'3C', X'41'). | "Building the output screen" takes any program value except X'00', X'80', X'02', X'82'; nothing says BMS normalises it |
| hx-attr-bytes / echo-dataonly | The 3270 honours the MDT bit of X'41' and so transmits TWIDDLE on ENTER (this is a scenario *input*). | GA23-0059: bits 0-1 of an attribute are derived from bits 2-7 and carry no meaning |
| hc-abend-link / sub-own-exit | RETURN from a LINKed program's HANDLE ABEND LABEL exit ends that program normally, and the linker resumes after the LINK. | "Abnormal termination recovery": the exit determines subsequent processing; RETURN is the documented way to end a program level |
| hc-abend-link / sub-unhandled | When the level-1 exit is used for an abend at level 2, the level-2 program is discarded and level 1 resumes at its label. | "Abnormal termination recovery": upward search, first active exit gets control |
| gt-start-retrieve / protect-abend | A START without PROTECT still runs when its issuer abends afterwards. | Implied by the PROTECT description (only PROTECTed requests are cancelled by an abend before syncpoint) |
| ca-xctl-versions / long-overread | XCTL copies LENGTH bytes from the named area even when LENGTH exceeds the item. | Implied by XCTL LENGERR RESP2 28 ("LENGTH ... greater than the length of the data area ... while that data was being copied ...") |

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
   * The stub `DFHBMSCA`/`DFHAID` hold *characters* whose ASCII bytes differ from the
     EBCDIC values. Attribute bytes must be compared as EBCDIC bytes (SPEC 6.3), so an ASCII
     runtime needs an explicit mapping.
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
