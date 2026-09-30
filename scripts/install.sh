#!/usr/bin/env bash
set -euo pipefail

# Both PowerShell and Bash require an explicit target root. No default to ~/.claude.
target_root="${TARGET_ROOT:-}"
if [[ -z "${target_root// }" ]]; then
  printf 'Install refused: TARGET_ROOT is required (no default). Pass TARGET_ROOT explicitly.\n' >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# Return 0 if relative path is safe (no abs, no drive, no ., .., empty segments)
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

# Resolve path under root; print absolute path or return 1 if escape.
# Does not require intermediate directories to exist.
resolve_under_root() {
  local root="$1" rel="$2"
  local root_full combined prefix
  root_full="$(cd "$root" 2>/dev/null && pwd)" || return 1
  # Normalize rel: collapse . and .. safely while rejecting escapes
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

# ---- Validate existing manifest before any write ----
declare -A owned=()
has_manifest=0
if [[ -f "$manifest_path" ]]; then
  has_manifest=1
  declare -A seen=()
  line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    [[ -z "${line// }" ]] && continue
    [[ "$line" == \#* ]] && continue
    IFS=$'\t' read -r proj rel hash <<< "$line"
    if [[ -z "${proj:-}" || -z "${rel:-}" || -z "${hash:-}" ]]; then
      printf 'Install aborted before any write: invalid manifest — line %d malformed\n' "$line_no" >&2
      exit 1
    fi
    # reject extra fields
    local_extra=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
    if [[ "$local_extra" -ne 3 ]]; then
      printf 'Install aborted before any write: invalid manifest — line %d malformed (need 3 fields)\n' "$line_no" >&2
      exit 1
    fi
    if [[ "$proj" != "$project_id" ]]; then
      printf 'Install aborted before any write: invalid manifest — line %d unexpected project id\n' "$line_no" >&2
      exit 1
    fi
    if ! safe_rel "$rel"; then
      printf 'Install aborted before any write: invalid manifest — line %d unsafe path %s\n' "$line_no" "$rel" >&2
      exit 1
    fi
    if ! is_allowed "$rel"; then
      printf 'Install aborted before any write: invalid manifest — line %d path not in allow-list %s\n' "$line_no" "$rel" >&2
      exit 1
    fi
    if [[ -n "${seen[$rel]:-}" ]]; then
      printf 'Install aborted before any write: invalid manifest — line %d duplicate path %s\n' "$line_no" "$rel" >&2
      exit 1
    fi
    if [[ ! "$hash" =~ ^[0-9a-f]{64}$ ]]; then
      printf 'Install aborted before any write: invalid manifest — line %d invalid sha256\n' "$line_no" >&2
      exit 1
    fi
    if ! resolved="$(resolve_under_root "$target_root" "$rel")"; then
      printf 'Install aborted before any write: invalid manifest — line %d path escapes TargetRoot %s\n' "$line_no" "$rel" >&2
      exit 1
    fi
    seen["$rel"]=1
    owned["$rel"]="$hash"
  done < "$manifest_path"
  for rel in "${allowed_rels[@]}"; do
    if [[ -z "${owned[$rel]:-}" ]]; then
      printf 'Install aborted before any write: invalid manifest — missing required path %s\n' "$rel" >&2
      exit 1
    fi
  done
  for rel in "${!owned[@]}"; do
    if ! is_allowed "$rel"; then
      printf 'Install aborted before any write: invalid manifest — extra path %s\n' "$rel" >&2
      exit 1
    fi
  done
fi

# ---- Preflight all 8 targets ----
declare -a modes=()
failures=()
for rel in "${allowed_rels[@]}"; do
  src="$repo_root/$rel"
  if ! dest="$(resolve_under_root "$target_root" "$rel")"; then
    failures+=("path escapes TargetRoot: $rel")
    continue
  fi
  if [[ ! -f "$src" ]]; then
    failures+=("missing source: $rel")
    continue
  fi
  if [[ ! -e "$dest" ]]; then
    modes+=("install")
    continue
  fi
  if [[ ! -f "$dest" ]]; then
    failures+=("conflict without ownership proof (not a file): $rel")
    continue
  fi
  if [[ "$has_manifest" -eq 0 ]]; then
    failures+=("conflict without ownership proof: $rel")
    continue
  fi
  cur="$(sha256_file "$dest")"
  if [[ "$cur" != "${owned[$rel]}" ]]; then
    failures+=("installed file modified by user: $rel")
    continue
  fi
  modes+=("upgrade")
done

if [[ ${#failures[@]} -gt 0 ]]; then
  printf 'Install aborted before any write:\n' >&2
  for f in "${failures[@]}"; do printf -- '- %s\n' "$f" >&2; done
  exit 1
fi

# ---- Write only after full preflight pass ----
for rel in "${allowed_rels[@]}"; do
  src="$repo_root/$rel"
  dest="$(resolve_under_root "$target_root" "$rel")"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
done

mkdir -p "$manifest_dir"
tmp="$manifest_path.tmp"
{
  printf '# claude-code-multi-agent-workflow manifest v1\n'
  printf '# project\trelpath\tsha256\n'
  for rel in "${allowed_rels[@]}"; do
    dest="$(resolve_under_root "$target_root" "$rel")"
    hash="$(sha256_file "$dest")"
    printf '%s\t%s\t%s\n' "$project_id" "$rel" "$hash"
  done
} > "$tmp"
mv -f "$tmp" "$manifest_path"

printf 'Installed %d files into %s (manifest published)\n' "${#allowed_rels[@]}" "$target_root"
