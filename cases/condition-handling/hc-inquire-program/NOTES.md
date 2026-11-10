# hc-inquire-program: INQUIRE PROGRAM with RESP

## The trap

`HCINQP` (transaction `HC96`) inquires on four program names with `EXEC CICS INQUIRE PROGRAM(name) STATUS(fullword)
RESP(..)` and logs to TS queue `HCLOG` (INQUIRE is not an event, SPEC 6.2). Item: tag (2), ` R=`, RESP (2), ` S=`, the
STATUS value (4 digits; 0000 when the command was not NORMAL): 14 bytes.

* **P1** `HCINQT`, defined `STATUS(ENABLED)`. **P2** `HCINQX`, defined `STATUS(DISABLED)`. **P3** `HCINQP`, the running
  program. **P4** `NOSUCHP`, which has no definition.

## Why a naive translation breaks

* A port that cannot translate `INQUIRE PROGRAM`, or that answers from the program's source instead of the CSD, fails P2.
* A port that returns the status as text, not the CVDA fullword (ENABLED 23, DISABLED 24), stores the wrong value.
* A port that answers NORMAL for any name (autoinstall-like behaviour) fails P4; autoinstall is off (SPEC section 2).

## Expected behaviour

* [INQUIRE] `INQUIRE PROGRAM` names the program in `PROGRAM`. `STATUS( cvda )` "Returns a CVDA value that indicates whether
  the module is available for use": DISABLED "The module is not available for use", ENABLED "The module is available for
  use". Numeric values: DISABLED 24, ENABLED 23 [CVDA]. The installed definition's `STATUS` attribute gives the program's
  state (a reading, README lower-confidence table; no SET PROGRAM is issued). P1 NORMAL, ENABLED: `P1 R=00 S=0023`. P2
  NORMAL, DISABLED: `P2 R=00 S=0024`. P3 NORMAL, the running program is installed and enabled: `P3 R=00 S=0023`.
* [INQUIRE] An undefined name raises PGMIDERR: "If the PROGRAM resource is not available as a public resource, a PGMIDERR
  condition is returned"; PGMIDERR RESP2 1 "The program cannot be found". RESP 27 [RESP-CODES]: `P4 R=27 S=0000`; the program
  zeroes the status itself, so what CICS leaves in the area on an error is not read. RESP2 is not logged.
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

* [INQUIRE] CICS TS 6.x, CICS SPI command INQUIRE PROGRAM (STATUS, conditions NOTAUTH, PGMIDERR, PGMIDERR RESP2 1):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-program
* [CVDA] CICS TS 6.x, API Reference, CVDAs and numeric values in alphabetic sequence (DISABLED 24, ENABLED 23):
  https://www.ibm.com/docs/en/SSJL4D_6.x/pdf/api-reference_pdf.pdf
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0, PGMIDERR 27):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
