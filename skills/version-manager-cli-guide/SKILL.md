---
name: version-manager-cli-guide
description: How to run version-manager from an agent or CI — command reference, --json contract, and safe automation patterns.
---

# version-manager CLI Guide

`version-manager` bumps every version string in a project from one `.appversion.yml`.
It is safe to run non-interactively: no prompts, `--json` on every command, non-zero
exit on any failure.

## Commands

- `version-manager bump <version> [--dry-run] [--json] [--skip-hooks] [--force]` —
  the main operation. Always plan-then-apply: nothing is written until every rule in
  the config has been checked (regex matches, occurrence counts, no accidental no-op).
  Run with `--dry-run --json` first to inspect the plan before committing to it.
- `version-manager check [--json]` — verifies the current repo state is internally
  consistent (every rule matches, all matched versions agree). Exits non-zero on any
  inconsistency. Good as a CI gate on release PRs.
- `version-manager current [--json]` — prints `.appversion.yml`'s `version` field
  verbatim (the single source of truth).
- `version-manager init [--force]` — writes a commented `.appversion.yml` template.

## Agent-safe usage

1. Never call `bump` without `--dry-run` first when acting on a version you didn't
   choose yourself (e.g. one derived from user input) — inspect the diff, confirm the
   old→new transition looks right, then re-run without `--dry-run`.
2. Prefer `--json` for both `--dry-run` inspection and the final result — it is
   structured and stable across versions; the human-readable diff output is not a
   parseable contract.
3. A non-zero exit code from any command means nothing was written (for `bump`) or the
   repo is inconsistent (for `check`) — never retry with `--force` automatically; surface
   the failure and let a human decide, since `--force` bypasses the
   cross-rule-version-mismatch guard that exists specifically to catch drift.
4. `check` in CI should run on every release PR before `bump` runs — catching a stale
   rule (zero matches) before a bump makes it worse.
