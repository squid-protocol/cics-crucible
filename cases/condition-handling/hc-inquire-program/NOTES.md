# hc-inquire-program: INQUIRE PROGRAM with RESP

## The trap

`HCINQP` (transaction `HC96`) inquires on four program names with `EXEC CICS INQUIRE PROGRAM(name) ENABLESTATUS(fullword)
RESP(..)` and logs to TS queue `HCLOG` (INQUIRE is not an event, SPEC 6.2). Item: tag (2), ` R=`, RESP (2), ` S=`, the
ENABLESTATUS value (4 digits; 0000 when the command was not NORMAL): 14 bytes.

* **P1** `HCINQT`, defined `STATUS(ENABLED)`. **P2** `HCINQX`, defined `STATUS(DISABLED)`. **P3** `HCINQP`, the running
  program. **P4** `NOSUCHP`, which has no definition.

## Why a naive translation breaks

* A port that cannot translate `INQUIRE PROGRAM`, or that answers from the program's source instead of the CSD, fails P2.
* A port that returns the status as text, not the CVDA fullword (ENABLED 23, DISABLED 24), stores the wrong value.
* A port that answers NORMAL for any name (autoinstall-like behaviour) fails P4; autoinstall is off (SPEC section 2).

## Expected behaviour

* [INQUIRE] `INQUIRE PROGRAM` names the program in `PROGRAM`; `ENABLESTATUS` returns "a CVDA value indicating whether the
  program is enabled": ENABLED or DISABLED, which come from the definition's `STATUS` attribute (no SET PROGRAM is issued).
  P1 NORMAL, CVDA ENABLED = 23: `P1 R=00 S=0023`. P2 NORMAL, DISABLED = 24: `P2 R=00 S=0024`. P3 NORMAL, the running program
  is defined and enabled: `P3 R=00 S=0023`.
* [INQUIRE] An undefined name raises PGMIDERR ("the program cannot be found"), RESP 27: `P4 R=27 S=0000`; the program zeroes
  the status itself, so what CICS leaves in the area on an error is not read.
* The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Answer from the CSD definition (status by name), raise PGMIDERR for an unknown name, return the CVDA values, write the four
  items in order, send `DONE OK` and RETURN.

## Avoided ambiguities

* **Other attributes:** LANGUAGE, LENGTH, USECOUNT, ENTRYPOINT, SHARESTATUS, PROGTYPE and the CVDA values for them are not
  read (use counts and storage details depend on the region's history and release).
* **RESP2 and NOTAUTH:** not asserted; security is not modelled.
* **INQUIRE PROGRAM BROWSE** (START / NEXT / END) is not used.
* A DISABLED program is never LINKed to or started.

## Citations

* [INQUIRE] CICS TS 6.x, EXEC CICS INQUIRE PROGRAM (ENABLESTATUS, CVDA values, conditions PGMIDERR, NOTAUTH):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-program
* [CSD] CICS TS 6.x, PROGRAM resource definition attributes (STATUS(ENABLED | DISABLED)):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=definitions-program-attributes
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0, PGMIDERR 27):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
