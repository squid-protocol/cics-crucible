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
| Terminal | one terminal, `T001`, a 24x80 3270 display that supports extended data stream, colour and extended highlighting, and accepts automatic and terminal-initiated transactions (TYPETERM `ATI(YES) TTI(YES)`; the RDO default `ATI(NO)` would silently stop every `START TERMID` task). A case CSD may define it and must then say `ATI(YES) TTI(YES)`; a case that STARTs a terminal task must define it. The screen is cleared when a scenario begins. Its session is a 3270 logical unit (TYPETERM `DEVICE(3270)`): a terminal `RECEIVE` raises no EOC (IBM, EXEC CICS RECEIVE (3270 logical), whose conditions are INVREQ, LENGERR and TERMERR). A case CSD may define it `DEVICE(LUTYPE2)` instead, a 3270 display logical unit: an input message is then one chain, and the `RECEIVE` that returns its last byte raises EOC (EXEC CICS RECEIVE (LUTYPE2/LUTYPE3): EOC "occurs when a request/response unit (RU) is received with end-of-chain-indicator set"; default action: ignore it). A case CSD may state the TYPETERM's `UCTRAN(YES|NO|TRANID)` (IBM, INQUIRE TERMINAL: the terminal's UCTRANST "comes from the UCTRAN option of the associated TYPETERM definition": UCTRAN, NOUCTRAN, TRANIDONLY); a case whose programs INQUIRE or SET a terminal's `UCTRANST` must, and then types its input in upper case, since an input translation is not modelled. A case CSD may state the TYPETERM's `USERAREALEN(0-255)`, the size of each terminal's terminal control table user area (IBM: "For SNA LUs, you specify that you want a TCTUA by means of the USERAREALEN attribute on the TYPETERM resource definition"), and a case whose programs `ADDRESS TCTUA` must; a case CSD may state a transaction's `TWASIZE(0-32767)` (IBM, TRANSACTION attributes: "the size in bytes of the transaction work area to be acquired for this transaction"), and a case whose programs `ADDRESS TWA` must state it on at least one transaction. Neither area's initial content is stated: a program writes before it reads. The CWA (SIT `WRKAREA`) is not modelled. A scenario starts with the terminal as its TYPETERM says. |
| Origin data | what `INQUIRE ASSOCIATION(EIBTASKN)` returns for the task's own origin (`ODAPPLID`, `ODUSERID`, `ODFACILNAME`, `ODNETWORKID`, `ODFACILTYPE`) is a fact the case states in its optional `origin` object (`applid`, `userid`, `facilname`, `networkid`: up to 8 characters; `faciltype`: one of IBM's facility types, e.g. `TERMINAL`), for the tasks that terminal input starts (IBM: origin data is "created when a new request first arrives at a CICS region"; its pages do not say what the fields hold for a terminal task). A case whose programs `INQUIRE ASSOCIATION` must state it, and only for `EIBTASKN`, the task's own number; a task a START, a RUN TRANSID or a RETURN IMMEDIATE started has no stated origin. |
| Security | none (no NOTAUTH). Nobody signs on, so every task's user is the default user, `CICSUSER` (the SIT `DFLTUSER` default; ASSIGN USERID: "If no user is explicitly signed on, CICS returns the default user ID"). |
| Temporary storage | every queue named in a case is main or auxiliary TS, local, non-recoverable. |
| Transient data | a TD queue a case uses is an intrapartition queue the case CSD defines, `DEFINE TDQUEUE(name) TYPE(INTRA)` (IBM, TDQUEUE resources), with a destination id of 1-4 characters; it is non-recoverable and has no trigger level (`RECOVSTATUS(NO)`, no `TRIGGERLEVEL`). Extrapartition, indirect and remote queues are not modelled. A TD queue is read destructively and in order: `READQ TD` removes the item it returns, and there is no item number. Additive (SPEC rule 5). |
| Files | a CSD `DEFINE FILE` plus the case's `data/` records; a file is opened on first use. A file is a local VSAM KSDS with a fixed record length, not recoverable (no `RECOVERY`, so no syncpoint locks), enabled and read/update-able; a seed is `data/<FILE>.dat`, one record per line (printable ASCII, read as EBCDIC 037), every line the same length, in ascending key order, the key being the leading bytes the case's `RIDFLD` names; a case's programs pass `LENGTH` equal to that record length so no scenario depends on how a fixed or variable length file reads `LENGTH`. No task other than the case's own touches the file. Additive (SPEC rule 5). |
| HTTP peer | an inbound HTTP request is a fact of the scenario, like an operator step: the scenario's optional `requests` (section 5), each sent by a named **client peer** the case states in `case.json` `peers` (section 5) with the one response it expects to each of its requests. The request starts a task if exactly one installed `DEFINE URIMAP(...) USAGE(SERVER)` matches it (IBM, URIMAP resource definitions: SCHEME(HTTP); HOST equal or the single `*`; PATH equal or ending in `*` as a prefix; STATUS enabled; "if an HTTP request is matched by more than one URIMAP definition, the most specific match is taken": a case never relies on that, so no request matches two). The task runs the URIMAP's alias `TRANSACTION` (a CSD transaction naming the URIMAP's `PROGRAM`) with no terminal (`termid` and `eibaid` null) and no COMMAREA; its `trigger` is `{"kind": "http", "request": i}` (section 6). The program answers with exactly one `WEB SEND` (server): the `WEB-SEND` event is delivered to the request's peer, and the peer's stated response must equal it. Talking to a peer the script does not state (a request naming no stated peer, a response with no stated counterpart, a second response) is a **defined failure**: the case is invalid, and a runner that reaches it reports an `http-peer` failure, not a response. HTTPS, chunking, HTTP methods' effects and the client role (`WEB OPEN` / `CONVERSE`) are not modelled; headers only as stated: a peer response's optional `headers` (name to value) is what the task's NORMAL `WEB-WRITE-HTTPHEADER` events before its delivered `WEB-SEND` must equal. Additive (SPEC rule 5). |
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
  "appears" to have is not stated either). A `RETURN TRANSID(x) CHANNEL(c)` (a level-1 RETURN with `channel`) starts `x` on the next step like any
  RETURN TRANSID, with EIBCALEN 0 and `c` as the current channel of its first program. Otherwise the step must be
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
  next operator step or inbound HTTP request (section 5, `requests`) once its time has come. Virtual time jumps to the next expiry or step.
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
* `unheld_maps` (optional, additive) lists map names that a program deliberately names in SEND MAP /
  RECEIVE MAP although no BMS source holds a map of that name (the ABM0 trap: the map is not in
  its mapset); the mapset named (or, with MAPSET omitted, the map name) must still be a mapset.
