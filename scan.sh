#!/usr/bin/env bash
# ==============================================================================
# Omarchy File Picker - High Performance File Scanner & Cache Manager
# ==============================================================================

set -euo pipefail

CONFIG_FILE="${OMARCHY_FILE_PICKER_CONFIG:-$HOME/.config/omarchy/file-picker.json}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/file-picker"
CACHE_FILE="$CACHE_DIR/files.tsv"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="$SCRIPT_DIR/default-config.json"

mkdir -p "$CACHE_DIR"

# Ensure config file exists in user's ~/.config/omarchy
if [[ ! -f "$CONFIG_FILE" && -f "$DEFAULT_CONFIG" ]]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cp "$DEFAULT_CONFIG" "$CONFIG_FILE" 2>/dev/null || true
fi

EFFECTIVE_CONFIG="$CONFIG_FILE"
if [[ ! -f "$EFFECTIVE_CONFIG" ]]; then
  EFFECTIVE_CONFIG="$DEFAULT_CONFIG"
fi

FORCE_REFRESH=0
OUTPUT_FORMAT="tsv" # tsv or json
FILTER_CATEGORY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|--refresh|-f)
      FORCE_REFRESH=1
      shift
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --tsv)
      OUTPUT_FORMAT="tsv"
      shift
      ;;
    --category|-c)
      FILTER_CATEGORY="$2"
      shift 2
      ;;
    --config)
      EFFECTIVE_CONFIG="$2"
      shift 2
      ;;
    -h|--help)
      cat <<USAGE
Usage: scan.sh [options]

Options:
  --force, --refresh, -f   Force re-indexing all files, ignoring cache
  --json                   Output results in JSON format
  --tsv                    Output results in TSV format (path, category, ext, size, mtime)
  --category <cat>         Filter by category (documents, notes, videos, audio, images, code)
  --config <path>          Custom configuration file path
USAGE
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

CACHE_TTL=300
MAX_RESULTS=2000
if [[ -f "$EFFECTIVE_CONFIG" ]]; then
  CACHE_TTL=$(jq -r '.cacheTtlSeconds // 300' "$EFFECTIVE_CONFIG" 2>/dev/null || echo 300)
  MAX_RESULTS=$(jq -r '.maxResults // 2000' "$EFFECTIVE_CONFIG" 2>/dev/null || echo 2000)
fi
[[ "$MAX_RESULTS" =~ ^[1-9][0-9]*$ ]] || MAX_RESULTS=2000

is_cache_valid() {
  [[ -f "$CACHE_FILE" && $FORCE_REFRESH -eq 0 ]] || return 1
  local now mtime age
  now=$(date +%s)
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  age=$(( now - mtime ))
  (( age < CACHE_TTL ))
}

