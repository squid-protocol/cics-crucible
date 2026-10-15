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

Format `cics-crucible/1` ([SPEC.md](SPEC.md)). 41 cases and 152 scenarios. No release tag
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
| condition-handling | [`hc-inquire-deleteq`](cases/condition-handling/hc-inquire-deleteq) | 3 | `INQUIRE ASSOCIATION(EIBTASKN)` origin data (`ODAPPLID`, `ODUSERID`, `ODFACILNAME`, `ODNETWORKID`, `ODFACILTYPE` as the CVDA 213); `DELETEQ TS` (the queue and its `NEXT` position gone, QIDERR for a missing queue, INVREQ for a name of binary zeros, a queue written anew starts at item 1); `RECEIVE MAP ... TERMINAL ASIS` |
| condition-handling | [`hc-named-counters`](cases/condition-handling/hc-named-counters) | 2 | named counters: `GET` / `DELETE` / `QUERY COUNTER` of a counter that is not there is INVREQ RESP2 201 (IBM lists no NOTFND), `DEFINE COUNTER` with and without `VALUE` (initial zero), a duplicate DEFINE (INVREQ 202), the same name in another pool, `QUERY` leaves the value, names outside IBM's character rules (INVREQ 404 counter, 403 pool) |
| condition-handling | [`hc-dcounters`](cases/condition-handling/hc-dcounters) | 2 | doubleword named counters: `DEFINE` / `GET` / `QUERY` / `DELETE DCOUNTER` with an 8-byte unsigned `VALUE` logged as hex, GET returns the value before the increment, `QUERY` does not advance, values past 2**31 and 2**32 kept exactly (incl. a doubleword `INCREMENT`), a deleted counter is INVREQ RESP2 201 |
| condition-handling | [`hc-counter-increment-wrap`](cases/condition-handling/hc-counter-increment-wrap) | 3 | named-counter limits: `GET DCOUNTER` with `INCREMENT`, `GET ... WRAP` at the default maximum (X'FF' x 8) rewinds to the minimum, a `GET` without `WRAP` at the limit is SUPPRESSED (RESP 72) RESP2 101 and leaves the counter unchanged |
| condition-handling | [`hc-readq-td`](cases/condition-handling/hc-readq-td) | 6 | intrapartition TD queues: `WRITEQ TD` then `READQ TD` in FIFO order with the read destroying the record, QZERO on an empty or drained queue, QIDERR on an undefined queue (READQ / WRITEQ / DELETEQ), `DELETEQ TD` then `READQ TD`, LENGERR on a short INTO area; no trigger levels or ATI |
| condition-handling | [`hc-file-unlock`](cases/condition-handling/hc-file-unlock) | 3 | file control on a KSDS: `READ UPDATE` + `REWRITE`, `UNLOCK` then `REWRITE` is INVREQ RESP2 30 (record unchanged), `UNLOCK` with nothing held is NORMAL, `REWRITE` with no READ UPDATE is INVREQ RESP2 30 |
| condition-handling | [`hc-file-read-set`](cases/condition-handling/hc-file-read-set) | 4 | file control `SET` reads on a KSDS: `READ SET` (NOTFND RESP2 80 for an absent key), `STARTBR GTEQ` / `EQUAL`, `READNEXT SET` and `READPREV SET` in key order with `RIDFLD` updated, ENDFILE RESP2 90 at either end, `STARTBR` NOTFND past the last key, `ENDBR` |
| condition-handling | [`hc-eoc-error`](cases/condition-handling/hc-eoc-error) | 2 | HANDLE CONDITION ERROR does not take EOC, whose default action is to ignore it; EOC's own label does |
| condition-handling | [`hc-abend-link`](cases/condition-handling/hc-abend-link) | 5 | handlers not inherited by a LINKed program and restored on return; the caller's abend exit catches the callee's AEYH; a callee's own exit recovering; PUSH/POP HANDLE suspends HANDLE ABEND too |
| hex-attributes | [`hx-attr-bytes`](cases/hex-attributes/hx-attr-bytes) | 4 | 3270 attribute bytes by name, literal, non-graphic X'3C', X'40'+1, X'80' input flag; null-first-byte data; MDT set by the program changes the next input; DATAONLY omissions; MAPONLY; a PA key sends no MDT fields (MAPFAIL) |
| hex-attributes | [`hx-extended-cursor`](cases/hex-attributes/hx-extended-cursor) | 3 | colour/highlight bytes vs the attribute byte (X'F1' = blink / blue / autoskip+MDT); map → field extended-attribute defaults; -1 length + CURSOR; NUM JUSTIFY=(RIGHT,ZERO) |
| commarea-mismatch | [`ca-link-lengths`](cases/commarea-mismatch/ca-link-lengths) | 4 | LINK LENGTH 100 vs a 500-byte DFHCOMMAREA; LENGTH 500 over a 100-byte item (the callee writes the caller's neighbouring storage); no COMMAREA; PGMIDERR RESP2 1 |
| commarea-mismatch | [`ca-address-commarea`](cases/commarea-mismatch/ca-address-commarea) | 3 | `ADDRESS COMMAREA` + `SET ADDRESS OF`: the callee's pointer is the caller's storage; no COMMAREA gives the null value X'FF000000' (EIBCALEN 0); `ADDRESS EIB` view equals DFHEIBLK |
| commarea-mismatch | [`ca-address-twa-tctua`](cases/commarea-mismatch/ca-address-twa-tctua) | 3 | `ADDRESS TWA` / `ADDRESS TCTUA`: a TWASIZE(32) TWA shared by a task's programs, TWASIZE(0) gives X'FF000000', a TYPETERM USERAREALEN TCTUA carried across two tasks (CWA not modelled) |
| commarea-mismatch | [`ca-xctl-versions`](cases/commarea-mismatch/ca-xctl-versions) | 4 | XCTL of a 10-byte V1 area to an 80-byte V2 reader that upgrades by EIBCALEN; LENGTH 80 over a 10-byte item carries the caller's neighbouring fields; LENGERR RESP2 11; the reader entered directly with EIBCALEN 0 |
| commarea-mismatch | [`ca-channel-containers`](cases/commarea-mismatch/ca-channel-containers) | 2 | A channel in place of a COMMAREA: CHAR and BIT containers, APPEND, LINK / XCTL CHANNEL and the callee's current channel, FLENGTH in / out and NODATA, CONTAINERERR / CHANNELERR / LENGERR / INVREQ by RESP and HANDLE CONDITION, AEZJ by default |
| commarea-mismatch | [`ca-container-ccsid`](cases/commarea-mismatch/ca-container-ccsid) | 2 | Container character conversion: FROMCCSID / INTOCCSID (037 and 1208, default the region's), DATATYPE(CHAR), CCSIDERR RESP2 3 for INTOCCSID on a BIT container, INVREQ RESP2 2 / 34 |
| commarea-mismatch | [`ca-container-byteoffset`](cases/commarea-mismatch/ca-container-byteoffset) | 2 | GET CONTAINER BYTEOFFSET: reads from offset 0, the middle, the last byte, FLENGTH above what is left, a negative offset, after a PUT PREPEND; LENGERR RESP2 12 for an offset at or past the end |
| commarea-mismatch | [`ca-getmain-pointer`](cases/commarea-mismatch/ca-getmain-pointer) | 2 | GETMAIN SET(ptr) FLENGTH INITIMG, SET ADDRESS OF, pointer arithmetic through a binary REDEFINES, ADDRESS OF a subordinate item, FREEMAIN; FLENGTH 0 / -1 and LENGTH 0 give LENGERR RESP2 1 and a zero pointer |
| commarea-mismatch | [`ca-receive-retrieve-set`](cases/commarea-mismatch/ca-receive-retrieve-set) | 3 | RECEIVE SET(ptr) and RETRIEVE SET(ptr) LENGTH into a POINTER variable: LENGTH is output only and bounds the SET ADDRESS OF view; a short terminal input, LENGTH equal to the START FROM length, ENDDATA |
| commarea-mismatch | [`ca-get-container-set`](cases/commarea-mismatch/ca-get-container-set) | 2 | GET CONTAINER SET(ptr) FLENGTH: FLENGTH is output only, the SET ADDRESS OF view covers the container data, a repeated GET SET and one after a replacing PUT; CONTAINERERR RESP2 10 and CHANNELERR RESP2 2 |
| ghost-tasks | [`gt-start-retrieve`](cases/ghost-tasks/gt-start-retrieve) | 6 | background STARTs: INTERVAL(0), no data (ENDDATA first), TIME in the past within six hours runs first, RETRIEVE LENGERR, PROTECT vs an abending starter; an unknown mode starts nothing |
| ghost-tasks | [`gt-terminal-coalesce`](cases/ghost-tasks/gt-terminal-coalesce) | 4 | three terminal STARTs → one task retrieving all three; staggered expiry → two tasks; CANCEL REQID in time (NORMAL) and too late (NOTFND) |
| ghost-tasks | [`gt-start-options`](cases/ghost-tasks/gt-start-options) | 7 | START data options RTRANSID / RTERMID / QUEUE and RETRIEVE's ENVDEFERR, RETRIEVE with no INTO, AFTER / AT and a TIME past 23 hours, INVREQ's RESP2 4 / 5 / 6, a REQID reused with FROM (IOERR); RUN TRANSID's child and TRANSIDERR |
| ghost-tasks | [`gt-assign-startcode`](cases/ghost-tasks/gt-assign-startcode) | 3 | ASSIGN STARTCODE `TD` / `SD` / `S` for terminal input, a pseudo-conversational RETURN TRANSID and STARTs with and without FROM; USERID the default user; FACILITY / SCRNHT / SCRNWD on a terminal task, INVREQ RESP2 5 without one, AEIP when unhandled |
| ghost-tasks | [`gt-send-text-terminal`](cases/ghost-tasks/gt-send-text-terminal) | 1 | SEND TEXT ... TERMINAL WAIT FREEKB ERASE: TERMINAL, the default disposition, records the same event as SEND TEXT without it; a START TERMID task sends to the terminal the START named; a task with no terminal sends nothing |
| ghost-tasks | [`gt-http-inbound`](cases/ghost-tasks/gt-http-inbound) | 1 | An inbound HTTP request is a task: SERVER URIMAP to an alias transaction, `WEB RECEIVE` of the body, `WEB SEND` of the response to a stated client peer (two requests, no operator step) |
| ghost-tasks | [`gt-urimap-browse`](cases/ghost-tasks/gt-urimap-browse) | 2 | `INQUIRE URIMAP START / NEXT / END`: a browse of the four installed URIMAPs (name, PATH, TRANSACTION) counted without relying on the order, ILLOGIC RESP2 1 for a START inside a browse, END RESP2 2 past the last, one START for the definition whose name and path qualify, `WRITE OPERATOR` (a new `WRITE-OPERATOR` event); the second run shows END closed the browse |
| ghost-tasks | [`gt-web-parse-url`](cases/ghost-tasks/gt-web-parse-url) | 3 | `WEB PARSE URL`: scheme returned upper case, default ports (80 / 443), explicit port, IPv4 and bracketed IPv6 hosts, INVREQ RESP2 28 (incorrect URL) / 65 (bad escape), LENGERR RESP2 29 / 30 / 8 for a short HOST / PATH / QUERYSTRING buffer; no peer, so no new event |
| pseudo-conversational | [`pc-wizard`](cases/pseudo-conversational/pc-wizard) | 6 | a 3-screen wizard over PC01/PC02/PC03 with state in the COMMAREA; MAPFAIL, CLEAR on each screen, PF3 in either program, an inactive PF key, PF7 back via XCTL under the same transid, a program-written amount not retransmitted |
| pseudo-conversational | [`pc-return-immediate`](cases/pseudo-conversational/pc-return-immediate) | 4 | `RETURN TRANSID COMMAREA IMMEDIATE` attaches the next task at once, with the COMMAREA, leaving the next operator step for what it RETURNs; INVREQ RESP2 2 below the highest logical level and RESP2 1 with no terminal; `LINK ... SYNCONRETURN` is ignored on a local link |
| pseudo-conversational | [`pc-return-channel`](cases/pseudo-conversational/pc-return-channel) | 3 | `RETURN TRANSID CHANNEL`: the next task's current channel (ASSIGN CHANNEL, GET CONTAINER with no CHANNEL) and a channel changed across turns (replaced, created, deleted containers); `RETURN CHANNEL` below the highest logical level is INVREQ RESP2 2 |
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
| ca-container-ccsid / bit-container | After the CCSIDERR (RESP2 3) of INTOCCSID on a BIT container, the INTO area holds the container's bytes. | GET CONTAINER (CHANNEL): "The data was returned without any code page conversion"; the page does not say the area is filled on this condition by name |
| ca-container-byteoffset / read | With BYTEOFFSET, FLENGTH larger than the data left is a maximum, not an error: the read is NORMAL and FLENGTH is set to the container length minus the offset. | GET CONTAINER (CHANNEL): FLENGTH "specifies the maximum length of the data that the program accepts" and "The maximum length returned is equal to the length of the data in the container minus the BYTEOFFSET value"; no sentence says a larger FLENGTH is not LENGERR RESP2 11 |
| ca-getmain-pointer / alloc | Adding 4 to a pointer (through a 4-byte binary REDEFINES, LP(32)) gives the address 4 bytes further on, and `ADDRESS OF` a subordinate item equals the group's address plus its offset. | POINTER phrase: a 4-byte item that "can be the subject or object of a REDEFINES clause"; SET format 5: "ADDRESS OF identifier-7 contains the address of the identifier". No sentence says a pointer value is a plain byte address that arithmetic may move |
| gt-assign-startcode (all) | With security off and nobody signed on, ASSIGN USERID returns `CICSUSER`, DFLTUSER's default, in terminal and started tasks alike. | ASSIGN USERID: "If no user is explicitly signed on, CICS returns the default user ID"; DFLTUSER's default is CICSUSER. No sentence ties these to SEC=NO. |
| hc-deedit-uctranst / uctranst | `UCTRAN(YES)` on the terminal's TYPETERM gives `INQUIRE TERMINAL UCTRANST` the CVDA UCTRAN (450), `NO` NOUCTRAN, `TRANID` TRANIDONLY. | INQUIRE TERMINAL: the value "comes from the UCTRAN option of the associated TYPETERM definition"; the page does not tabulate YES / NO / TRANID against the three CVDAs |
| hc-deedit-uctranst / deedit | A trailing minus sign puts the negative zone X'D' in the rightmost byte of the field after its digits are right-aligned (`123-` in 4 bytes: X'F0F1F2D3'). | BIF DEEDIT: "If the field ends with a minus sign ... a negative zone (X'D') is placed in the rightmost (low-order) byte"; no example shows it |
| hc-resp-options / formattime | After a FORMATTIME that raised INVREQ the case reads neither output area, and the logged ABSTIME is a packed-decimal -1. | FORMATTIME: INVREQ RESP2 1 "The ABSTIME value is less than zero or not in packed-decimal format"; the page does not say what the output areas hold afterwards |
| hc-resp-options / asis | Without ASIS the same input would be upper-cased on this UCTRAN(YES) terminal; the case only reads the ASIS result. | RECEIVE MAP: ASIS "specifies that lowercase characters in the 3270 input data stream are not translated to uppercase"; the page does not tie the default translation to the TYPETERM's UCTRAN |
| hc-inquire-deleteq / origin | The origin data of a task terminal input starts is what the case states in `origin` (SPEC 2); the log shows each value reaching its own area. | INQUIRE ASSOCIATION: ODAPPLID, ODUSERID, ODFACILNAME, ODNETWORKID, ODFACILTYPE are returned from the origin descriptor; the pages do not say what the fields hold for a terminal-started task |
| hc-inquire-deleteq / deleteq | A queue deleted and written again is a new queue: its first item is 1 and `READQ ... NEXT` starts there. | DELETEQ TS removes the queue ("QIDERR ... the queue can't be found" afterwards); the pages do not state the NEXT position of a queue created again |
| hc-named-counters / names | A counter name or pool with a character outside IBM's list (lower case, a leading digit, a hyphen, a space) is INVREQ RESP2 404 / 403; the pool is checked for DELETE, and a DELETE of a well-formed missing name is 201. | DEFINE / GET COUNTER: "RESP2 403: POOL contains invalid characters or embedded spaces", "RESP2 404: COUNTER contains invalid characters or embedded spaces"; the DELETE COUNTER page lists 403 and no 404; the order when both are invalid is not stated, so no scenario provokes both |
| hc-dcounters (life, big) | QUERY DCOUNTER leaves the counter unchanged (L6 then L7, B4, B8, B12), while GET advances it by the increment. | The QUERY page says only that the commands "return the current, maximum, and minimum values" and that VALUE is "the current value"; nothing says it does not advance. GET: "The counter is incremented after the current number has been assigned." |
| hc-counter-increment-wrap (wrap, limit) | A GET that assigns the maximum is NORMAL and puts the counter at its limit; GET WRAP at the limit rewinds to the minimum and returns it (0), the next GET returns 1; failed GETs at the limit leave the counter unchanged. | GET COUNTER: "If you omit the WRAP option, and the counter-at-limit condition is reached, CICS returns SUPPRESSED, RESP2=101"; WRAP "resets the current value of the named counter equal to the minimum value"; "The maximum value ... has already been assigned". Whether the wrapping GET returns the minimum or the next number is not stated word for word |
| hc-file-unlock / unlock-rewrite | After `READ UPDATE` + `UNLOCK` (no TOKEN), a `REWRITE` is INVREQ RESP2 30. | REWRITE: INVREQ RESP2 30 "No token was supplied, and no earlier READ for UPDATE without a token can be found"; UNLOCK: "releases the exclusive control established in response to a read command with the UPDATE option" and matches a tokenless READ UPDATE. No sentence says a REWRITE after UNLOCK is RESP2 30. |
| pc-return-channel (carry, modify) | The channel a `RETURN TRANSID CHANNEL` names is the *current channel* of the next task's first program (ASSIGN CHANNEL names it, GET / PUT / DELETE CONTAINER with no CHANNEL use it). | RETURN: CHANNEL is "made available to the next program that receives control" and a program can RETURN "its current channel by name"; the pages do not say "current channel" of the next task |
| pc-return-channel / modify | Containers replaced, created and deleted in a task are seen so by the task of the next RETURN CHANNEL; the channel is one object, not a copy made at the first RETURN. | RETURN lists creating the channel by PUT CONTAINER, naming the current channel, or naming a new one; nothing says the next task gets a snapshot or a fresh copy |
| ca-address-commarea / no-commarea | `ADDRESS COMMAREA` with no COMMAREA sets the pointer to `X'FF000000'`, and the callee's EIBCALEN is 0 (as for a terminal task). | The ADDRESS page: "If the COMMAREA does not exist, the pointer reference is set to the null value, X'FF000000'"; read at a `6.1.0` URL that names no release (no page naming 6.x was found) and at the 5.6 page. EIB fields page is 5.3. |
| ca-address-twa-tctua / twasize-zero | `TWASIZE(0)` means no TWA exists, so `ADDRESS TWA` gives `X'FF000000'`. | The ADDRESS page: "If a TWA does not exist, the pointer reference is set to the null value, X'FF000000'"; the 5.3 TRANSACTION attributes page gives the range 0 - 32767 but not what 0 means (find exact cite). |
| ca-address-twa-tctua / tctua-two-tasks | A TCTUA written by one task is still there for the next task on the terminal. | The 5.6 TCTUA page ties USERAREALEN to the terminal's TYPETERM; no opened sentence states persistence across tasks (find exact cite). |
| pc-return-immediate / immediate | The task a RETURN IMMEDIATE attaches runs at the same virtual time as the task that RETURNed, on the same terminal, with `eibaid` null, ahead of everything else, and does not use up an operator step. | RETURN IMMEDIATE: "attached as the next transaction regardless of any other transactions enqueued by ATI for this terminal. The next transaction starts immediately and appears to the operator as having been started by terminal data"; the page says nothing of EIBAID or of virtual time, so SPEC 4 states both and the case reads neither |
| gt-http-inbound (all) | The alias transaction of a SERVER URIMAP is a CSD transaction naming the URIMAP's `PROGRAM`, and its task's first program is that program. | "whatever name you choose for the alias transaction, it must always run the same program" and the URIMAP's program overrides the transaction definition's; IBM's default alias runs its own web attach program, which the model does not show |
| gt-urimap-browse (all) | The URIMAP definitions the CSD defines are the ones installed in the region, and a browse returns each of them once; the case uses no order. | "You can also browse through all the URIMAP definitions installed in the region, using the browse options (START, NEXT, and END)"; IBM states no browse order |
| gt-web-parse-url / errors | A URL with no scheme and no `://` (`example.com/a?x=1`) is INVREQ RESP2 28. | WEB PARSE URL: INVREQ RESP2 28 "Incorrect URL"; the page does not say which strings are incorrect |
| gt-web-parse-url / parse | A scheme typed in mixed case (`HtTp`, `hTTps`) is accepted and returned upper case. | "returned in upper case"; the page does not say the input is case-insensitive |
| hc-readq-td (fifo, seeded) | Records come back oldest first (write order; a seeded item before a written one). | "All access is sequential, governed by read and write pointers" and "Once a record has been read, it cannot be read subsequently by another task" (Intrapartition transient data queues); no page found says "first in, first out" |
| hc-readq-td / deleteq | After `DELETEQ TD` the queue is still defined and empty, so `READQ TD` is QZERO, not QIDERR. | DELETEQ TD "deletes all the transient data associated with a particular intrapartition destination (queue)" and releases its storage; the page does not say whether the queue (the TDQUEUE definition) remains; QIDERR is for a destination that "cannot be found". A write after DELETEQ TD is not relied on |
| hc-readq-td / lengerr | A READQ TD whose INTO area is too short is LENGERR with the leading bytes moved and LENGTH the record's full length. Whether the record is also consumed is not relied on. | READQ TD: "the data is truncated to that value and the LENGERR condition occurs", "the data area is set to the original length of the data record"; the page does not say if the record stays |
| hc-readq-td / empty | READQ TD of an empty queue leaves INTO unwritten (the log has `data` null; the case never reads INTO). | QZERO page text only; whether INTO is touched is not stated |
| hc-file-read-set / browse-back | The first `READPREV` after a `STARTBR` returns the record the `STARTBR` named (`K040`), then the browse goes down, and ENDFILE follows the first record. | READPREV: "your STARTBR command RIDFLD must specify the key of a record that exists on the data set"; "READPREV can be used repeatedly to read records in reverse sequential order"; no sentence says the first READPREV returns the STARTBR key's record |
| hc-file-read-set / browse-fwd, browse-notfnd | The first `READNEXT` after a `STARTBR` returns the record the browse is positioned on (`K020` after `GTEQ` of `K015`; `K030` after `EQUAL`). | STARTBR: GTEQ "the first record that has a greater key satisfies the search"; "No records are read until a READNEXT command ... is executed"; the page does not say that READNEXT returns that record itself |
| hc-file-read-set / browse-notfnd | `STARTBR GTEQ` of a key above the last record is NOTFND RESP2 80, and `ENDBR` after an ENDFILE (browse-fwd, browse-back) is NORMAL. | STARTBR NOTFND: "An attempt to position on a record based on the search argument provided is unsuccessful"; ENDBR: INVREQ RESP2 35 only when no successful STARTBR matches; neither page ties these two cases to its sentence |

## Known gaps (future work)

* **Validator cross-checks not yet implemented:**
  * `color`/`hilight` with `*_from: "map"` are not checked against the DFHMDF → DFHMDI →
    DFHMSD `COLOR=`/`HILIGHT=` chain.
  * `data` with `data_from: "map"` is not checked against `INITIAL`.
  * A `{"kind": "start"}` task trigger is not checked against the START it names
    (transid/termid, `at` ≥ `expires`), including the other requests of a coalesced
    terminal start.
* **Coverage:** no case uses `FLENGTH` (the fullword LENGTH form) yet. `DATALENGTH` is
  avoided on purpose (it matters only for DPL). File control (READ / REWRITE / UNLOCK against a KSDS) is in the
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