* `peers` (optional, additive) states the client peers of a case's HTTP scenarios (section 2, HTTP peer):
  `{"<peer id>": {"responses": [{"status", "mediatype"?, "body"?}, ...]}}`. A peer's script is replayed in every scenario: the
  nth request that peer sends in a scenario (in order of `at`) is answered by `responses[n]`, and the script is as long as the
  most requests the peer sends in one scenario. `body` is text (the characters, after any code-page conversion; trailing
  blanks are not compared); a response with no `body` has none, and a `WEB SEND` that sends one fails the case.
* A scenario's `path` is `happy` or `trap` (which side of the trap it drives), `initial` seeds
  temporary storage queues (`ts_queues`: queue → list of items) and, optionally and additively, intrapartition
  transient data queues (`td_queues`: queue → items, oldest first; each queue must be a CSD `TDQUEUE`), and `steps` are the operator
  actions (with `requests`, below, `steps` may be empty; a scenario has at least one of them):

| Step key | Meaning |
|---|---|
| `at` | seconds after `clock` |
| `aid` | `ENTER`, `CLEAR`, `PA1`-`PA3`, `PF1`-`PF24` (EIBAID gets the DFHAID value) |
| `text` | unformatted input typed on a **cleared** screen, e.g. `"CA01 S"`; what a terminal `RECEIVE` returns. An unformatted read returns the buffer from position 0, so the text is exact only on a cleared screen: at a later step the operator presses CLEAR first (with no TRANSID pending, CLEAR starts nothing and is not a step of its own) |
| `map` + `fields` | formatted input: the fields of the map on the screen that the terminal transmits (every field whose MDT is on — typed into, or sent with FSET/MDT and left alone). Value: the transmitted characters (the 3270 sends no nulls; trailing blanks are data). `""` is a field transmitted with no data — cleared with ERASE EOF, or an MDT-on field left empty — which BMS reports as length 0 with the flag byte X'80' |
| `cursor` | optional: field name where the cursor was left (EIBCPOSN) |
| `note` | optional commentary, never compared |

