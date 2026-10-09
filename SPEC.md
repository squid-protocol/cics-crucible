# cics-crucible case format — `cics-crucible/1`

This document defines, precisely, what a case in this repository is: its files, its
`case.json` (the inputs), and its `expected/*.json` event logs (the oracle). The format is
versioned: every `case.json` carries `"format": "cics-crucible/case/1"` and every expected
log `"format": "cics-crucible/expected/1"`. A change that would make an existing file mean
something different bumps the major number; additive, optional keys do not.

The machine-checkable half of this document is `schema/case.schema.json` and
`schema/expected.schema.json`; `tools/validate.py` applies both and the cross-reference
rules in section 8.

## 1. The oracle principle

The expected log of a scenario is **what IBM CICS Transaction Server would do**, derived by
hand from IBM's documentation and cited in the case's `NOTES.md`. It is not the output of any
tool: not of the gitgalaxy stub runtime (`tests/equivalence/cics/ggcics.c`), not of a
generated Java port, not of an emulator. Those are all *tested against* it.

Where CICS behaviour is release-dependent or not pinned down by the documentation, the case
is designed so that the scenario never reaches that behaviour, and `NOTES.md` says what was
avoided and why. A behaviour the author is less than fully confident about is listed in the
README's confidence table.

## 2. The reference region

Every case runs in the same notional region. Cases rely on these properties, so they are
part of the format:

