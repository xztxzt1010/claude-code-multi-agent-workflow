#!/usr/bin/env bash
set -euo pipefail

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

if [[ ! -f "$manifest_path" ]]; then
  printf 'Uninstall refused: ownership manifest not found at %s (will not guess ownership by filename)\n' "$manifest_path" >&2
  exit 1
fi

declare -a rels=()
declare -A hashes=()
count=0
while IFS=$'\t' read -r proj rel hash _; do
  [[ -z "${proj:-}" || "$proj" == \#* ]] && continue
  [[ "$proj" != "$project_id" ]] && continue
  rels+=("$rel")
  hashes["$rel"]="$(printf '%s' "$hash" | tr '[:upper:]' '[:lower:]')"
  count=$((count + 1))
done < "$manifest_path"

if [[ "$count" -eq 0 ]]; then
  printf 'Uninstall refused: manifest contains no project entries\n' >&2
  exit 1
fi

# ---- Verify ALL paths and hashes before deleting anything ----
failures=()
for rel in "${rels[@]}"; do
  dest="$target_root/$rel"
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

# ---- Delete only manifest-proven, unmodified project files ----
for rel in "${rels[@]}"; do
  rm -f "$target_root/$rel"
done

# Remove directories only when empty (no recursive delete of user content)
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

printf 'Uninstalled %d owned files from %s (manifest removed)\n' "$count" "$target_root"