A scenario's optional `requests` (additive) are the inbound HTTP requests, each
`{"at", "peer", "method", "scheme": "HTTP", "host", "path", "query"?, "headers"?, "mediatype"?, "body"?}`: `at` is whole seconds after `clock`, in order,
and never equal to a step's `at` or another request's (section 4: no ties); `peer` names an entry of `peers`; `body` and
`mediatype` go together and only a `POST` or `PUT` has a body. `query` (additive) is the request line's query string without the `?`
(what `WEB EXTRACT QUERYSTRING` reads; `path` never holds a `?`); `headers` (additive) maps header names to values (what
`WEB READ HTTPHEADER` reads; IBM raises INVREQ RESP2 43 when a request has none, so a case reads headers only on a request that
states at least one). Neither takes part in URIMAP matching. A request is not an event: the task it starts is.

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
* `final` (optional) is the state of the named TS queues (`ts_queues`) and, additively, TD queues
  (`td_queues`: remaining items, oldest first) and files (`files`: file name -> every record in key order, as text; each the seed's length) after the scenario; queues not named are not compared.

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
| `RETURN` | `level` (1 = to CICS), `transid` (level 1: next transid or null), `commarea` (level 1: the area passed to the next task, or null), `caller_commarea` (level > 1: the LINK COMMAREA as the linking program now sees it, or null), `immediate` (`true` only if the program gave IMMEDIATE), `channel` (the channel name the program gave on CHANNEL: 1-16 characters of `A-Z0-9`; level 1 with a `transid`, and then no `commarea`), `resp` / `resp2` (only on a RETURN IMMEDIATE or CHANNEL that failed) | at level 1 it ends the task, except a RETURN IMMEDIATE or CHANNEL that failed: INVREQ RESP2 1 ("A RETURN command with the TRANSID option is issued in a program that is not associated with a terminal"), INVREQ RESP2 2 (CHANNEL, COMMAREA or IMMEDIATE "issued by a program that is not at the highest logical level") or LENGERR RESP2 11 (the COMMAREA length is less than 0 or greater than 32763) return to the program; that event has `level` (the issuing program's), `immediate` and / or `channel`, `transid`, `resp`, `resp2` and no area. A level-1 RETURN with `channel` makes that channel, with the containers it holds, the current channel of the next task's first program (EIBCALEN 0: the task started by it, on the terminal's next step, is an ordinary terminal task). Containers are not events (none is an event, 6.2): the programs log what they read. Additive (SPEC rule 5): the new keys are optional and the `immediate` trigger kind is new |
| `START` | `transid`, `termid`, `interval` (`hhmmss`) or `time` (`hhmmss`), `from` (area or null), `reqid` (only if the program named one), `rtransid` / `rtermid` / `queue` (each only if the program named it), `protect`, `resp`, `expires` (virtual time, null if not NORMAL) | `AFTER` is recorded as the `interval` and `AT` as the `time` its HOURS / MINUTES / SECONDS amount to; out of range (INVREQ) it amounts to none: null |
| `RETRIEVE` | `resp`, `length` (the LENGTH value after the command; only when the command sets it: NORMAL, LENGERR, with INTO), `data` (the bytes written into INTO, or null), `rtransid` / `rtermid` / `queue` (each only if the command named it and is NORMAL or LENGERR) | |
| `CANCEL` | `reqid`, `resp` | interval-control CANCEL |
| `RUN` | `transid`, `resp`, `resp2` (not NORMAL) | RUN TRANSID; its CHILD token is not observable. The child task's `trigger` is `{"kind": "run", "task", "event"}` |
| `READQ-TS` | `queue`, `item` (number, or `"NEXT"`), `resp`, `length` (after; only on NORMAL / LENGERR), `data` (the bytes written into INTO, or null) | |
| `WRITEQ-TS` | `queue`, `data`, `resp`, `item` (number assigned) | |
| `WEB-RECEIVE` | `resp`, `resp2` (only where IBM documents it), `length` (the LENGTH value after the command), `data` (the bytes written into INTO, or null) | `EXEC CICS WEB RECEIVE` (server, buffer form) in an `http` task: the request body (IBM, WEB RECEIVE (server)). LENGERR RESP2 36 / 57 when the body exceeds MAXLENGTH. Additive: new event type, only in an `http` task |
| `WEB-SEND` | `status` (STATUSCODE), `statustext` (optional), `mediatype` (optional), `from` (the bytes of FROM, FROMLENGTH of them, or null), `resp`, `resp2` (only where IBM documents it) | `EXEC CICS WEB SEND` (server) in an `http` task: the response, delivered to the request's client peer and compared with its stated response (section 2, HTTP peer; IBM, WEB SEND (server)). An `http` task has exactly one. Additive: new event type, only in an `http` task |
| `WEB-WRITE-HTTPHEADER` | `name`, `value`, `resp`, `resp2` (only where IBM documents it) | `EXEC CICS WEB WRITE HTTPHEADER` (server) in an `http` task: a header of the response (IBM, WEB WRITE HTTPHEADER). Compared with the peer response's `headers` (section 2). Additive: new event type, only in an `http` task |
| `WRITE-OPERATOR` | `data` (the TEXT area sent to the console), `resp` | `EXEC CICS WRITE OPERATOR TEXT(area)`; a plain message only (a text that starts `DFHnnnn` / `DFHaannnn`, which IBM reformats, or is over 113 characters, which it splits into lines, is not used). Additive (SPEC rule 5): a new event type |
| `READQ-TD` | `queue`, `resp`, `resp2` (only where IBM documents it), `length` (after; only on NORMAL / LENGERR), `data` (the bytes written into INTO, or null) | `EXEC CICS READQ TD`: destructive ("after which the record is no longer available"), oldest item first (a reading of "sequential, governed by read and write pointers": README lower-confidence table), no item number (IBM, READQ TD). An empty or drained queue is QZERO; a queue the CSD does not define is QIDERR (the event then names an undefined queue); a short INTO area is LENGERR (leading bytes moved, `length` the record's length). The IBM pages give no RESP2 for these. Additive (SPEC rule 5): new event type |
| `WRITEQ-TD` | `queue`, `data`, `resp`, `resp2` (only where IBM documents it) | `EXEC CICS WRITEQ TD`: appends one item (IBM, WRITEQ TD). QIDERR for a queue the CSD does not define. Additive: new event type |
| `DELETEQ-TD` | `queue`, `resp`, `resp2` (only where IBM documents it) | `EXEC CICS DELETEQ TD`: deletes the queue's items (IBM, DELETEQ TD). QIDERR for a queue the CSD does not define. The queue's definition is not removed (a reading, README lower-confidence table), so a READQ TD after it is QZERO; whether a WRITEQ TD after it works is not stated by IBM and no case relies on it. Additive: new event type |
| `READ` | `file`, `ridfld`, `update` (true when the command has `UPDATE`; omitted otherwise), `resp`, `resp2` (only where IBM documents it), `set` (true for the `SET` form; omitted otherwise), `length` (after; only on NORMAL), `data` (the bytes written into INTO, or, with `set`, the bytes the returned pointer addresses; null when not NORMAL) | `EXEC CICS READ FILE ... INTO|SET ... RIDFLD`; `ridfld` is the key on entry; NOTFND is RESP2 80; a READ with UPDATE holds the record's exclusive control until REWRITE, UNLOCK, DELETE, syncpoint or task end (IBM, READ). Optional keys added (SPEC rule 5) |
| `REWRITE` | `file`, `data` (the record written from FROM), `resp`, `resp2` (only where IBM documents it) | `EXEC CICS REWRITE FILE FROM`; it must follow a READ UPDATE (IBM, REWRITE). Additive: new event type |
| `UNLOCK` | `file`, `resp`, `resp2` (only where IBM documents it) | `EXEC CICS UNLOCK FILE`, no `TOKEN`: releases the exclusive control a READ UPDATE took (IBM, UNLOCK). Additive: new event type |
| `STARTBR` | `file`, `ridfld` (the key on entry), `mode` (`GTEQ` or `EQUAL`), `resp`, `resp2` (only where IBM documents it) | `EXEC CICS STARTBR FILE RIDFLD`: positions a browse (IBM, STARTBR); `GTEQ` positions on the first record at or above the key, `EQUAL` only on a match; NOTFND RESP2 80 when neither. Additive: new event type |
| `READNEXT` / `READPREV` | `file`, `ridfld` (the key on entry; CICS then puts the key of the record returned into it), `set` (true for the `SET` form), `resp`, `resp2` (only where IBM documents it), `length` (only with INTO, when NORMAL), `data` (the record, or null when not NORMAL) | `EXEC CICS READNEXT` / `READPREV` in a browse: next / previous record in key order; ENDFILE (RESP 20) RESP2 90 when there is none (IBM, READNEXT, READPREV). The first read after a STARTBR returns the record the STARTBR positioned on (a reading, README lower-confidence table). Additive: new event types |
| `ENDBR` | `file`, `resp`, `resp2` (only where IBM documents it) | `EXEC CICS ENDBR FILE`: ends the browse (IBM, ENDBR). Additive: new event type |
| `ABEND` | `abcode`, `cause` (`command` for EXEC CICS ABEND, `condition` for an unhandled condition, `system` for an abend CICS itself raises for a command that raises no condition -- BMS's ABM0 for a map the mapset does not hold; additive, SPEC rule 5), `condition` (when cause is `condition`), `outcome` (`terminated` or `exit`), `exit` (`{"program", "label"}` when outcome is `exit`) | an abend handled by a HANDLE ABEND LABEL exit continues at that label in that program; the lower levels are gone |

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
   literal `PROGRAM('X')` on LINK/XCTL/LOAD/RELEASE is defined in the CSD or listed in
   `undefined_programs`; every literal `TRANSID('X')` on RETURN/START is a CSD transaction;
   every literal `MAP`/`MAPSET` exists in the BMS sources (a map in `unheld_maps` must not) and each mapset has a CSD
   `DEFINE MAPSET`; every `COPY` resolves in the copy directories or is IBM-supplied.
3. BMS vs symbolic map copybook: same named fields, in order, with lengths and DSATTS bytes.
4. Layouts: the record exists; field sizes are computed (DISPLAY, COMP/BINARY/COMP-5, COMP-3,
   REDEFINES, fixed OCCURS) to check area fields (existence, completeness, fit, value type).
5. Expected logs: one per scenario and no strays; `case`/`scenario` match; transids,
   programs and maps exist; trigger references are in range; SEND-MAP fields are named
   fields of the map, `meaning` agrees with `attr`, and `attr` with `attr_from: map` equals
   the byte the DFHMDF ATTRB produces.
6. `NOTES.md` exists, has the section headings above, and cites at least one IBM document.
7a. Files (section 2): a `data/` seed is `<FILE>.dat` for a CSD `FILE`, with equal-length, unique, printable lines; every `FILE` of a `READ` / `WRITE` / `REWRITE` / `DELETE` / `UNLOCK` / `STARTBR` / `READNEXT` / `READPREV` / `ENDBR` command and every `READ` / `REWRITE` / `UNLOCK` / `STARTBR` / `READNEXT` / `READPREV` / `ENDBR` event file is a CSD `FILE`, and a browse event's file says `BROWSE(YES)`; `final.files` names CSD files and records of the seed's length; a NORMAL `READ` / `REWRITE` / `READNEXT` / `READPREV` data length is the seed's, and an ENDFILE read returns no data.
7. TD queues (section 2): every CSD `TDQUEUE` is `TYPE(INTRA)` with a 1-4 character id; every literal
   `QUEUE` of a `READQ` / `WRITEQ` / `DELETEQ` `TD` command, every `td_queues` name (initial and final) and
   every `READQ-TD` / `WRITEQ-TD` / `DELETEQ-TD` event queue is a CSD `TDQUEUE`, except that an event with `resp` QIDERR names a queue the CSD does not define (and must not name one it defines). A command whose `QUEUE` is a data name, not a literal, can name an undefined queue.
8. The reference region (section 2): every CSD `TYPETERM` has `ATI(YES) TTI(YES)`, every
   `TERMINAL` names a defined TYPETERM, and a case whose programs `START ... TERMID` defines
   `TERMINAL(<case terminal>)`.
9. HTTP peer (sections 2, 5, 6): every request names a stated peer, matches exactly one `USAGE(SERVER)` URIMAP and shares no
   second with a step or another request; each peer's script is as long as its most requests in a scenario; every SERVER URIMAP
   states `TRANSACTION`, `PROGRAM`, `HOST`, `PATH`, `SCHEME(HTTP)`, with an alias CSD transaction that runs `PROGRAM`; a program
   issuing a server `WEB RECEIVE` / `WEB SEND` / `WEB EXTRACT` / `WEB READ HTTPHEADER` needs a scenario with requests; every request starts exactly one task, whose
   `at`, transid and program are the request's and the URIMAP's, with null `termid` / `eibaid`, and which sends one `WEB-SEND`
   equal to its peer's response, with the headers it wrote (`WEB-RECEIVE` / `WEB-SEND` / `WEB-WRITE-HTTPHEADER` appear in no other task).

`python3 tools/validate.py --self-test` checks the validator's own ATTRB → attribute-byte and
bit-decoding tables against SPEC 6.3.

`tools/syntax_check.py` (optional, needs `cobc` or Docker) compiles each program with the
EXEC CICS blocks replaced by `CONTINUE` and the DFH copybooks from `tools/stubs/`.
