# hc-inquire-program: INQUIRE PROGRAM with RESP

## The trap

`HCINQP` (transaction `HC96`) inquires on two program names with `EXEC CICS INQUIRE PROGRAM(name) STATUS(fullword)
RESP(..)` and logs to TS queue `HCLOG` (INQUIRE is not an event, SPEC 6.2). Item: tag (2), ` R=`, RESP (2), ` S=`, the
STATUS value (4 digits; 0000 when the command was not NORMAL): 14 bytes.

* **P1** `HCINQP`, the running program. **P2** `NOSUCHP`, which has no definition.

## Why a naive translation breaks

* A port that cannot translate `INQUIRE PROGRAM` fails the program outright.
* A port that returns the status as text, not the CVDA fullword (ENABLED 23), stores the wrong value.
* A port that answers NORMAL for any name (autoinstall-like behaviour) fails P2; autoinstall is off (SPEC section 2).

## Expected behaviour

* [INQUIRE] `INQUIRE PROGRAM` names the program in `PROGRAM`. `STATUS( cvda )` "Returns a CVDA value that indicates whether
  the module is available for use": DISABLED "The module is not available for use", ENABLED "The module is available for
  use". Numeric values: DISABLED 24, ENABLED 23 [CVDA]. P1 is the program that is running, so it is available for use:
  NORMAL, ENABLED: `P1 R=00 S=0023`.
* [INQUIRE] An undefined name raises PGMIDERR: "If the PROGRAM resource is not available as a public resource, a PGMIDERR
  condition is returned"; PGMIDERR RESP2 1 "The program cannot be found". RESP 27 [RESP-CODES]: `P2 R=27 S=0000`; the program
  zeroes the status itself, so what CICS leaves in the area on an error is not read. RESP2 is not logged.
* The task ends normally: `SEND TEXT ... ERASE`, `RETURN`.

## What a correct port must do

* Return the CVDA fullword for a defined program, raise PGMIDERR for an unknown name, write the two items in order, send
  `DONE OK` and RETURN.

## Avoided ambiguities

* **DISABLED programs:** not exercised. That a CSD `DEFINE PROGRAM ... STATUS(DISABLED)` installs a program that INQUIRE
  reports DISABLED rests on the RDO PROGRAM attributes page, which could not be opened when the case was written, so no
  scenario depends on it. Likewise no other program is inquired on, so no result depends on a definition's default status.
* **Other attributes:** LANGUAGE, LENGTH, USECOUNT, ENTRYPOINT, SHARESTATUS, PROGTYPE and their CVDA values are not read.
* **RESP2 and NOTAUTH:** not asserted; security is not modelled.
* **INQUIRE PROGRAM BROWSE** (START / NEXT / END) is not used.

## Citations

* [INQUIRE] CICS TS 6.x, CICS SPI command INQUIRE PROGRAM (STATUS, conditions NOTAUTH, PGMIDERR, PGMIDERR RESP2 1):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=commands-inquire-program
* [CVDA] CICS TS 6.x, API Reference, CVDAs and numeric values in alphabetic sequence (DISABLED 24, ENABLED 23):
  https://www.ibm.com/docs/en/SSJL4D_6.x/pdf/api-reference_pdf.pdf
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (NORMAL 0, PGMIDERR 27):
  https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
