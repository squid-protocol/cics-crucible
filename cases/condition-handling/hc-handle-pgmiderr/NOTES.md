# hc-handle-pgmiderr: a LINK or XCTL to a program with no definition is a jump, a return code or an abend

## The trap

`HCPGMI` issues `LINK PROGRAM('HCGONE')` (or `XCTL`) for a program the CSD does not define. Program autoinstall is off
(SPEC section 2), so the command raises PGMIDERR with RESP2 1. Four transactions run the same program:

* **HP01**: `HANDLE CONDITION PGMIDERR(NO-PROG)`, then LINK. Control goes to `NO-PROG`; `MOVE 'LINK RETURNED'` after the
  LINK never runs. SEND TEXT `AT LABEL`.
* **HP02**: the same with XCTL. A failed XCTL does not transfer control, so the label runs in `HCPGMI`.
* **HP03**: no handler, no RESP, LINK. The default action, task abend AEI0.
* **HP04**: the handler is set but the target `HCPGMT` is defined: no condition, SEND TEXT `LINK RETURNED`.

## Why a naive translation breaks

* Porting PGMIDERR as a return code, or ignoring it, runs the statement after the LINK on HP01 and HP02
  (`LINK RETURNED` instead of `AT LABEL`).
* Porting a missing program as a Java exception nobody catches abends HP01 and HP02, which have a handler.
* Treating the handler as raised on a LINK that worked (HP04).
* Giving HP03 a return code instead of the abend.

## Expected behaviour

Model (SPEC sections 2 and 4): one region, terminal T001, clock 2026-03-02T10:00:00. Each scenario is one task.

* **`link-handler`**: LINK event resp PGMIDERR, resp2 1 ("A program has no installed resource definition and either
  program autoinstall was switched off ..." [LINK]). HANDLE CONDITION is active ("Use the HANDLE CONDITION command to specify
  the label to which control is to be passed if a condition occurs" [HANDLE-CONDITION]): SEND TEXT `AT LABEL`, RETURN.
* **`xctl-handler`**: XCTL event resp PGMIDERR, resp2 1 [XCTL]; SPEC 6.2: "on failure control stays in the issuing
  program". SEND TEXT `AT LABEL`, RETURN.
* **`link-unhandled`**: LINK event PGMIDERR resp2 1, then "Default action: end the task abnormally." [LINK], abend
  AEI0 (SPEC section 6.2, PGMIDERR -> AEI0). Nothing is sent.
* **`link-defined`**: LINK resp NORMAL, `HCPGMT` returns (RETURN level 2), the handler is not taken: SEND TEXT `LINK RETURNED`.

## What a correct port must do

* Go to the HANDLE CONDITION label on PGMIDERR from LINK and from XCTL, and skip the statement after the command.
* Keep control in the issuing program after a failed XCTL.
* Abend with AEI0 when PGMIDERR has no handler and no RESP.
* Not raise PGMIDERR for a defined program.

## Avoided ambiguities

* **Other PGMIDERR RESP2 values** (2 disabled, 3 not loadable, 9 remote, 21 to 26): no program here has them.
* **The abend code AEI0** comes from SPEC section 6.2's table; the IBM abend-code page was not fetched for this case.
  If the table is wrong, this case is.
* **The DFHAC2206 message** CICS writes on an abend is not an event (SPEC section 6.2).
* **RESP on the same command** is covered by `ca-link-lengths` (`undefined-program`); no scenario here uses it.
* **XCTL default abend**: not exercised, the XCTL page's default action is the same text; no scenario depends on it.

## Citations

* [LINK] IBM CICS TS 6.x, EXEC CICS LINK (PGMIDERR RESP2 1; "Default action: end the task abnormally."):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-link
* [XCTL] IBM CICS TS 6.x, EXEC CICS XCTL (PGMIDERR RESP2 1; "Default action: terminate the task abnormally."):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-xctl
* [HANDLE-CONDITION] IBM CICS TS 6.x, EXEC CICS HANDLE CONDITION:
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-handle-condition
