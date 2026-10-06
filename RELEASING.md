# Releasing / tagging this repo

Tags are cut deliberately and coordinated with gitgalaxy: a tag must never happen by accident, and
it must never silently change what gitgalaxy's CI tests against. See "Where things stand" for what exists.

## How the pin works

This mirrors [language-crucible's `RELEASING.md`](https://github.com/squid-protocol/language-crucible/blob/main/RELEASING.md),
except that there is no GitHub Actions repository variable. gitgalaxy clones this repo **at a
release tag**, never at `main`, and the ref lives in one place: the `PINNED_REF` constant in
`tests/_cics_crucible_pin.py` in gitgalaxy. Its CI workflows read it straight out of that file
(so it also works on pull requests from forks), and local runs and human-facing messages use
the same constant. Moving the pin is its own gitgalaxy PR that re-baselines the
`cics_crucible` runner (phase 2 of
[gitgalaxy#3989](https://github.com/squid-protocol/gitgalaxy/issues/3989)).

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
4. **Back in gitgalaxy**, bump `PINNED_REF` in `tests/_cics_crucible_pin.py` and re-baseline, grep for the old
   tag, push, and confirm CI passes before merging.

Steps 2 and 4 happen in a different repository. Treat them as one coordinated cross-repo
change (with a "Cross-repo" PR note), not something to do unilaterally from this side.

## Where things stand

| Tag | Date | Contents |
|---|---|---|
| `v0.1.0` | 2026-09-29 | First release: format `cics-crucible/1`, 10 cases, 37 scenarios over 5 traps (condition handling, hex attributes, COMMAREA mismatch, ghost tasks, pseudo-conversational). Pinned by gitgalaxy#3989. |
| `v0.2.0` | 2026-09-30 | Format unchanged. 10 cases, 44 scenarios: seven scenarios close the COBOL coverage gaps gitgalaxy's tracer found (gitgalaxy#4023). No log corrected. |
| `v0.3.0` | 2026-10-06 | Format unchanged (additive SPEC additions: LUTYPE2 terminal, `SEND-CONTROL` options). 15 cases, 74 scenarios. Adds `hc-terminal-receive`, `hc-terminal-eoc`, `hc-handle-aid`, `hc-ignore-error` and `hc-eoc-error` (all condition-handling) for gitgalaxy#4413, #4414 and #4502. No log corrected. gitgalaxy pinned it from PR #4553. |
| `v0.4.0` | 2026-10-06 | Format unchanged. 16 cases, 76 scenarios. Adds `ca-channel-containers` (commarea-mismatch: PUT / GET / DELETE CONTAINER, LINK / XCTL CHANNEL, the current channel, CONTAINERERR / CHANNELERR / LENGERR / INVREQ) for gitgalaxy#4270. No log corrected. |
| `v0.5.0` | 2026-10-06 | Format unchanged (additive SPEC: START / RETRIEVE data options, AFTER / AT, `RUN` event and trigger, default user `CICSUSER`). 18 cases, 86 scenarios. Adds `gt-start-options` and `gt-assign-startcode` (ghost-tasks) for gitgalaxy#4270. No log corrected. |

The latest tag is `v0.5.0`; `main` may carry unreleased commits beyond it. Full notes for each tag are on its
[GitHub release](https://github.com/squid-protocol/cics-crucible/releases).
