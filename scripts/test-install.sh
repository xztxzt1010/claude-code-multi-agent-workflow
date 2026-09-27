#!/usr/bin/env bash
# Isolation tests for install.sh / uninstall.sh
# NEVER touches real ~/.claude — every case uses a unique temp TARGET_ROOT.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install="$repo_root/scripts/install.sh"
uninstall="$repo_root/scripts/uninstall.sh"
fail_count=0
pass_count=0

pass() { printf '  PASS  %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; fail_count=$((fail_count + 1)); }
assert() {
  local cond="$1" msg="$2"
  if eval "$cond"; then pass "$msg"; else fail "$msg"; fi
}

new_temp_root() {
  local p
  p="$(mktemp -d "${TMPDIR:-/tmp}/mimo-inst-XXXXXXXX")"
  printf '%s' "$p"
}

remove_temp_safe() {
  local dir="$1" resolved temp_root
  resolved="$(cd "$dir" && pwd)"
  temp_root="$(cd "${TMPDIR:-/tmp}" && pwd)"
  case "$resolved" in
    "$temp_root") echo "refusing to delete temp root" >&2; exit 1 ;;
    "$temp_root"/*) rm -rf "$resolved" ;;
    *) echo "refusing to delete outside temp: $resolved" >&2; exit 1 ;;
  esac
}

run_install() { TARGET_ROOT="$1" bash "$install" >/dev/null 2>&1; echo $?; }
run_uninstall() { TARGET_ROOT="$1" bash "$uninstall" >/dev/null 2>&1; echo $?; }

echo "=== Bash isolation tests ==="

# Case 1: empty target first install
root="$(new_temp_root)"
code="$(run_install "$root")"
assert "[[ $code -eq 0 ]]" "case1 install exit 0 (got $code)"
assert "[[ \$(ls \"$root/agents\"/*.md 2>/dev/null | wc -l) -eq 6 ]]" "case1 6 agents"
assert "[[ -f \"$root/skills/three-review/SKILL.md\" && -f \"$root/skills/six-role-drill/SKILL.md\" ]]" "case1 2 skills"
assert "[[ -f \"$root/.claude-multi-agent-workflow/manifest.tsv\" ]]" "case1 manifest exists"
remove_temp_safe "$root"

# Case 2: idempotent reinstall
root="$(new_temp_root)"
run_install "$root" >/dev/null
code="$(run_install "$root")"
assert "[[ $code -eq 0 ]]" "case2 idempotent reinstall exit 0 (got $code)"
remove_temp_safe "$root"

# Case 3: conflict without ownership
root="$(new_temp_root)"
mkdir -p "$root/agents"
printf 'USER FILE NOT OURS\n' > "$root/agents/premise-overturner.md"
code="$(run_install "$root")"
assert "[[ $code -ne 0 ]]" "case3 conflict install fails (got $code)"
assert "[[ \$(cat \"$root/agents/premise-overturner.md\") == 'USER FILE NOT OURS' ]]" "case3 conflict file untouched"
assert "[[ ! -f \"$root/agents/assumption-challenger.md\" ]]" "case3 zero partial writes"
assert "[[ ! -f \"$root/.claude-multi-agent-workflow/manifest.tsv\" ]]" "case3 no manifest"
remove_temp_safe "$root"

# Case 4: unrelated files preserved
root="$(new_temp_root)"
mkdir -p "$root/agents" "$root/skills/my-skill"
printf 'keep me\n' > "$root/agents/my-personal-agent.md"
printf 'keep skill note\n' > "$root/skills/my-skill/notes.txt"
run_install "$root" >/dev/null
assert "[[ -f \"$root/agents/my-personal-agent.md\" ]]" "case4 unrelated agent kept after install"
run_uninstall "$root" >/dev/null
assert "[[ -f \"$root/agents/my-personal-agent.md\" ]]" "case4 unrelated agent kept after uninstall"
assert "[[ -f \"$root/skills/my-skill/notes.txt\" ]]" "case4 unrelated skill file kept after uninstall"
remove_temp_safe "$root"

# Case 5: modified installed file -> uninstall fails, zero deletes
root="$(new_temp_root)"
run_install "$root" >/dev/null
printf '\nuser edit\n' >> "$root/agents/test-designer.md"
code="$(run_uninstall "$root")"
assert "[[ $code -ne 0 ]]" "case5 modified uninstall fails (got $code)"
assert "[[ -f \"$root/agents/premise-overturner.md\" ]]" "case5 other project files not deleted"
assert "[[ -f \"$root/.claude-multi-agent-workflow/manifest.tsv\" ]]" "case5 manifest still present"
remove_temp_safe "$root"

# Case 6: clean uninstall
root="$(new_temp_root)"
printf '{}\n' > "$root/settings.local.json"
run_install "$root" >/dev/null
code="$(run_uninstall "$root")"
assert "[[ $code -eq 0 ]]" "case6 clean uninstall exit 0 (got $code)"
assert "[[ ! -f \"$root/agents/premise-overturner.md\" ]]" "case6 agent removed"
assert "[[ ! -f \"$root/skills/three-review/SKILL.md\" ]]" "case6 skill removed"
assert "[[ ! -f \"$root/.claude-multi-agent-workflow/manifest.tsv\" ]]" "case6 manifest removed"
assert "[[ -f \"$root/settings.local.json\" ]]" "case6 unrelated file kept"
remove_temp_safe "$root"

# Extra: uninstall without manifest refuses
root="$(new_temp_root)"
code="$(run_uninstall "$root")"
assert "[[ $code -ne 0 ]]" "no-manifest uninstall refuses (got $code)"
remove_temp_safe "$root"

echo "=== result: $pass_count passed, $fail_count failed ==="
[[ $fail_count -gt 0 ]] && exit 1
exit 0
