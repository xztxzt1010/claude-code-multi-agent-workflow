#!/usr/bin/env bash
set -euo pipefail

target_root="${TARGET_ROOT:-}"
if [[ -z "${target_root// }" ]]; then
  printf 'Uninstall refused: TARGET_ROOT is required (no default). Pass TARGET_ROOT explicitly.\n' >&2
  exit 1
fi

project_id="claude-code-multi-agent-workflow"
manifest_dir="$target_root/.claude-multi-agent-workflow"
manifest_path="$manifest_dir/manifest.tsv"

allowed_rels=(
  "agents/premise-overturner.md"
  "agents/assumption-challenger.md"
  "agents/test-designer.md"
  "agents/metric-gate.md"
  "agents/rollback-planner.md"
  "agents/range-creep-guardian.md"
  "skills/three-review/SKILL.md"
  "skills/six-role-drill/SKILL.md"
)

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print tolower($1)}'
  else
    shasum -a 256 "$1" | awk '{print tolower($1)}'
  fi
}

safe_rel() {
  local rel="$1"
  [[ -z "${rel// }" ]] && return 1
  [[ "$rel" == /* || "$rel" == \\* ]] && return 1
  [[ "$rel" =~ ^[A-Za-z]: ]] && return 1
  [[ "$rel" == *\\* ]] && return 1
  [[ "$rel" == *//* ]] && return 1
  local IFS='/'
  local segs
  read -ra segs <<< "$rel"
  for seg in "${segs[@]}"; do
    [[ -z "$seg" || "$seg" == "." || "$seg" == ".." ]] && return 1
  done
  return 0
}

resolve_under_root() {
  local root="$1" rel="$2"
  local root_full combined prefix
  root_full="$(cd "$root" 2>/dev/null && pwd)" || return 1
  local norm="" seg
  local IFS='/'
  local segs
  read -ra segs <<< "$rel"
  for seg in "${segs[@]}"; do
    if [[ -z "$seg" || "$seg" == "." ]]; then continue; fi
    if [[ "$seg" == ".." ]]; then return 1; fi
    if [[ -z "$norm" ]]; then norm="$seg"; else norm="$norm/$seg"; fi
  done
  [[ -z "$norm" ]] && return 1
  combined="$root_full/$norm"
  prefix="${root_full%/}/"
  case "$combined" in
    "$prefix"*) printf '%s' "$combined"; return 0 ;;
    *) return 1 ;;
  esac
}

is_allowed() {
  local rel="$1" a
  for a in "${allowed_rels[@]}"; do
    [[ "$a" == "$rel" ]] && return 0
  done
  return 1
}

if [[ ! -f "$manifest_path" ]]; then
  printf 'Uninstall refused: ownership manifest not found at %s (will not guess ownership by filename)\n' "$manifest_path" >&2
  exit 1
fi

# ---- Full manifest validation before any delete ----
declare -A hashes=()
declare -A seen=()
line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  [[ -z "${line// }" ]] && continue
  [[ "$line" == \#* ]] && continue
  IFS=$'\t' read -r proj rel hash <<< "$line"
  field_count=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
  if [[ "$field_count" -ne 3 || -z "${proj:-}" || -z "${rel:-}" || -z "${hash:-}" ]]; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d malformed\n' "$line_no" >&2
    exit 1
  fi
  if [[ "$proj" != "$project_id" ]]; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d unexpected project id\n' "$line_no" >&2
    exit 1
  fi
  if ! safe_rel "$rel"; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d unsafe path %s\n' "$line_no" "$rel" >&2
    exit 1
  fi
  if ! is_allowed "$rel"; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d path not in allow-list %s\n' "$line_no" "$rel" >&2
    exit 1
  fi
  if [[ -n "${seen[$rel]:-}" ]]; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d duplicate path %s\n' "$line_no" "$rel" >&2
    exit 1
  fi
  hash_lc="$(printf '%s' "$hash" | tr '[:upper:]' '[:lower:]')"
  if [[ ! "$hash_lc" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d invalid sha256\n' "$line_no" >&2
    exit 1
  fi
  if ! resolve_under_root "$target_root" "$rel" >/dev/null; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — line %d path escapes TargetRoot %s\n' "$line_no" "$rel" >&2
    exit 1
  fi
  seen["$rel"]=1
  hashes["$rel"]="$hash_lc"
done < "$manifest_path"

for rel in "${allowed_rels[@]}"; do
  if [[ -z "${hashes[$rel]:-}" ]]; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — missing required path %s\n' "$rel" >&2
    exit 1
  fi
done
for rel in "${!hashes[@]}"; do
  if ! is_allowed "$rel"; then
    printf 'Uninstall aborted with zero deletes: invalid manifest — extra path %s\n' "$rel" >&2
    exit 1
  fi
done

# ---- Verify ALL paths and hashes before deleting anything ----
failures=()
for rel in "${allowed_rels[@]}"; do
  dest="$(resolve_under_root "$target_root" "$rel")" || { failures+=("path escapes TargetRoot: $rel"); continue; }
  if [[ ! -f "$dest" ]]; then
    failures+=("missing installed file: $rel")
    continue
  fi
  cur="$(sha256_file "$dest")"
  if [[ "$cur" != "${hashes[$rel]}" ]]; then
    failures+=("installed file modified by user: $rel")
    continue
  fi
done

if [[ ${#failures[@]} -gt 0 ]]; then
  printf 'Uninstall aborted with zero deletes:\n' >&2
  for f in "${failures[@]}"; do printf -- '- %s\n' "$f" >&2; done
  exit 1
fi

# ---- Delete only after full validation and hash verification ----
for rel in "${allowed_rels[@]}"; do
  dest="$(resolve_under_root "$target_root" "$rel")"
  rm -f "$dest"
done

for rel_dir in "skills/three-review" "skills/six-role-drill" "skills" "agents"; do
  dir="$target_root/$rel_dir"
  if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    rmdir "$dir"
  fi
done

rm -f "$manifest_path"
if [[ -d "$manifest_dir" ]] && [[ -z "$(ls -A "$manifest_dir" 2>/dev/null)" ]]; then
  rmdir "$manifest_dir"
fi

count=${#hashes[@]}
printf 'Uninstalled %d owned files from %s (manifest removed)\n' "$count" "$target_root"
