# hc-send-map-freekb

## The trap

`FREEKB` on `EXEC CICS SEND MAP` unlocks the 3270 keyboard after the write. The expected log records it in the
`options` of the SEND-MAP event only when the program wrote it. Eight burned programs (CardDemo, CBSA) send maps
with `FREEKB`, in combination with `ERASE`, `ALARM`, `DATAONLY` and `MAPONLY`; no earlier case logged one.
A map-level `CTRL=(FREEKB)` (DFHMDI) also unlocks the keyboard, but it is not a send option and never appears in `options`.

## Why a naive translation breaks

* A port that drops `FREEKB` because "the keyboard is not modelled" loses a logged option (modes A-D).
* A port that adds `FREEKB` whenever the map says `CTRL=(FREEKB)` logs an option the program never wrote (mode F).
* A port that sorts or merges options wrongly (`ALARM ERASE FREEKB`, `ERASE FREEKB MAPONLY`) fails the sorted-subset rule.
* `FREEKB` must not change what is sent: DATAONLY still sends only program data, MAPONLY only map defaults.

## Expected behaviour

HC43 receives its input (`HC43 x`), takes the mode from byte 6, does one SEND MAP and RETURNs. Mapset HCFSET has
map HCFA (no CTRL anywhere) and HCFB (`CTRL=(FREEKB)` on the DFHMDI; the DFHMSD has no CTRL, as IBM allows only one of the two).

| Scenario | Command | Logged `options` |
|---|---|---|
| mode-a | `MAP(HCFA) FROM ERASE FREEKB` | `ERASE FREEKB` |
| mode-b | `MAP(HCFA) FROM ERASE ALARM FREEKB` | `ALARM ERASE FREEKB` |
| mode-c | `MAP(HCFA) FROM DATAONLY FREEKB` | `DATAONLY FREEKB`; only AMSG (program data, no attribute) |
| mode-d | `MAP(HCFA) MAPONLY ERASE FREEKB` | `ERASE FREEKB MAPONLY`; map defaults, program data ignored |
| mode-e | `MAP(HCFA) FROM ERASE` | `ERASE` (the keyboard stays locked) |
| mode-f | `MAP(HCFB) FROM ERASE` | `ERASE` (the keyboard unlocks through the map's CTRL, not a send option) |

Fields: AMSG/BMSG are ASKIP,NORM (attribute F0, from the map); ANAME/BNAME are UNPROT,NORM,IC (40, from the map).
The program moves `MODE <x>` into the message field, so its data is program-supplied; the name field has no data.
ERASE sends put the cursor at the IC field; the DATAONLY send logs no cursor, as in hx-mdt-reset.

## What a correct port must do

Log exactly the options the program wrote, sorted; send the same fields as without FREEKB; take no option from the
map's CTRL. A runtime that models the keyboard lock must treat both the option and a map CTRL as unlocking it, but
the log still shows only the option.

## Avoided ambiguities

* IBM does not say whether a FREEKB on one SEND MAP carries to a later SEND MAP that omits it: every scenario has one send.
* Under DATAONLY the case does not depend on where the IC attribute puts the cursor: no cursor is logged, as in hx-mdt-reset.
* The case does not run CTRL on the DFHMSD and DFHMDI of one mapset (IBM forbids it).

## Citations

* IBM CICS TS 6.x, EXEC CICS SEND MAP: FREEKB "specifies that the 3270 keyboard should be unlocked after the data is written";
  "If FREEKB is omitted, the keyboard remains locked." ALARM, ERASE, MAPONLY, DATAONLY, CURSOR options on the same page
  (https://www.ibm.com/docs/en/cics-ts/6.x?topic=summary-send-map).
* IBM CICS TS 6.x, DFHMDI: "Use of any of the control options in the SEND MAP command overrides all control options in the
  DFHMDI macro"; FREEKB under CTRL "causes the keyboard to be unlocked after the map is written"; "CTRL cannot be specified
  in the DFHMDI and DFHMSD macros in the same mapset" (https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmdi).
* IBM CICS TS 6.x, DFHMSD, CTRL (https://www.ibm.com/docs/en/cics-ts/6.x?topic=macros-dfhmsd).
* The expected logs were derived by hand from these pages and the program text, not from any tool's output.
