#!/usr/bin/env bash
set -euo pipefail

# Usage: TARGET_ROOT=/path bash install.sh   (TargetRoot is required in tests; default only for interactive use)
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_root="${TARGET_ROOT:-}"
if [[ -z "$target_root" ]]; then
  target_root="${HOME}/.claude"
fi
project_id="claude-code-multi-agent-workflow"
manifest_dir="$target_root/.claude-multi-agent-workflow"
manifest_path="$manifest_dir/manifest.tsv"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print tolower($1)}'
  else
    shasum -a 256 "$1" | awk '{print tolower($1)}'
  fi
}

rels=(
  "agents/premise-overturner.md"
  "agents/assumption-challenger.md"
  "agents/test-designer.md"
  "agents/metric-gate.md"
  "agents/rollback-planner.md"
  "agents/range-creep-guardian.md"
  "skills/three-review/SKILL.md"
  "skills/six-role-drill/SKILL.md"
)

# ---- Preflight all 8 targets before any write ----
declare -a modes=()
failures=()
owned_file="$manifest_path"
declare -A owned=()
if [[ -f "$owned_file" ]]; then
  while IFS=$'\t' read -r proj rel hash _; do
    [[ -z "${proj:-}" || "$proj" == \#* ]] && continue
    [[ "$proj" != "$project_id" ]] && continue
    owned["$rel"]="$(printf '%s' "$hash" | tr '[:upper:]' '[:lower:]')"
  done < "$owned_file"
  has_manifest=1
else
  has_manifest=0
fi

for rel in "${rels[@]}"; do
  src="$repo_root/$rel"
  dest="$target_root/$rel"
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
  if [[ "$has_manifest" -eq 0 || -z "${owned[$rel]:-}" ]]; then
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
for rel in "${rels[@]}"; do
  src="$repo_root/$rel"
  dest="$target_root/$rel"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
done

mkdir -p "$manifest_dir"
tmp="$manifest_path.tmp"
{
  printf '# claude-code-multi-agent-workflow manifest v1\n'
  printf '# project\trelpath\tsha256\n'
  for rel in "${rels[@]}"; do
    hash="$(sha256_file "$target_root/$rel")"
    printf '%s\t%s\t%s\n' "$project_id" "$rel" "$hash"
  done
} > "$tmp"
mv -f "$tmp" "$manifest_path"

printf 'Installed %d files into %s (manifest published)\n' "${#rels[@]}" "$target_root"
