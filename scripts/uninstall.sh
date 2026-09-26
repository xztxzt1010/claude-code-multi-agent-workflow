#!/usr/bin/env bash
set -euo pipefail

target_root="${TARGET_ROOT:-$HOME/.claude}"

for name in premise-overturner assumption-challenger test-designer metric-gate rollback-planner range-creep-guardian; do
  rm -f "$target_root/agents/$name.md"
done

for name in three-review six-role-drill; do
  rm -rf "$target_root/skills/$name"
done

printf "Removed only this project's 6 agents and 2 skills from %s\n" "$target_root"
