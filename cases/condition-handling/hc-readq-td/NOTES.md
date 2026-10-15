# hc-readq-td: READQ TD is a destructive FIFO read; QZERO, QIDERR, DELETEQ TD then READQ, LENGERR

The transient-data (TD) lane of the queue commands. The temporary storage lane is covered by other cases; this one does not repeat
it. Intrapartition queues only, with no trigger level and no automatic transaction initiation (see Avoided ambiguities).

## The trap

`HCRQTD` (transaction `HC82`) is typed with a mode after `HC82` and issues TD commands on intrapartition queue `HCQ1` (CSD
`DEFINE TDQUEUE(HCQ1) TYPE(INTRA) RECOVSTATUS(NO)`) and, in mode `U`, on `HCNQ`, which the CSD does not define. Every command has
`RESP`, so no condition abends the task, and each command is one `WRITEQ-TD` / `READQ-TD` / `DELETEQ-TD` event.

* **F** (fifo): WRITEQ TD three items (`ALPHA` 5 bytes, `BRAVO77` 7, `EIGHTCHR` 8), READQ TD four times into an 8-byte area
  (`LENGTH(8)` set before each read), the fourth on a drained queue.
* **S** (seeded): the scenario seeds `HCQ1` with `SEEDED1`; the program writes `BRAVO77`, then reads three times.
* **E** (empty): READQ TD of an empty queue; the INTO area holds `XXXXXXXX`.
* **U** (undefined): READQ, WRITEQ and DELETEQ TD of `HCNQ`.
* **D** (deleteq): WRITEQ TD three items, DELETEQ TD `HCQ1`, READQ TD.
* **L** (lengerr): WRITEQ TD `LONGITEM`, READQ TD into a 4-byte area with `LENGTH(4)`.

## Why a naive translation breaks

* A port that backs a TD queue with a TS queue (or a list read by index) leaves the record in place: the second read returns the
  first item again, and the fourth read finds data instead of QZERO.
* A port that reads newest-first (a stack) swaps `ALPHA` and `EIGHTCHR` in F.
* A port that creates a queue on first WRITEQ TD (as TS does) returns NORMAL in U; IBM says a TD queue must be defined, and
  QIDERR is raised when it "cannot be found".
* A port that answers READQ of an empty queue with ENDFILE, NOTFND or an empty NORMAL read logs a different RESP in E.
* A port that fails a short INTO area without moving the truncated data, or without setting LENGTH to the record's length, differs in L.

## Expected behaviour

Model (SPEC sections 2 and 4): T001 is a 3270 display; each scenario starts at 10:00:00 on 2026-03-02 with `HC82 <mode>` typed on
T001. `HCQ1` is empty at the start unless the scenario seeds it. No RESP2 is logged: the IBM pages give none for these conditions
[READQ-TD] [WRITEQ-TD] [DELETEQ-TD].

* **`fifo`** (F): READQ TD "reads transient data from a queue (after which the record is no longer available)" [READQ-TD], and
  intrapartition access is "sequential, governed by read and write pointers", "Once a record has been read, it cannot be read
  subsequently by another task" [TD-INTRA]. So the reads return `ALPHA`, `BRAVO77`, `EIGHTCHR` in write order. After each read
  `LENGTH` is "set to the original length of the data record read" [READQ-TD]: 5, 7, 8 (the 8-byte record equals the area, so
  there is no LENGERR); only that many bytes of INTO are written. The fourth read: QZERO, "Occurs when the destination (queue) is
  empty or the end of the queue has been reached" [READQ-TD]; INTO is not written (`data` null). Final `HCQ1`: empty.
  The order is a reading, see the README lower-confidence table.
* **`seeded`** (S): the seeded item was written before the written one, so it is read first (same reading); both are 7 bytes;
  then QZERO. Final `HCQ1`: empty.
* **`empty`** (E): QZERO on a queue holding no record [READQ-TD]. Whether INTO is untouched is not stated; the log records
  `data` null and the case never reads INTO.
* **`undefined`** (U): READQ TD "Occurs if the symbolic destination to be used with READQ TD cannot be found" (QIDERR)
  [READQ-TD]; WRITEQ TD "Occurs if the symbolic destination to be used with a transient data control command cannot be found"
  [WRITEQ-TD], and "The named queue must already be defined to CICS" ([WRITEQ-TD] QUEUE; DELETEQ TD says the same); DELETEQ TD
  "Occurs if the symbolic destination to be used with DELETEQ TD cannot be found" [DELETEQ-TD]. A queue the CSD does not define is
  one CICS cannot find, so all three are QIDERR [TDQUEUE]. The three events name `HCNQ`; the validator accepts an undefined
  queue only on a QIDERR event.
