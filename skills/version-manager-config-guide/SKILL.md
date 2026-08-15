---
name: version-manager-config-guide
description: How to write a .appversion.yml file for version-manager — schema, examples, and common patterns for keeping version strings in sync across a project.
---

# version-manager Config Guide

`.appversion.yml` tells `version-manager` which files contain version strings, how to
extract/replace them, and what to do around a version bump.

## Minimal config

```yaml
version: "1.0.0"
files:
  - id: version-swift
    path: Sources/MyToolCLI/Version.swift
    pattern: 'static let current = "(\d+\.\d+\.\d+)"'
    occurrences: 1
```

Every `pattern` must contain **exactly one capture group** — only the captured text is
replaced, so surrounding context (`static let current = "..."`) acts as a guard against
accidental matches elsewhere in the file.

## Fields

- `version`: **the single source of truth**, a plain SemVer 2.0.0 string. `current` and
  `check` read this value directly — they never regex-extract a version from a file.
  `bump` rewrites this field itself (in place, preserving every other comment/field in
  the file) as part of the same replacement pass that updates every `files[]` rule.
- `strict`: (default `true`) rejects pre-release/build-metadata suffixes like
  `1.18.0-beta.1` in `version`. Set `false` to allow them.
- `files[].occurrences`: `all` (default, requires ≥1 match) or an integer requiring an
  exact match count. Use an integer whenever you know exactly how many times a version
  string should appear — it turns "someone deleted a line" into a hard error.
- `renames[]`: rename files whose *name* encodes the version (e.g. `Configs/1-17-2.xcconfig`).
  Each rule requires `id` (unique identifier), `directory` (folder to rename files in),
  and `format` (filename pattern with the `{version}` placeholder — this is mandatory).
  `transform` is optional: a shell one-liner reading `$APPVERSION_VALUE` and writing
  exactly one line to stdout. Without `transform`, the version is used verbatim. Example:

  ```yaml
  renames:
    - id: version-xcconfig
      directory: Configs
      format: "{version}.xcconfig"
      transform:
        run: "echo \"$APPVERSION_VALUE\" | tr '.' '-'"
  ```

- `hooks.pre` / `hooks.post`: arrays of named shell commands run before/after the bump.
  Each hook is an object with `name` (for logging) and `run` (the command). `pre` failures
  abort the whole bump before any file is touched; `post` failures are reported but do
  not roll back already-written changes (hooks may be non-idempotent external actions).
  Both receive `APPVERSION_OLD`, `APPVERSION_NEW`, `APPVERSION_CONFIG_DIR` as env vars.
  Example:

  ```yaml
  hooks:
    pre:
      - name: ensure-clean-worktree
        run: "git diff --quiet"
    post:
      - name: update-changelog
        run: "./scripts/insert-changelog-entry.sh"
  ```

version-manager is semver-only — there is no support for custom/non-semver version
schemes (e.g. bare integer build numbers).

## Common mistake: replacing a whole line instead of just the version

Bad: `pattern: 'MARKETING_VERSION = \d+\.\d+\.\d+;'` (no capture group — this is a config
error, version-manager will reject it). Good:
`pattern: 'MARKETING_VERSION = (\d+\.\d+\.\d+);'` — the parens around the digits are
what gets replaced.
