#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_root="${TARGET_ROOT:-$HOME/.claude}"
mkdir -p "$target_root/agents" "$target_root/skills"

for name in premise-overturner assumption-challenger test-designer metric-gate rollback-planner range-creep-guardian; do
  cp "$repo_root/agents/$name.md" "$target_root/agents/$name.md"
done

for name in three-review six-role-drill; do
  mkdir -p "$target_root/skills/$name"
  cp "$repo_root/skills/$name/SKILL.md" "$target_root/skills/$name/SKILL.md"
done

printf 'Installed 6 agents and 2 skills into %s\n' "$target_root"
