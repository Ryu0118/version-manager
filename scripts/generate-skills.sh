#!/bin/sh
set -eu

OUT="Sources/VersionManagerKit/Generated/GeneratedSkills.swift"
mkdir -p "$(dirname "$OUT")"

{
  echo "package struct SkillAsset: Sendable, Equatable {"
  echo "    package let name: String"
  echo "    package let content: String"
  echo "}"
  echo ""
  echo "package enum GeneratedSkills {"
  echo "    package static let all: [SkillAsset] = ["
  for dir in skills/*/; do
    name=$(basename "$dir")
    content=$(cat "$dir/SKILL.md")
    printf '        SkillAsset(name: "%s", content: #"""\n%s\n"""#),\n' "$name" "$content"
  done
  echo "    ]"
  echo "}"
} > "$OUT"
