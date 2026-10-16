# ca-load-set: LOAD PROGRAM SET(ptr) LENGTH(len)

## The trap

`LOAD PROGRAM(name) SET(ptr) LENGTH(len)` does not copy anything into a program area: CICS
returns the address at which the program was loaded and the program's length (a halfword).
`CALDST` (transaction `CA0L`) LOADs the defined program `CALDTG` with the pointer preset to null
and LENGTH preset to 0, then RELEASEs it. `CALDSX` (`CA0M`) LOADs `CALDXX`, which has no
definition (PGMIDERR), then LOADs `CALDTG`, then RELEASEs it. `CALDTG` is never run. LOAD is
not an event (SPEC 6.2), so each result is a 12-byte record in TS queue `LDLOG` (copybook
`LDLOG`: tag X(4), RESP 9(3), RESP2 9(3), pointer flag X, LENGTH flag X). The flags are `Y` (the
pointer is not null / LENGTH is above zero), `N`, or `-` (not read). No address, length or loaded
byte is logged.

## Why a naive translation breaks

* A port that cannot give a pointer for a program (it has no loaded image) leaves the pointer
  null or throws: `LD01` and `OK01` log `N` for the pointer.
* A port that leaves LENGTH untouched (it is output only) logs `N` for LENGTH.
* A port that treats an undefined program as a runtime exception, or as NORMAL with a null
  pointer, hides PGMIDERR RESP2 1 (`PG01`).
* A port that reads the pointer or LENGTH after the PGMIDERR gets junk; the case does not.

## Expected behaviour

### `load` (`CA0L`, `CALDST`)

1. `SET WS-PTR TO NULL`, `WS-LEN` = 0. `LOAD PROGRAM('CALDTG') SET(WS-PTR) LENGTH(WS-LEN)`:
   "SET(ptr-ref) specifies the pointer reference that is to be set to the address at which a
   program, table, or map is loaded" and "LENGTH(data-area) specifies a halfword binary value to
   be set to the length of the loaded program, table, or map" [LOAD]. NORMAL; the pointer is not
   null and LENGTH is above zero (`LD01000000YY`).
2. `RELEASE PROGRAM('CALDTG')`: the program was loaded by this task without HOLD, and "It may,
   however, be released before this by the task that loaded the resource issuing a RELEASE
   command" [RELEASE]. The page lists INVREQ, NOTAUTH and PGMIDERR and none of them applies (the
   program is loaded, installed, not RELOAD=YES, released by the task that loaded it), so the
   command completes NORMAL (`RL01000000--`). That NORMAL is read from the absence of a
   condition, not from a sentence (README lower-confidence table). `RETURN`.

### `pgmiderr` (`CA0M`, `CALDSX`)

1. `LOAD PROGRAM('CALDXX') SET LENGTH`: CALDXX has no installed definition and program
   autoinstall is off (SPEC section 2). PGMIDERR (27), RESP2 1: "A program, table, or map has no
   installed resource definition and either program autoinstall was switched off, or the
   program autoinstall control program indicated that the program should not be autoinstalled"
   [LOAD] [RESP-CODES]. The pointer and LENGTH are not read (`PG01027001--`).
2. `LOAD PROGRAM('CALDTG')`: NORMAL, pointer set, LENGTH above zero: the failure changed nothing
   (`OK01000000YY`).
3. `RELEASE PROGRAM('CALDTG')`: NORMAL (`RL01000000--`). `RETURN`.

## What a correct port must do

* Return a non-null address for a defined program and set LENGTH above zero, ignoring the
  incoming value of both.
* Raise PGMIDERR RESP2 1 as an ordinary condition for a program with no definition.
* Release a loaded program on RELEASE PROGRAM with NORMAL.

## Avoided ambiguities

* **The loaded program's bytes.** The case never reads through the pointer, never uses
  `SET ADDRESS OF` on it, and does not compare the bytes (they are the load module's, which the
  crucible does not define).
* **The value of LENGTH and of the pointer.** Only "above zero" and "not null" are logged, never
  a number. The page says LENGTH is "the length of the loaded program" and does not say how a
  non-COBOL-image program (a stub) is sized (README lower-confidence table).
* **The pointer and LENGTH after PGMIDERR.** Not read, not logged.
* **The other PGMIDERR RESP2 values** (2 disabled, 3 not loadable, 9 remote, 21 to 24
  autoinstall, 42 JVM). Not exercised: the case has no disabled, remote or autoinstalled
  program.
* **HOLD, ENTRY, FLENGTH, RELOAD=YES programs.** Not exercised. For a program defined
  RELOAD=YES the LOAD page says "RELEASE does not work, and a FREEMAIN request must be issued to
  remove the program" and the RELEASE page gives INVREQ RESP2 17 ("It must be released by a
  FREEMAIN rather than a RELEASE command"); CALDTG is not RELOAD=YES.
* **RELEASE of a program that was not loaded, and a second LOAD of a held program.** Not issued.
* **Program size, key, location, and whether the load is a new or a shared copy.** Not
  asserted.
* **The unhandled conditions.** Every command uses RESP, so the default action is never reached.

## Citations

* [LOAD] CICS TS 6.x, EXEC CICS LOAD (PROGRAM: "the identifier (1 - 8 characters) of a program, table, or map to be loaded"; SET: "Specifies the pointer reference that is to be set to the address at which a program, table, or map is loaded"; LENGTH: "Specifies a halfword binary value to be set to the length of the loaded program, table, or map"; PGMIDERR RESP2 1: "A program, table, or map has no installed resource definition and either program autoinstall was switched off, or the program autoinstall control program indicated that the program should not be autoinstalled"; HOLD: "If you omit HOLD, the program, table, or map is released when the task that issued the load terminates or issues a RELEASE command"; RELOAD=YES: "RELEASE does not work, and a FREEMAIN request must be issued to remove the program"): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-load
* [RESP-CODES] CICS TS 6.x, Response codes of EXEC CICS commands (PGMIDERR 27): https://www.ibm.com/docs/en/cics-ts/6.x?topic=codes-response-exec-cics-commands
* [RELEASE] CICS TS 6.x, EXEC CICS RELEASE ("RELEASE releases the program, table, or mapset previously loaded by a LOAD command"; "If the HOLD option is not specified in the LOAD command, the loaded resource is released at the end of the task. It may, however, be released before this by the task that loaded the resource issuing a RELEASE command"; "RELEASE does not remove a program from storage"; conditions listed: INVREQ (RESP2 6 "The command is issued for a program that is not loaded", RESP2 7 a program "loaded, without the HOLD option, by another task", RESP2 17 "The program is defined with RELOAD=YES. It must be released by a FREEMAIN rather than a RELEASE command"), NOTAUTH, PGMIDERR; no NORMAL entry): https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-release
