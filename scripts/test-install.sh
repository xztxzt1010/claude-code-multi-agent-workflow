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
  mktemp -d "${TMPDIR:-/tmp}/mimo-inst-XXXXXXXX"
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
run_install_no_root() { env -u TARGET_ROOT bash "$install" >/dev/null 2>&1; echo $?; }
run_uninstall_no_root() { env -u TARGET_ROOT bash "$uninstall" >/dev/null 2>&1; echo $?; }

write_manifest() {
  local root="$1"; shift
  mkdir -p "$root/.claude-multi-agent-workflow"
  {
    printf '# claude-code-multi-agent-workflow manifest v1\n'
    printf '# project\trelpath\tsha256\n'
    for line in "$@"; do printf '%s\n' "$line"; done
  } > "$root/.claude-multi-agent-workflow/manifest.tsv"
}

base_rels=(
  "agents/premise-overturner.md"
  "agents/assumption-challenger.md"
  "agents/test-designer.md"
  "agents/metric-gate.md"
  "agents/rollback-planner.md"
  "agents/range-creep-guardian.md"
  "skills/three-review/SKILL.md"
  "skills/six-role-drill/SKILL.md"
)

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

# Case 7: missing TARGET_ROOT -> refuse, zero writes
root="$(new_temp_root)"
code="$(run_install_no_root)"
assert "[[ $code -ne 0 ]]" "case7 install without TARGET_ROOT fails (got $code)"
code="$(run_uninstall_no_root)"
assert "[[ $code -ne 0 ]]" "case7 uninstall without TARGET_ROOT fails (got $code)"
remove_temp_safe "$root"

# Case 8: ../ manifest escape -> refuse, sentinel unchanged
root="$(new_temp_root)"
run_install "$root" >/dev/null
sentinel="$(mktemp "${TMPDIR:-/tmp}/mimo-sentinel-XXXXXXXX.txt")"
printf 'SENTINEL-KEEP\n' > "$sentinel"
sentinel_leaf="$(basename "$sentinel")"
lines=()
for rel in "${base_rels[@]:0:7}"; do
  lines+=("claude-code-multi-agent-workflow	$rel	$(printf 'a%.0s' {1..64})")
done
lines+=("claude-code-multi-agent-workflow	../$sentinel_leaf	$(printf 'b%.0s' {1..64})")
write_manifest "$root" "${lines[@]}"
code="$(run_uninstall "$root")"
assert "[[ $code -ne 0 ]]" "case8 ../ manifest uninstall fails (got $code)"
assert "[[ \$(cat \"$sentinel\") == 'SENTINEL-KEEP' ]]" "case8 sentinel outside root unchanged"
assert "[[ -f \"$root/agents/premise-overturner.md\" ]]" "case8 project files not deleted"
rm -f "$sentinel"
remove_temp_safe "$root"

# Case 9: absolute path in manifest -> refuse
root="$(new_temp_root)"
run_install "$root" >/dev/null
lines=()
for rel in "${base_rels[@]}"; do
  if [[ "$rel" == "skills/six-role-drill/SKILL.md" ]]; then
    lines+=("claude-code-multi-agent-workflow	/etc/passwd	$(printf 'c%.0s' {1..64})")
  else
    lines+=("claude-code-multi-agent-workflow	$rel	$(printf 'c%.0s' {1..64})")
  fi
done
write_manifest "$root" "${lines[@]}"
code="$(run_uninstall "$root")"
assert "[[ $code -ne 0 ]]" "case9 absolute-path manifest fails (got $code)"
assert "[[ -f \"$root/agents/premise-overturner.md\" ]]" "case9 zero deletes"
remove_temp_safe "$root"

# Case 10: extra / missing / duplicate / malformed
for kind in extra missing duplicate malformed; do
  root="$(new_temp_root)"
  run_install "$root" >/dev/null
  lines=()
  case "$kind" in
    extra)
      for rel in "${base_rels[@]}"; do lines+=("claude-code-multi-agent-workflow	$rel	$(printf 'd%.0s' {1..64})"); done
      lines+=("claude-code-multi-agent-workflow	agents/evil.md	$(printf 'd%.0s' {1..64})")
      ;;
    missing)
      for rel in "${base_rels[@]:0:7}"; do lines+=("claude-code-multi-agent-workflow	$rel	$(printf 'd%.0s' {1..64})"); done
      ;;
    duplicate)
      for rel in "${base_rels[@]}"; do lines+=("claude-code-multi-agent-workflow	$rel	$(printf 'd%.0s' {1..64})"); done
      lines+=("claude-code-multi-agent-workflow	agents/premise-overturner.md	$(printf 'd%.0s' {1..64})")
      ;;
    malformed)
      for rel in "${base_rels[@]}"; do lines+=("claude-code-multi-agent-workflow	$rel"); done
      ;;
  esac
  write_manifest "$root" "${lines[@]}"
  code="$(run_uninstall "$root")"
  assert "[[ $code -ne 0 ]]" "case10 $kind manifest fails (got $code)"
  assert "[[ -f \"$root/agents/premise-overturner.md\" ]]" "case10 $kind zero deletes"
  remove_temp_safe "$root"
done

echo "=== result: $pass_count passed, $fail_count failed ==="
[[ $fail_count -gt 0 ]] && exit 1
exit 0
