# Releasing / tagging this repo

**No tag has been cut yet.** This file exists so that cutting the first one, and every one
after it, is a deliberate, coordinated decision. It must never happen by accident, and it
must never silently change what gitgalaxy's CI tests against.

## How the pin will work

This mirrors [language-crucible's `RELEASING.md`](https://github.com/squid-protocol/language-crucible/blob/main/RELEASING.md).
gitgalaxy will clone this repo **at a release tag**, never at `main`, in two places that
move together:

- a GitHub Actions repository variable on `squid-protocol/gitgalaxy` (planned name
  `CICS_CRUCIBLE_REF`), read by the CI job that runs the `cics_crucible` equivalence runner;
- a `PINNED_TAG` constant in gitgalaxy's runner (like `tests/_crucible_pin.py` for
  language-crucible), for local runs and human-facing messages.

Both, the runner, its baseline ratchet ledger and the CI job are **phase 2** of
[gitgalaxy#3989](https://github.com/squid-protocol/gitgalaxy/issues/3989). Until phase 2
lands, a tag here changes nothing downstream.

## The checklist, in order

1. **Batch, don't tag per PR.** A tag is a checkpoint. Let several case PRs land on `main`
   first, each green on `tools/validate.py`.
2. **In gitgalaxy**, with a local checkout of this repo's `main` at the commit you intend
   to tag, run the `cics_crucible` runner against it. Update its baseline ledger: new or
   changed cases usually add expected-failure cells (phase 3 closes them). Explain every
   cell that changed. A cell that newly *passes* is fine. A cell that newly *fails* on an
   unchanged case is a regression in gitgalaxy, not a reason to touch a log here (see
   `AGENTS.md` rule 3). Stop there, with the ledger reviewed but the pin not yet moved.
3. **Here**, cut the tag against exactly that commit, using three-part semver:
   ```bash
   git tag -a vX.Y.Z -m "..." <commit>
   git push origin vX.Y.Z
   gh release create vX.Y.Z --notes-file <notes>
   ```
   Release notes list the cases added or changed per trap, format changes (with the SPEC
   version), and any log corrections, each with its `NOTES.md` justification.
4. **Back in gitgalaxy**, bump the pin variable and `PINNED_TAG` together, grep for the old
   tag, push, and confirm CI passes before merging.

Steps 2 and 4 happen in a different repository. Treat them as one coordinated cross-repo
change (with a "Cross-repo" PR note), not something to do unilaterally from this side.

## Where things stand

| Tag | Date | Contents |
|---|---|---|
| — | — | Phase 1 (format `cics-crucible/1`, 10 cases, 37 scenarios) is on `main`, untagged. The first tag waits for gitgalaxy's phase-2 runner. |