perform_scan() {
  local tmp_cache="$CACHE_FILE.tmp.$$"
  local dirs=()
  local excludes=()
  local exts=()

  if [[ -f "$EFFECTIVE_CONFIG" ]]; then
    while IFS= read -r dir; do
      dir="${dir/#\~/$HOME}"
      dir="${dir/\$HOME/$HOME}"
      [[ -d "$dir" ]] && dirs+=("$dir")
    done < <(jq -r '.directories[]? // empty' "$EFFECTIVE_CONFIG" 2>/dev/null)

    while IFS= read -r exc; do
      [[ -n "$exc" ]] && excludes+=("$exc")
    done < <(jq -r '.excludeDirectories[]? // empty' "$EFFECTIVE_CONFIG" 2>/dev/null)

    while IFS= read -r ext; do
      [[ -n "$ext" ]] && exts+=("$ext")
    done < <(jq -r '.categories | to_entries[] | .value[]' "$EFFECTIVE_CONFIG" 2>/dev/null)
  fi

  if [[ ${#dirs[@]} -eq 0 ]]; then
    for d in "$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop" "$HOME/Github" "$HOME/Videos" "$HOME/Music" "$HOME/Pictures"; do
      [[ -d "$d" ]] && dirs+=("$d")
    done
  fi

  if [[ ${#dirs[@]} -eq 0 ]]; then
    dirs=("$HOME")
  fi

  if command -v fd >/dev/null 2>&1; then
    local fd_cmd=("fd" "--type" "f" "--hidden" "--follow" "--no-ignore-vcs")

    for exc in "${excludes[@]}"; do
      fd_cmd+=("-E" "$exc")
    done

    for ext in "${exts[@]}"; do
      fd_cmd+=("-e" "$ext")
    done

    "${fd_cmd[@]}" . "${dirs[@]}" -X stat -c $'%n\t%s\t%Y' 2>/dev/null | awk -F'\t' '
      BEGIN { OFS="\t" }
      {
        file = $1;
        size = $2;
        mtime = $3;
        n = split(file, p, "/");
        base = p[n];
        m = split(base, ep, ".");
        ext = (m > 1) ? tolower(ep[m]) : "";
        cat = "other";
        if (ext ~ /^(pdf|epub|djvu|docx|pptx|xlsx|txt|csv|odt|ods|odp|rtf)$/) cat = "documents";
        else if (ext ~ /^(md|markdown|org|rst|adoc)$/) cat = "notes";
        else if (ext ~ /^(mp4|mkv|avi|mov|webm|flv|wmv|m4v|3gp)$/) cat = "videos";
        else if (ext ~ /^(mp3|flac|ogg|wav|m4a|aac|opus|wma|aiff)$/) cat = "audio";
        else if (ext ~ /^(png|jpg|jpeg|webp|gif|svg|bmp|avif|ico|tiff)$/) cat = "images";
        else if (ext ~ /^(py|rs|go|js|ts|jsx|tsx|c|cpp|h|hpp|sh|bash|zsh|lua|json|toml|yaml|yml|css|html|php|java|kt|swift|zig|sql)$/) cat = "code";
        print file, cat, ext, size, mtime;
      }
    ' | sort -k5 -nr > "$tmp_cache"
  else
    local find_excludes=()
    for exc in "${excludes[@]}"; do
      find_excludes+=(-name "$exc" -o)
    done

    local find_exts=()
    for ext in "${exts[@]}"; do
      find_exts+=(-iname "*.$ext" -o)
    done

    find "${dirs[@]}" \
      -type d \( "${find_excludes[@]}" -false \) -prune -o \
      -type f \( "${find_exts[@]}" -false \) -exec stat -c $'%n\t%s\t%Y' {} + 2>/dev/null | awk -F'\t' '
      BEGIN { OFS="\t" }
      {
        file = $1;
        size = $2;
        mtime = $3;
        n = split(file, p, "/");
        base = p[n];
        m = split(base, ep, ".");
        ext = (m > 1) ? tolower(ep[m]) : "";
        cat = "other";
        if (ext ~ /^(pdf|epub|djvu|docx|pptx|xlsx|txt|csv|odt|ods|odp|rtf)$/) cat = "documents";
        else if (ext ~ /^(md|markdown|org|rst|adoc)$/) cat = "notes";
        else if (ext ~ /^(mp4|mkv|avi|mov|webm|flv|wmv|m4v|3gp)$/) cat = "videos";
        else if (ext ~ /^(mp3|flac|ogg|wav|m4a|aac|opus|wma|aiff)$/) cat = "audio";
        else if (ext ~ /^(png|jpg|jpeg|webp|gif|svg|bmp|avif|ico|tiff)$/) cat = "images";
        else if (ext ~ /^(py|rs|go|js|ts|jsx|tsx|c|cpp|h|hpp|sh|bash|zsh|lua|json|toml|yaml|yml|css|html|php|java|kt|swift|zig|sql)$/) cat = "code";
        print file, cat, ext, size, mtime;
      }
    ' | sort -k5 -nr > "$tmp_cache"
  fi

  head -n "$MAX_RESULTS" "$tmp_cache" > "$tmp_cache.limited"
  mv "$tmp_cache.limited" "$tmp_cache"
  mv "$tmp_cache" "$CACHE_FILE"
}

if ! is_cache_valid; then
  perform_scan
fi

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  jq -R -s -c --arg cat "$FILTER_CATEGORY" '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        path: .[0],
        category: .[1],
        extension: .[2],
        size: (.[3] | tonumber? // 0),
        mtime: (.[4] | tonumber? // 0)
      })
    | if ($cat != "" and $cat != "all") then map(select(.category == $cat)) else . end
  ' "$CACHE_FILE" 2>/dev/null || echo "[]"
else
  if [[ -n "$FILTER_CATEGORY" && "$FILTER_CATEGORY" != "all" ]]; then
    awk -F '\t' -v cat="$FILTER_CATEGORY" '$2 == cat { print }' "$CACHE_FILE"
  else
    cat "$CACHE_FILE"
  fi
fi
