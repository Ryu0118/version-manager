# version-manager

## Commands

- Build: `swift build`
- Test: `swift test`
- Format: `make format`
- Lint: `make lint`
- Format + lint: `make format-lint`
- Full check (format + lint + test): `make check`
- Install dev tools (swiftformat/swiftlint/gitnagg/docsync via nest): `make install-commands`
- Regenerate embedded skill content: `make generate-skills`

## Architecture

3-layer SwiftPM package:
- `Sources/version-manager/` — executable entry point only.
- `Sources/VersionManagerCLI/` — ArgumentParser command definitions (`BumpCommand`,
  `CheckCommand`, `CurrentCommand`, `InitCommand`, `InstallSkillsCommand`) plus
  `GlobalOptions` (shared `--config`/`--verbose` via `@OptionGroup`). Commands that
  support machine-readable output (`bump`, `check`, `current`, `install-skills`)
  each carry their own `--json` flag.
- `Sources/VersionManagerKit/` — all logic, organized by pipeline stage:
  - `Config/` — `.appversion.yml` decoding (`ConfigLoader`) and static validation
    (`ConfigValidator` + per-section extensions for `files` and `renames`).
  - `Versioning/` — independent SemVer 2.0.0 implementation (`SemanticVersion`),
    format validation (`VersionFormatValidator`), and the `renames[].transform.run`
    shell-out helper (`VersionTransformer`).
  - `Planning/` — builds an in-memory `BumpPlan` (`BumpPlanner`) and validates it
    before any write (`PlanValidator`).
  - `Applying/` — writes the plan atomically with rollback (`PlanApplier`), renders
    it as a diff (`DiffRenderer`), and encodes it for `--json` output
    (`BumpPlanJSON`).
  - `Hooks/` — runs `hooks.pre`/`hooks.post` shell commands (`HookRunner`).
  - `Runners/` — one type per CLI subcommand (`BumpRunner`, `CheckRunner`,
    `CurrentRunner`, `InitRunner`, `InstallSkillsRunner`), orchestrating the above.
  - `Skills/` — installs version-manager's own Agent Skills (config authoring guide
    + CLI usage guide) into other projects, for Claude Code and/or Codex
    (`SkillAsset`, `SkillInstaller`).
  - `Generated/` — codegen output (`GeneratedSkills.swift`), gitignored, produced by
    `make generate-skills` from `skills/*/SKILL.md`.
  - `Internals/` — shared regex constants (`Regexes.swift`) and a mockable glob
    wrapper (`FileSystemAccess.swift`).

Core flow (`bump`): `ConfigLoader` → `ConfigValidator` → `BumpPlanner` (builds
`BumpPlan` entirely in memory, no writes; this is also where `renames[].transform.run`
executes) → `PlanValidator` (rejects zero-match rules, occurrence mismatches, no-op
bumps) → `HookRunner` (pre) → `PlanApplier` (atomic write + rollback on failure) →
`HookRunner` (post). `--dry-run` stops after `PlanValidator` and renders the plan
instead of applying it.

## Config schema (`.appversion.yml`)

- `version: String` — the single source of truth for the current version. Plain
  semver string (e.g. `"1.4.0"`), no wrapper object. There is no `source_of_truth`
  field — `bump`/`check`/`current` all read and compare against this field.
- `strict: Bool?` — top-level flag; see `DESIGN.md` for its exact effect on
  validation strictness.
- `files: [FileRule]` — each rule has `id`, `path`, `pattern`, and optional
  `occurrences` (`"all"` or an exact `Int`, default `.all`).
- `renames: [RenameRule]?` — each rule has `id`, `directory`, `format`, and an
  optional `transform.run` (a shell command that computes the target filename).
- `hooks: { pre: [Hook]?, post: [Hook]? }?` — each `Hook` has `name` and `run`.

`Config.swift` and `README.md`'s Commands section / `DESIGN.md`'s config schema
section are kept in sync by `docsync.yml` — see Gotchas below before editing either.

## Code Style

- Swift 6.2, default access level `package` inside Kit/CLI; `public` only on the
  `@main` command type.
- All file I/O goes through `FileManagerProtocol`; all subprocess execution goes
  through `ProcessRunning`. Never call `Foundation.FileManager`/`Process` directly
  inside `VersionManagerKit`.
- String identifiers (hook environment variable names, etc.) live in
  `enum ... : String` rawValue types (`HookEnvironmentKey`), never as scattered
  string literals.
- Regex literals are centralized in `Internals/Regexes.swift`.
- Errors are per-feature `enum XxxError: Error, LocalizedError`, every case carrying
  enough context (rule ID, path, etc.) to locate the failure without a stack trace.
- No comments on self-evident code. Doc comments only for genuinely non-obvious
  behavior (e.g. the capture-group-counting workaround in
  `ConfigValidator+FilesValidator.swift`, since Swift's `Regex` type doesn't expose
  group count via public API).

## Testing

swift-testing (`@Test`/`#expect`, struct test types), not XCTest. All Kit tests
inject a mock `FileManagerProtocol`/`ProcessRunning` — no test touches the real
filesystem or spawns a real shell except where explicitly noted (e.g. glob
expansion, if `tuist/FileSystem`'s `Glob` cannot be mocked — see
`FileSystemAccessTests.swift`).

## Gotchas

- `BumpPlanner`'s replacement loop iterates matches in **reverse order**
  (`.reversed()`) before calling `replaceSubrange` — this is required so that
  length-changing replacements (`1.9.0` → `1.10.0`, +1 character) don't invalidate
  the `Range<String.Index>` of not-yet-processed earlier matches. Do not "simplify"
  this to a forward loop.
- `renames[].transform.run` executes during **plan construction**, not during apply
  — it runs even under `--dry-run` and during `check`, because computing the
  target filename requires it. It must be a pure string transform with no side
  effects; side-effecting logic belongs in `hooks`, which only run around the
  actual write.
- `hooks.post` failures do **not** roll back already-written file changes — hooks
  may be non-idempotent external actions (e.g. a changelog script), so re-running
  a rolled-back bump could double-apply them. `hooks.pre` failures, by contrast,
  abort before any write happens.
- `docsync.yml` tracks `Config.swift` against `DESIGN.md`'s config schema section,
  and all 5 `VersionManagerCLI/*Command.swift` files against `README.md`'s Commands
  section, via SHA-256 checksums. Modifying any of those source files requires
  running `.nest/bin/docsync update-checksum` before committing, or the pre-commit
  hook blocks the commit. The hook triggers on **any** staged `.swift` file, not
  just docsync-tracked ones, so this is easy to hit unexpectedly — if a commit gets
  blocked on an unrelated `.swift` change, that's why.
