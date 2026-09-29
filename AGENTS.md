# AGENTS.md — cics-crucible

Vendor-neutral guidance for any coding agent working in this repo. Repo-specific rules live
here. The multi-repo picture lives in the gitgalaxy engine repo's **`docs/ecosystem.md`**
(the constellation map, cross-repo workflow ordering, PR conventions). Read it before any
cross-repo work.

## What this repo is

The **CICS crucible**: small, original CICS COBOL applications (programs, BMS maps, CSD
definitions, copybooks) that attack five CICS-to-Java traps. Each scenario ships a
hand-written expected event log that states what IBM CICS TS does. The format is defined in
[`SPEC.md`](SPEC.md) and checked by [`tools/validate.py`](tools/validate.py). gitgalaxy's
`cics_crucible` runner (phase 2 of
[gitgalaxy#3989](https://github.com/squid-protocol/gitgalaxy/issues/3989)) will run the
generated Java and the COBOL on its stub runtime against these logs.

## Hard rules

1. **Original code only.** Never copy programs, maps, copybooks or data from CardDemo,
   GenApp, CBSA, IBM samples, or anywhere else. Not even "just the layout". Everything here
   is Apache-2.0 and written for this repo. The `tools/stubs/` copybooks are stand-ins
   written from IBM's documented values, not IBM's files.
2. **The expected log is the oracle, and it comes from IBM's documentation.** Every
   behaviour a log asserts that is not obvious from the COBOL must be cited in the case's
   `NOTES.md`: the IBM page URL (or publication number and section) and the quoted rule. Do
   not generate or "refresh" a log from any tool's output: not gitgalaxy's stub runtime, not
   a Java port, not an emulator.
3. **Never edit an expected log to match a tool.** Change a log only when you can show,
   from IBM documentation, that the log was wrong. Record the reason, the citation and the
   date in that case's `NOTES.md` (add a `## Changes` section). A tool disagreeing with a log
   is a bug report against the tool until proven otherwise.
4. **Design out ambiguity; don't guess.** If CICS behaviour is release-dependent or
   undocumented, change the case so that no scenario depends on it, and say so under
   `## Avoided ambiguities`. If a log must rest on a reading that no single IBM sentence
   states, list it in the README's lower-confidence table.
5. **Keep the format honest.** A change to what a file *means* bumps the major number in
   `SPEC.md`, both schemas and every file's `format`. Additive optional keys do not. Update
   `tools/validate.py` in the same change.
6. **Validate before you push.** Run `python3 tools/validate.py` (required, and CI enforces
   it). Run `python3 tools/syntax_check.py` when GnuCOBOL or Docker is available.
7. **Cross-repo PRs carry a "Cross-repo" note** (companion PR links, merge order, what
   re-runs after), per gitgalaxy's `docs/ecosystem.md`.

## Adding a case

1. Pick the trap directory and a unique kebab-case id. Transids and programs use the trap
   prefix: `HC`, `HX`, `CA`, `GT`, `PC`.
2. Write the program(s), BMS and symbolic-map copybook, CSD and case.json per `SPEC.md`.
   Give ATTRB explicitly with protection and intensity. Make every INITIAL exactly its
   field's length. Keep COMMAREA layouts free of FILLER, so INITIALIZE defines every byte.
3. Hand-write `expected/<scenario>.json`, tracing the program line by line against the IBM
   rules. Make each trap observable: a breadcrumb trail on the screen or in a TS queue.
4. Write `NOTES.md` with the required sections and citations, then validate.

## Releases and the gitgalaxy pin

gitgalaxy will pin this repo to a **release tag**, the way it pins language-crucible
(`LANGUAGE_CRUCIBLE_REF` + `tests/_crucible_pin.py`). The pin variable and runner are phase 2
of gitgalaxy#3989 and do not exist yet. No tag has been cut. Tagging is a deliberate,
coordinated step: see [`RELEASING.md`](RELEASING.md). Never create tags or releases as a
side effect of other work.
