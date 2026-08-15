# version-manager - A CLI tool to bump version strings across your entire project in one command.

[![Language](https://img.shields.io/badge/Language-Swift-F05138?style=flat-square)](https://www.swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey?style=flat-square)](https://github.com/Ryu0118/version-manager/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-007ec6?style=flat-square)](LICENSE)
[![release](https://img.shields.io/github/v/release/Ryu0118/version-manager?style=flat-square)](https://github.com/Ryu0118/version-manager/releases/latest)
[![Follow @ryu_hu03](https://img.shields.io/badge/Follow-%40ryu__hu03-ffffff?style=flat-square&logo=x&logoColor=000000&labelColor=ffffff&color=ffffff)](https://x.com/ryu_hu03)

✨ **Stop hunting for every place a version number hides. Point `version-manager` at your project once, then bump every occurrence — Xcode project, Info.plist, Package.swift, fastlane config, README badges, CHANGELOG — with a single command and a safety net that refuses to run when something looks off.**

## Why

Every non-trivial project ends up with its version number scattered across files that
never agree with each other for long: `MARKETING_VERSION` in `project.pbxproj`, a
badge in `README.md`, a constant in `Version.swift`, a `Deliverfile` for fastlane. A
manual bump means opening five files and hoping you didn't miss one. `version-manager`
turns that into a single declarative config and one command.

## Features

- 🎯 **One config, every file.** Describe each version location once in `.appversion.yml`
  with a regex + capture group — the tool finds and replaces only the version part,
  never touching the surrounding text.
- 🔍 **Plan-then-apply, always.** Every `bump` builds the full change set in memory,
  validates it, and shows you a diff before writing anything. `--dry-run` stops right
  there.
- 🚨 **Refuses to run silently wrong.** Zero matches, a mismatched occurrence count, or
  rules that disagree on the current version — all hard errors by default. No more
  "the bump ran but only touched 2 of 3 files."
- 🔤 **File renaming, not just content.** Version-encoded filenames
  (`Configs/1-17-2.xcconfig`) get renamed via a small shell transform you control.
- 🪝 **Pre/post hooks.** Run a script before the bump (e.g. require a clean worktree) or
  after (e.g. insert a CHANGELOG entry), with the old/new version passed in as
  environment variables.
- 🤖 **Agent-friendly by design.** `--json` on every command, no interactive prompts,
  predictable non-zero exit codes — built to be driven by CI or an AI coding agent as
  comfortably as by a human.
- 📐 **Independent SemVer 2.0.0 implementation.** No dependency black box — parsing and
  precedence comparison are implemented and tested directly against the spec.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Ryu0118/version-manager/main/install.sh | bash
```

To update, run the same command. It skips the download if already up-to-date.

```bash
# Install a specific version
curl -fsSL https://raw.githubusercontent.com/Ryu0118/version-manager/main/install.sh | VERSION=0.1.0 bash

# Force reinstall
curl -fsSL https://raw.githubusercontent.com/Ryu0118/version-manager/main/install.sh | FORCE=1 bash
```

### Other methods

#### Nest ([mtj0928/nest](https://github.com/mtj0928/nest))

```bash
nest install Ryu0118/version-manager
```

#### Mise ([jdx/mise](https://github.com/jdx/mise))

```bash
mise use -g github:Ryu0118/version-manager
```

#### Build from source

Requires Swift 6.2+ and macOS 15+.

```bash
git clone https://github.com/Ryu0118/version-manager.git
cd version-manager
swift run version-manager <subcommand>
```

## Quick start

```bash
# 1. Scaffold a config
version-manager init

# 2. Edit .appversion.yml to point at your version-carrying files (see below)

# 3. Preview a bump — nothing is written yet
version-manager bump --dry-run 1.18.0

# 4. Apply it for real
version-manager bump 1.18.0

# 5. Verify everything stayed in sync (great as a CI gate on release PRs)
version-manager check
```

## Configuration

`.appversion.yml` lives at your project root. The minimum viable config is a `version`
string (the single source of truth — `current` and `check` read it directly, they never
regex-extract a version from a file) and one `files` rule:

```yaml
version: "1.0.0"

files:
  - id: version-swift
    path: Sources/MyToolCLI/Version.swift
    pattern: 'static let current = "(\d+\.\d+\.\d+)"'
    occurrences: 1
```

Every `pattern` must contain **exactly one capture group** — only the captured text is
replaced, so the surrounding text (`static let current = "..."`) acts as a guard
against accidental matches. `occurrences` defaults to `all` (at least one match
required); set an exact integer when you know precisely how many times a version
should appear — a mismatch means something drifted.

A more complete example, covering an Xcode project with multiple targets, a fastlane
deliverfile, a README badge, a version-encoded config filename, and pre/post hooks:

```yaml
version: "1.17.2"

files:
  - id: xcodeproj
    path: "App/*.xcodeproj/project.pbxproj"
    pattern: 'MARKETING_VERSION = (\d+\.\d+\.\d+);'
    occurrences: all          # Debug/Release × iOS/watchOS/Widget all match

  - id: fastlane-deliverfile
    path: fastlane/Deliverfile
    pattern: 'app_version\("(\d+\.\d+\.\d+)"\)'
    occurrences: 1

  - id: readme-badge
    path: README.md
    pattern: 'img\.shields\.io/badge/version-(\d+\.\d+\.\d+)-blue'
    occurrences: 1

renames:
  - id: version-xcconfig
    directory: App/Configs
    format: "Version-{version}.xcconfig"
    transform:
      run: "echo \"$APPVERSION_VALUE\" | tr '.' '-'"   # Version-1-17-2.xcconfig -> Version-1-18-0.xcconfig

hooks:
  pre:
    - name: clean-worktree
      run: "git diff --quiet"
  post:
    - name: insert-changelog-entry
      run: "./scripts/insert-changelog-entry.sh"
```

`strict` (default `true`) rejects pre-release/build-metadata suffixes like
`1.18.0-beta.1` in `version` — set it to `false` at the top level to allow them.
version-manager is semver-only; there is no support for non-semver version schemes.

Full schema reference: `version-manager install-skills` installs a
`version-manager-config-guide` Agent Skill with the complete field-by-field
documentation, or read [`skills/version-manager-config-guide/SKILL.md`](skills/version-manager-config-guide/SKILL.md)
directly.

## Commands

```bash
version-manager bump <version> [--dry-run] [--json] [--skip-hooks] [--force] [--config <path>] [--verbose]
version-manager check [--json] [--config <path>] [--verbose]
version-manager current [--json] [--config <path>] [--verbose]
version-manager init [--force] [--config <path>] [--verbose]
version-manager install-skills [--agent claude-code|codex|both] [--dir <path>] [--force] [--json]
```

| Command | What it does |
|---|---|
| `bump <version>` | Plan, validate, then apply a version bump across every configured file, rename, and hook. |
| `check` | Verify the current repo state is internally consistent — every rule matches, every extracted version agrees with the config's `version` field. Non-zero exit on drift. Ideal as a CI gate before merging a release PR. |
| `current` | Print the current version, read directly from the config's `version` field. |
| `init` | Write a commented `.appversion.yml` template to get started. |
| `install-skills` | Install version-manager's own Agent Skills (config authoring guide + CLI usage guide) into a target project, for Claude Code and/or Codex. |

`--config <path>` selects a config file other than `.appversion.yml` (default);
`--verbose` turns on detailed logging. Both are available on every subcommand except
`install-skills`.

`--dry-run` builds and validates the full change set — every regex match, every
occurrence count, every rename — without writing anything, then prints the diff.
Nothing about `bump`'s validation is skipped in dry-run mode; only the write and any
hooks are.

## Design principles

- **Never a silent no-op.** A rule that matches zero times, or an occurrence count that
  doesn't add up, is a hard error — not a warning buried in output you might not read.
- **Plan-then-apply.** The entire change set — every file replacement, every rename,
  every hook — is computed and validated in memory before a single byte is written to
  disk.
- **Atomic, best-effort-recoverable writes.** Files are written via a temp-file-then-
  rename sequence; if a write fails partway through a multi-file bump, already-applied
  changes are rolled back on a best-effort basis, with `git checkout -- <files>` always
  available as the ultimate fallback.
- **Hooks are honest about their limits.** A `pre` hook failure aborts before anything
  is written. A `post` hook failure is reported but does **not** roll back file
  changes — hooks may run non-idempotent external actions (like appending to a
  CHANGELOG) that shouldn't be undone just because a *later* hook failed.

## License

MIT