* **`deleteq`** (D): "DELETEQ TD deletes all the transient data associated with a particular intrapartition destination
  (queue)" [DELETEQ-TD]: NORMAL, and the three items are gone. The READQ TD that follows is QZERO. That the queue is still
  defined, so that the answer is QZERO and not QIDERR, is a reading (the page releases "all storage associated with the
  destination" and says nothing of the definition, which is the TDQUEUE resource [TDQUEUE]): README lower-confidence table. No
  command writes to the queue afterwards.
* **`lengerr`** (L): READQ "Occurs if READQ names an INTO area that cannot hold all the data that is to be returned"
  (LENGERR) [READQ-TD]; "the data is truncated to that value and the LENGERR condition occurs" and LENGTH is "set to the
  original length of the data record": the 4 bytes `LONG` are moved and LENGTH comes back 8. The log has no `final` for `HCQ1`:
  whether the truncated record is also consumed is not relied on.

## What a correct port must do

* Keep an intrapartition TD queue as an ordered, destructive queue: write appends, read returns the oldest record and removes it.
* QZERO for a read of an empty or drained queue, with the INTO area unwritten.
* QIDERR for READQ, WRITEQ and DELETEQ of a queue the region does not define; never create one on write.
* DELETEQ TD removes every record; a following read is QZERO (see the README row).
* On a short INTO area: LENGERR, the leading bytes moved, LENGTH set to the record's length.

## Avoided ambiguities

* **Trigger levels, automatic transaction initiation, TRANSID / FACILITYID, recoverable (`LOGICAL` / `PHYSICAL`) queues**: the
  queue is `RECOVSTATUS(NO)` with no `TRIGGERLEVEL`, so QBUSY (a recoverable-queue condition [READQ-TD]) and NOSUSPEND are not used.
* **Extrapartition, indirect and remote queues**, SYSID, `READQ TD SET`: not used.
* **RESP2**: none of the three pages gives a RESP2 value for these conditions; no event carries one.
* **READQ TD with `LENGTH` 0 or negative**: IBM's page says a negative value raises LENGERR with the queue unread; the zero case
  changed between releases (APAR PI86627). Neither is used.
* **Whether a LENGERR read consumes the record**, **the INTO area after QZERO**, **a write after DELETEQ TD**: not relied on.
* **WRITEQ TD LENGTH versus the control interval** (LENGERR on write): every item is far below it, and no case writes a zero length.
* **NOSPACE, LOCKED, IOERR, DISABLED, NOTAUTH**: not reachable in this region.

## Citations

Pages opened 2026-10-15 (CICS TS 5.5 / 6.x documentation on ibm.com):

* [READQ-TD] EXEC CICS READQ TD (CICS TS 5.5, application programming reference; same conditions in 6.x):
  https://www.ibm.com/docs/SSGMCP_5.5.0/reference/commands-api/dfhp4_readqtd.html
  Quoted: description; INTO; LENGTH (truncation, "set to the original length"); QZERO; QIDERR; LENGERR; QBUSY.
* [WRITEQ-TD] EXEC CICS WRITEQ TD (CICS TS 6.x):
  https://www.ibm.com/docs/SSJL4D_6.x/reference-applications/commands-api/dfhp4_writeqtd.html
  Quoted: description; QUEUE; QIDERR; LENGERR.
* [DELETEQ-TD] EXEC CICS DELETEQ TD (CICS TS 6.x):
  https://www.ibm.com/docs/SSJL4D_6.x/reference-applications/commands-api/dfhp4_deleteqtd.html
  Quoted: description; QUEUE; QIDERR.
* [TDQUEUE] TDQUEUE resources (CICS TS 6.x):
  https://www.ibm.com/docs/en/SSJL4D_6.x/reference-system-management/resources/tdqueue/dfha4_summary.html
  Quoted: "defines the attributes of a transient data queue"; TYPE INTRA; RECOVSTATUS(NO) "not recoverable"; the 1- to 4-character name.
* [TD-INTRA] Intrapartition transient data queues (CICS TS 5.5):
  https://ibm.com/support/knowledgecenter/SSGMCP_5.5.0/applications/designing/dfhp3mr.html
  Quoted: "All access is sequential, governed by read and write pointers."; "Once a record has been read, it cannot be read subsequently by another task."
* APAR PI86627 (READQ TD LENGTH(0)): https://www.ibm.com/support/pages/apar/PI86627 (read in a search summary only; used for the avoided-zero-length note).
