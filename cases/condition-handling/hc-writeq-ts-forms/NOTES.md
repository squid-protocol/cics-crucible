# hc-writeq-ts-forms: WRITEQ TS with RESP, every option a burned program uses, and the two REWRITE failures

## The trap

`HCWQTS` (transaction `HC97`) issues seven `WRITEQ TS` commands, each with `RESP(..)`. After each it logs the `ITEM` and
`NUMITEMS` data areas and the RESP to TS queue `HCLOG` (a data area is not an event, SPEC 6.2). Log item: tag (2),
` I=`, item (2), ` N=`, numitems (2), ` R=`, RESP (2): 17 bytes. Tags `W1`-`W7`, in order:

* **W1** new queue `HCQA`, `NOSUSPEND`, `ITEM(..)`: item 1.
* **W2** same queue, `NOSUSPEND`, `ITEM(..)` and `NUMITEMS(..)`: item 2, two items in the queue.
* **W3** new queue `HCQB`, `AUXILIARY`, `ITEM` and `NUMITEMS`: item 1, one item.
* **W4** new queue `HCQC`, `MAIN`, `ITEM`: item 1.
* **W5** `REWRITE ITEM(2)` of `HCQA` with `NOSUSPEND`: replaces item 2 (`BBBBB` becomes `RRRRR`).
* **W6** `REWRITE ITEM(7)` of `HCQA`, which holds two items: ITEMERR.
* **W7** `REWRITE ITEM(1)` of `HCNOQ`, which does not exist: QIDERR.

## Why a naive translation breaks

* A port that rejects `NOSUSPEND`, `MAIN` or `AUXILIARY` on a write (or treats NOSUSPEND as "fail when anything else holds
  the queue") fails W1-W5: on one task nothing can be unavailable, so each is NORMAL.
* A port that returns the item count in `ITEM`, or `ITEM` in `NUMITEMS`, shows the wrong numbers in the W2 / W3 log lines.
* A port that appends on `REWRITE` instead of replacing, or renumbers the item, fails W5 and the final state of `HCQA`.
* A port that creates a queue on a REWRITE of an absent one, or abends instead of answering RESP, fails W7.
* A port that changes the queue on the failed W6 fails the final state of `HCQA`.

## Expected behaviour

Model (SPEC sections 2 and 4): one terminal `T001`, no other task, clock 2026-03-02T10:00:00, no TSMODEL (so MAIN /
AUXILIARY are honoured and the queues are not recoverable, nothing to do with syncpoint).

* **`forms`**: one task.
  * W1-W4 are NORMAL: "ITEM(data-area) ... returns the item number assigned to the data" [WRITEQ-TS]; a queue is created by
    the first write to it; `NUMITEMS` returns "the number of items in the queue" [WRITEQ-TS], so 2 after W2 and 1 after W3.
    `NOSUSPEND` "specifies that the application program is not to be suspended if NOSPACE would otherwise occur" in
    the queue's storage [WRITEQ-TS]; no storage is short, so it has no effect. `MAIN` and `AUXILIARY` are used only on a
    queue that does not exist yet (W3, W4).
  * W5: with `REWRITE`, `ITEM` is "the item number of the entry to be replaced" and the item keeps its number
    [WRITEQ-TS]: the event carries item 2, and the queue is `AAAAA`, `RRRRR`. `ITEM` is an input here and stays 2.
  * W6: item 7 is past the last item of `HCQA`: ITEMERR "occurs when ... REWRITE ... the item number specified is not
    valid" [WRITEQ-TS]. RESP is given, so the task is not abended. Nothing is written, so the event has no item number
    (null) and the queue is unchanged; the program's `ITEM` area keeps its 7.
  * W7: "QIDERR occurs if the queue name cannot be found" [WRITEQ-TS] on a REWRITE: no queue is created.
  * RESP numbers in the log: NORMAL 0, ITEMERR 26, QIDERR 44 [RESP-CODES].
  * Every `HCLOG` item is itself a NORMAL `WRITEQ TS`, numbered 1-7. The task then sends `DONE OK` and RETURNs.
* Final TS state: `HCQA` = `AAAAA`, `RRRRR`; `HCQB` = `CCCCC`; `HCQC` = `CCCCC`; `HCLOG` = the seven log lines.

## What a correct port must do

* Accept every option above, give W1-W5 RESP NORMAL with the item numbers and NUMITEMS stated, replace item 2 in place
  on W5, answer W6 ITEMERR and W7 QIDERR without changing any queue, and write the seven `HCLOG` items.

## Avoided ambiguities

* **`MAIN` / `AUXILIARY` on a queue that already exists:** not used (IBM's wording on which wins is not relied on).
* **NOSPACE, and the NOSUSPEND case it exists for:** needs a full TS pool, which the model has no way to state; not used.
* **`NUMITEMS` on a REWRITE:** not requested (the log shows `N=00`, the preset), so no reading of IBM is needed.
* **RESP2 values:** the event has no RESP2 key for WRITEQ-TS and none is asserted.
* **`ITEM` after a failed command:** the case only asserts what the program preset (W6 `I=07`, W7 `I=01`).
* **A REWRITE where `LENGTH` differs from the stored item:** every FROM is 5 bytes, the length of the item it replaces.

## Citations

* [WRITEQ-TS] IBM CICS TS 6.x, Application Programming Reference, EXEC CICS WRITEQ TS:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-writeq-ts
* [RESP-CODES] IBM CICS TS 6.x, RESP and RESP2 values (EIBRESP codes): https://www.ibm.com/docs/en/cics-ts/6.x?topic=application-conditions