| Property | Value |
|---|---|
| Release | CICS TS for z/OS 6.x semantics (nothing used here is new in 6.x) |
| Code page | EBCDIC CCSID 037 for every byte in every area. A hex value in a case (`X'C1'`, `"hex": "C1"`) is an EBCDIC byte. |
| Program autoinstall | **off**. A LINK/XCTL to a program with no CSD definition raises PGMIDERR, RESP2 = 1. |
| Terminal | one terminal, `T001`, a 24x80 3270 display that supports extended data stream, colour and extended highlighting, and accepts automatic and terminal-initiated transactions (TYPETERM `ATI(YES) TTI(YES)`; the RDO default `ATI(NO)` would silently stop every `START TERMID` task). A case CSD may define it and must then say `ATI(YES) TTI(YES)`; a case that STARTs a terminal task must define it. The screen is cleared when a scenario begins. Its session is a 3270 logical unit (TYPETERM `DEVICE(3270)`): a terminal `RECEIVE` raises no EOC (IBM, EXEC CICS RECEIVE (3270 logical), whose conditions are INVREQ, LENGERR and TERMERR). A case CSD may define it `DEVICE(LUTYPE2)` instead, a 3270 display logical unit: an input message is then one chain, and the `RECEIVE` that returns its last byte raises EOC (EXEC CICS RECEIVE (LUTYPE2/LUTYPE3): EOC "occurs when a request/response unit (RU) is received with end-of-chain-indicator set"; default action: ignore it). A case CSD may state the TYPETERM's `UCTRAN(YES|NO|TRANID)` (IBM, INQUIRE TERMINAL: the terminal's UCTRANST "comes from the UCTRAN option of the associated TYPETERM definition": UCTRAN, NOUCTRAN, TRANIDONLY); a case whose programs INQUIRE or SET a terminal's `UCTRANST` must, and then types its input in upper case, since an input translation is not modelled. A scenario starts with the terminal as its TYPETERM says. |
| Security | none (no NOTAUTH). Nobody signs on, so every task's user is the default user, `CICSUSER` (the SIT `DFLTUSER` default; ASSIGN USERID: "If no user is explicitly signed on, CICS returns the default user ID"). |
| Temporary storage | every queue named in a case is main or auxiliary TS, local, non-recoverable. |
| Files | a CSD `DEFINE FILE` plus the case's `data/` records; a file is opened on first use. |
| Language | Enterprise COBOL, translated by the CICS translator; `HANDLE CONDITION`/`HANDLE AID`/`HANDLE ABEND LABEL` transfers are `GO TO`s (the translator's `GO TO ... DEPENDING ON` after the command). |

A case may narrow these (e.g. a CSD `TYPETERM` with `EXTENDEDDS(YES)`) but never contradict
them.

## 3. Directory layout

```
cases/<trap>/<case-id>/
  case.json            the case: sources, layouts, maps, scenarios (section 5)
  NOTES.md             the trap, why a naive port breaks, the expected behaviour with IBM citations
  src/<PROGRAM>.cbl    COBOL programs, fixed format, one program per file, file stem = PROGRAM-ID
  copy/<MEMBER>.cpy    copybooks: commarea layouts and symbolic maps (file stem = COPY member)
  bms/<MAPSET>.bms     BMS map source (DFHMSD/DFHMDI/DFHMDF), file stem = mapset name
  csd/<case>.csd       DFHCSDUP input: DEFINE PROGRAM / TRANSACTION / MAPSET / FILE / ...
  data/                seed data (VSAM records, as fixed-length text lines), when a case READs a file
  expected/<scenario-id>.json   one expected log per scenario (section 6)
```

`<trap>` is one of `condition-handling`, `hex-attributes`, `commarea-mismatch`,
`ghost-tasks`, `pseudo-conversational`. `<case-id>` is lower-case kebab and unique across the
repository.

Rules for the sources:

* Programs are original, valid Enterprise COBOL with EXEC CICS, columns 1-72 (sequence area
  blank), no continuation lines inside an EXEC CICS block, no `CBL`/`PROCESS` cards.
* IBM-supplied copybooks `DFHAID` and `DFHBMSCA` may be `COPY`ed and are not shipped in the
  case (stand-ins for syntax checking only are in `tools/stubs/`). `DFHEIBLK` and
  `DFHCOMMAREA` are supplied by the translator and never `COPY`ed.
* Every BMS map field that a program references is named, and every DFHMDF gives
  `ATTRB` explicitly with a protection (`ASKIP`/`PROT`/`UNPROT`) and an intensity
  (`NORM`/`BRT`/`DRK`), so that no case depends on operand defaults. Mapsets use
  `MODE=INOUT,LANG=COBOL,STORAGE=AUTO,TIOAPFX=YES`.
* The symbolic map copybook in `copy/` is what the BMS assembly with `TYPE=DSECT` produces:
  `01 <map>I` with a 12-byte TIOA prefix FILLER, then per named field `<f>L COMP S9(4)`,
  `<f>F` with `<f>A` redefining it, one FILLER byte per extended attribute in `DSATTS`, and
  `<f>I`; and `01 <map>O REDEFINES <map>I` with FILLER X(12), per field FILLER X(3), one byte
  per extended attribute (`<f>C` colour, `<f>P` PS, `<f>H` highlight, `<f>V` validation, in that
  order) and `<f>O`. The validator checks the copybook against the BMS source.

## 4. Time, tasks and the terminal (the execution model)

A scenario is a deterministic, single-threaded replay of one terminal conversation plus any
tasks it starts.

* **Virtual clock.** The case's `clock` (local time, ISO 8601, no zone) is time 0. Steps are
  at whole seconds after it. A task takes zero time: EIBTIME/EIBDATE of a task, and ASKTIME
  inside it, are the virtual time at which it was dispatched.
* **Operator steps.** Each step is one operator action at the terminal at its `at` time:
  an attention key (`aid`) plus what the terminal transmits with it. The terminal must be
  free (no task attached) at that time.
* **Which transaction runs.** If the previous terminal task ended with `RETURN TRANSID(x)`,
  the step starts transaction `x` with the COMMAREA of that RETURN (EIBCALEN = its LENGTH),
  whatever key was pressed — CLEAR and PA keys included. A task that ended with `RETURN TRANSID(x) ... IMMEDIATE`
  (IBM, EXEC CICS RETURN: IMMEDIATE "ensures that the transaction specified in the TRANSID option is attached as the next
  transaction regardless of any other transactions enqueued by ATI for this terminal. The next transaction starts
  immediately and appears to the operator as having been started by terminal data") starts `x` at once, at the same
  virtual time, with the COMMAREA of that RETURN, ahead of every expired START request and without using an operator step:
  the terminal's next step then goes on as it would after any task. That task's `trigger` is `{"kind": "immediate",
  "task", "event"}` (the RETURN, in the task that precedes it) and its `eibaid` is null: IBM does not say which key it
  holds, so a case never makes it observable (no EIBAID test, no HANDLE AID, no terminal RECEIVE: the terminal input it
  "appears" to have is not stated either). Otherwise the step must be
  unformatted `text` whose first blank-delimited word is the transaction id, and the task
  starts with EIBCALEN = 0.
* **Started tasks.** `START` creates an interval-control request that *expires* at
  `now + INTERVAL` (or `AFTER`), or at `TIME` (or `AT`): today; if it is not later than now but is
  within the preceding six hours it expires immediately, if earlier than that tomorrow; an hours
  component greater than 23 is a time on a following day. A request with `PROTECT` does not exist until
  the issuing task ends normally (the task-end syncpoint); if that task abends it is
  discarded. An expired request is dispatched:
  * without `TERMID`: as a non-terminal task, once the issuing task has ended;
  * with `TERMID`: once that terminal is free. All requests for the same TRANSID and TERMID
    that have expired by then are satisfied by **one** task, which RETRIEVEs their data in
    expiry order.
  A request's data is its `FROM` data and its `RTRANSID` / `RTERMID` / `QUEUE` values; a request
  with none of them has none, and a task started by it gets ENDDATA on its first RETRIEVE.
* **RUN TRANSID children.** `RUN TRANSID` attaches a child task that "runs asynchronously
  with the starting task": it is dispatched like a non-terminal request that expires when the
  RUN is issued (once the issuing task has ended). A case never makes its order against the
  parent observable (no FETCH; no shared resource).
* **Dispatch order.** The scheduler never pre-empts a task. When a task ends, it dispatches,
  in order: expired START requests (earliest expiry first, ties by issue order), then the
  next operator step once its time has come. Virtual time jumps to the next expiry or step.
  After the last step it keeps dispatching until no request expires before `until`.
* **No ties by design.** Real CICS is multi-tasking; the order above is only the observable
  order because cases are written so that it cannot matter: no operator step and START
  expiry share a second, and concurrently eligible tasks never share a resource whose
  ordering is observable. A case that needs an ordering says in `NOTES.md` which IBM rule
  gives it.

## 5. `case.json`

```json
{
  "format": "cics-crucible/case/1",
  "id": "hc-perform-range",
  "trap": "condition-handling",
  "title": "HANDLE CONDITION labels inside and outside a PERFORM THRU range",
  "clock": "2026-03-02T10:00:00",
  "terminal": "T001",
  "sources": {"cobol": ["src/HCQREAD.cbl"], "bms": [], "csd": ["csd/hc-perform-range.csd"],
              "copy": [], "data": []},
  "layouts": {},
  "maps": {},
  "scenarios": [
    {"id": "three-items", "summary": "...", "path": "happy",
     "initial": {"ts_queues": {"HCQ1": ["AAA", "BBB", "CCC"]}},
     "steps": [{"at": 0, "aid": "ENTER", "text": "HC01"}],
     "until": 60}
  ]
}
```

* `layouts` name the record layouts that expected logs use to spell out COMMAREAs and other
  areas field by field: an 01-level `record` in a copybook or program `source` (COPY
  statements inside it are expanded from the case's copy directory).
* `maps` lists every BMS map a program sends or receives, with its mapset and symbolic map
  copybook.
* `undefined_programs` lists program names that a program deliberately LINKs/XCTLs to but
  that have no CSD definition (the PGMIDERR traps); everything else must resolve.
* A scenario's `path` is `happy` or `trap` (which side of the trap it drives), `initial` seeds
  temporary storage queues (`ts_queues`: queue → list of items), and `steps` are the operator
  actions:

| Step key | Meaning |
|---|---|
| `at` | seconds after `clock` |
| `aid` | `ENTER`, `CLEAR`, `PA1`-`PA3`, `PF1`-`PF24` (EIBAID gets the DFHAID value) |
| `text` | unformatted input typed on a **cleared** screen, e.g. `"CA01 S"`; what a terminal `RECEIVE` returns. An unformatted read returns the buffer from position 0, so the text is exact only on a cleared screen: at a later step the operator presses CLEAR first (with no TRANSID pending, CLEAR starts nothing and is not a step of its own) |
| `map` + `fields` | formatted input: the fields of the map on the screen that the terminal transmits (every field whose MDT is on — typed into, or sent with FSET/MDT and left alone). Value: the transmitted characters (the 3270 sends no nulls; trailing blanks are data). `""` is a field transmitted with no data — cleared with ERASE EOF, or an MDT-on field left empty — which BMS reports as length 0 with the flag byte X'80' |
| `cursor` | optional: field name where the cursor was left (EIBCPOSN) |
| `note` | optional commentary, never compared |

A step with neither `text` nor `map` (e.g. ENTER on a screen written by SEND TEXT) transmits
nothing the program reads; only its AID matters.

CLEAR and PA keys transmit no field data: such a step has neither `text` nor `fields`.
A step with `map` but empty `fields` is ENTER/PF with nothing modified (RECEIVE MAP raises
MAPFAIL).

## 6. Expected logs — `expected/<scenario-id>.json`

```json
{
  "format": "cics-crucible/expected/1",
  "case": "hc-perform-range",
  "scenario": "three-items",
  "tasks": [
    {"seq": 1, "transid": "HC01", "program": "HCQREAD", "termid": "T001",
     "at": "2026-03-02T10:00:00", "trigger": {"kind": "terminal", "step": 0},
     "eibaid": "ENTER", "eibcalen": 0, "commarea": null,
     "events": [ ... ],
     "end": "normal"}
  ],
  "final": {"ts_queues": {"GTLOG": ["..."]}}
}
```

* `tasks` are in dispatch order (section 4). `trigger` is `{"kind": "terminal", "step": i}`
  (index into `steps`) or `{"kind": "start", "task": seq, "event": j}` (the START event, index
  into that task's events; a coalesced terminal start names the first request), or
  `{"kind": "run", "task": seq, "event": j}` (a RUN TRANSID child: the RUN event), or
  `{"kind": "immediate", "task": seq, "event": j}` (the task a RETURN IMMEDIATE attached: that RETURN event).
* `eibaid` is the key name (null for a non-terminal task; a started terminal task has
  `null` too). `eibcalen` and `commarea` describe the COMMAREA the task's first program
  receives.
* `end` is `normal` (the level-1 RETURN) or `abend` (the task was terminated).
* Any object in a log may carry a `note` (task, event, SEND-MAP field): commentary for
  humans, never compared.
* `final` (optional) is the state of the named TS queues after the scenario; queues not
  named are not compared.

### 6.1 Values

A **text** value is a JSON string of EBCDIC-037-representable characters. When the area it
describes has a known length, the string is right-padded with blanks (X'40') to that length
before comparison; trailing blanks in the log are therefore optional, embedded ones are not.
A **hex** value is `{"hex": "C1C2"}`: exact EBCDIC bytes, used whenever an area contains
nulls, binary or packed data, or non-graphic bytes. A **numeric** field value (a field with a
numeric PICTURE) is a decimal string (`"-12.50"`, `"7"`), compared as a number.

An **area** (COMMAREA, TS item, START/RETRIEVE data) is
`{"length": n, "layout": "NAME", "fields": {...}}` or `{"length": n, "text": "..."}` or
`{"length": n, "hex": "..."}`. With a layout, every elementary non-FILLER field that lies
wholly inside the first `n` bytes must be listed (fields under a REDEFINES or an OCCURS are
optional); no listed field may extend past `n`. Case layouts avoid FILLER so that every byte
of an area is named.

### 6.2 Events

Only commands with an effect outside the program's own storage, or whose outcome decides the
flow, are events. `HANDLE`, `IGNORE`, `PUSH`, `POP`, `ASSIGN`, `ADDRESS`, `ASKTIME` are not
events: their effect must be made observable by what the program then does (the cases carry
a breadcrumb trail to the screen or a TS queue for this reason). A condition that transfers
to a HANDLE CONDITION label is not an event either; its command's event carries the `resp`.

Every event has `event` (its type) and `program` (the program issuing it). `resp` is the
condition name (`NORMAL`, `QIDERR`, ...) raised by the command, whether or not the program
asked for RESP; `resp2` is given only where IBM documents the value.

| `event` | Further keys | Notes |
|---|---|---|
| `SEND-MAP` | `map`, `mapset`, `options` (sorted subset of `ERASE ERASEAUP MAPONLY DATAONLY FREEKB ALARM FRSET CURSOR`), `cursor` (optional: field name, or `{"offset": n}`), `fields` | see 6.3 |
| `SEND-TEXT` | `text` (text or hex), `length`, `options` (sorted subset of `ERASE FREEKB ALARM CURSOR WAIT LAST`, as the program wrote them) | the FROM data as the program passed it, not the formatted screen. `TERMINAL` is never an option of the event: it is the default output disposition, the task's principal facility, so `SEND TEXT ... TERMINAL` and `SEND TEXT` are the same command |
| `SEND-CONTROL` | `options` (sorted subset of `ERASE ERASEAUP FREEKB ALARM FRSET CURSOR`), `cursor` (with CURSOR: `{"offset": n}`) | device controls only |
| `RECEIVE-MAP` | `map`, `mapset`, `resp` | received values are observable through what the program does next |
| `RECEIVE` | `resp`, `length` (after), `data` | terminal input, unformatted |
| `LINK` | `target`, `length` (the LENGTH given = EIBCALEN the target sees; 0 without COMMAREA), `commarea` (the `length` bytes at the named area when the command is issued, or null without COMMAREA), `resp`, `resp2` | on NORMAL the target's events follow |
| `XCTL` | `target`, `length`, `commarea` (as for LINK), `resp`, `resp2` | on NORMAL the target's events follow, same level; on failure control stays in the issuing program |
| `RETURN` | `level` (1 = to CICS), `transid` (level 1: next transid or null), `commarea` (level 1: the area passed to the next task, or null), `caller_commarea` (level > 1: the LINK COMMAREA as the linking program now sees it, or null), `immediate` (`true` only if the program gave IMMEDIATE), `resp` / `resp2` (only on a RETURN IMMEDIATE that failed) | at level 1 it ends the task, except a RETURN IMMEDIATE that failed: INVREQ RESP2 1 ("A RETURN command with the TRANSID option is issued in a program that is not associated with a terminal"), INVREQ RESP2 2 (CHANNEL, COMMAREA or IMMEDIATE "issued by a program that is not at the highest logical level") or LENGERR RESP2 11 (the COMMAREA length is less than 0 or greater than 32763) return to the program; that event has `level` (the issuing program's), `immediate`, `transid`, `resp`, `resp2` and no area. Additive (SPEC rule 5): the new keys are optional and the `immediate` trigger kind is new |
| `START` | `transid`, `termid`, `interval` (`hhmmss`) or `time` (`hhmmss`), `from` (area or null), `reqid` (only if the program named one), `rtransid` / `rtermid` / `queue` (each only if the program named it), `protect`, `resp`, `expires` (virtual time, null if not NORMAL) | `AFTER` is recorded as the `interval` and `AT` as the `time` its HOURS / MINUTES / SECONDS amount to; out of range (INVREQ) it amounts to none: null |
| `RETRIEVE` | `resp`, `length` (the LENGTH value after the command; only when the command sets it: NORMAL, LENGERR, with INTO), `data` (the bytes written into INTO, or null), `rtransid` / `rtermid` / `queue` (each only if the command named it and is NORMAL or LENGERR) | |
| `CANCEL` | `reqid`, `resp` | interval-control CANCEL |
| `RUN` | `transid`, `resp`, `resp2` (not NORMAL) | RUN TRANSID; its CHILD token is not observable. The child task's `trigger` is `{"kind": "run", "task", "event"}` |
| `READQ-TS` | `queue`, `item` (number, or `"NEXT"`), `resp`, `length` (after; only on NORMAL / LENGERR), `data` (the bytes written into INTO, or null) | |
| `WRITEQ-TS` | `queue`, `data`, `resp`, `item` (number assigned) | |
| `WRITE-OPERATOR` | `data` (the TEXT area sent to the console), `resp` | `EXEC CICS WRITE OPERATOR TEXT(area)`; a plain message only (a text that starts `DFHnnnn` / `DFHaannnn`, which IBM reformats, or is over 113 characters, which it splits into lines, is not used). Additive (SPEC rule 5): a new event type |
| `READ` | `file`, `ridfld`, `resp` | file control |
| `ABEND` | `abcode`, `cause` (`command` for EXEC CICS ABEND, `condition` for an unhandled condition), `condition` (when cause is `condition`), `outcome` (`terminated` or `exit`), `exit` (`{"program", "label"}` when outcome is `exit`) | an abend handled by a HANDLE ABEND LABEL exit continues at that label in that program; the lower levels are gone |

Abend codes for unhandled conditions are IBM's AEIx/AEYx/AEXx codes (e.g. NOTFND → AEIM,
LENGERR → AEIV, ITEMERR → AEIZ, QIDERR → AEYH, MAPFAIL → AEI9, ENDDATA → AEI2, PGMIDERR →
AEI0, INVREQ → AEIP; see the AEIA topic in IBM's abend codes). The DFHAC2206 message CICS
writes to the terminal when a task abends is not an event.

### 6.3 `SEND-MAP` fields

`fields` has one entry per **named** field of the map (unnamed literals are not listed).
Under DATAONLY, a field for which BMS sends nothing is omitted. Each entry:

| Key | Meaning |
|---|---|
| `attr` | the 3270 field attribute byte BMS writes for the field, two hex digits (EBCDIC), exactly as on the data stream; null when none is sent (DATAONLY with no program attribute) |
| `attr_from` | `program` (the `<f>A` byte was present: not X'00', X'80', X'02', X'82'), `map` (the DFHMDF ATTRB, or ASKIP,NORM when omitted), or `none` |
| `meaning` | optional, the byte decoded from its bits 2-7: `{"protected": bool, "numeric": bool, "display": "normal" or "bright" or "dark", "mdt": bool}` (protected + numeric is autoskip). Checked against `attr`. |
| `data` | the field's data as BMS sends it: text (padded to the field length) or hex. null when neither program nor map supplies data: without DATAONLY BMS then writes nulls ("field is set to nulls"), under DATAONLY it writes no data; either way the field shows nothing |
| `data_from` | `program` (first byte of `<f>O` not null), `map` (INITIAL), or `none` |
| `color`, `hilight` | extended attributes as sent (hex, e.g. `F2` red, `F1` blink); null means the hardware default, whether BMS omits the attribute or sends it as X'00' (a runner must treat both as null); only for maps with DSATTS |
| `color_from`, `hilight_from` | `program`, `map` or `none` |

Attribute byte bits (3270 Data Stream Programmer's Reference, GA23-0059, "Field attribute";
bit 0 is the high-order bit): bits 0-1 are chosen so the byte is a graphic character and carry
no meaning; bit 2 = protected (X'20'); bit 3 = numeric (X'10'); bits 4-5 = display: `00`
normal, `01` normal/pen-detectable, `10` bright, `11` nondisplay (X'0C'); bit 6 reserved;
bit 7 = MDT (X'01'). The graphic encodings: unprotected X'40' / MDT X'C1', bright X'C8'/X'C9',
dark X'4C'/X'4D'; numeric X'50'/X'D1', bright X'D8'/X'D9', dark X'5C'/X'5D'; protected
X'60'/X'61', bright X'E8'/X'E9', dark X'6C'/X'6D'; autoskip X'F0'/X'F1', bright X'F8'/X'F9',
dark X'7C'/X'7D'.

## 7. `NOTES.md`

Each case's `NOTES.md` has these sections: **The trap**, **Why a naive translation breaks**,
**Expected behaviour** (per scenario, step by step, each non-obvious step citing IBM
documentation), **What a correct port must do**, **Avoided ambiguities**, and **Citations**
(IBM documentation URLs or publication numbers and sections). An expected log is never edited
to match a tool's output unless `NOTES.md` records the documentation that shows the log was
wrong.

## 8. What `tools/validate.py` checks

1. `case.json` and every expected log against the schemas.
2. Sources: every listed file exists; each program's PROGRAM-ID equals its file stem and has
   a CSD `DEFINE PROGRAM`; each CSD `DEFINE TRANSACTION` names a program that exists; every
   literal `PROGRAM('X')` on LINK/XCTL is defined in the CSD or listed in
   `undefined_programs`; every literal `TRANSID('X')` on RETURN/START is a CSD transaction;
   every literal `MAP`/`MAPSET` exists in the BMS sources and each mapset has a CSD
   `DEFINE MAPSET`; every `COPY` resolves in the copy directories or is IBM-supplied.
3. BMS vs symbolic map copybook: same named fields, in order, with lengths and DSATTS bytes.
4. Layouts: the record exists; field sizes are computed (DISPLAY, COMP/BINARY/COMP-5, COMP-3,
   REDEFINES, fixed OCCURS) to check area fields (existence, completeness, fit, value type).
5. Expected logs: one per scenario and no strays; `case`/`scenario` match; transids,
   programs and maps exist; trigger references are in range; SEND-MAP fields are named
   fields of the map, `meaning` agrees with `attr`, and `attr` with `attr_from: map` equals
   the byte the DFHMDF ATTRB produces.
6. `NOTES.md` exists, has the section headings above, and cites at least one IBM document.
7. The reference region (section 2): every CSD `TYPETERM` has `ATI(YES) TTI(YES)`, every
   `TERMINAL` names a defined TYPETERM, and a case whose programs `START ... TERMID` defines
   `TERMINAL(<case terminal>)`.

`python3 tools/validate.py --self-test` checks the validator's own ATTRB → attribute-byte and
bit-decoding tables against SPEC 6.3.

`tools/syntax_check.py` (optional, needs `cobc` or Docker) compiles each program with the
EXEC CICS blocks replaced by `CONTINUE` and the DFH copybooks from `tools/stubs/`.
