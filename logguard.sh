#!/bin/zsh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${LOGGUARD_CONFIG:-$SCRIPT_DIR/config.conf}"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: Config not found: $CONFIG_FILE" >&2; exit 1; }
source "$CONFIG_FILE"
LOG_DIR="${LOG_DIR/#\~/$HOME}"

case "$LOG_DIR" in
  ""|"/"|"/System"|"/Library"|"/Users"|"$HOME"|"$HOME/Library")
    echo "ERROR: Refusing unsafe LOG_DIR: $LOG_DIR" >&2; exit 1 ;;
esac
case "$LOG_DIR" in "$HOME"/*) ;; *) echo "ERROR: LOG_DIR must be under $HOME" >&2; exit 1 ;; esac
[[ "${RETENTION_DAYS:-}" =~ '^[0-9]+$' ]] || { echo "ERROR: RETENTION_DAYS must be an integer" >&2; exit 1; }
[[ "${MAX_SIZE_GB:-}" =~ '^[0-9]+([.][0-9]+)?$' ]] || { echo "ERROR: MAX_SIZE_GB must be numeric" >&2; exit 1; }

mkdir -p "$LOG_DIR"
timestamp(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ local m="$(timestamp) $*"; echo "$m"; [[ "$DRY_RUN" == true ]] || echo "$m" >> "$LOGGUARD_LOG"; }
directory_bytes(){ /usr/bin/du -sk "$LOG_DIR" 2>/dev/null | /usr/bin/awk '{print $1 * 1024}'; }
MAX_BYTES=$(awk "BEGIN {printf \"%.0f\", $MAX_SIZE_GB * 1024 * 1024 * 1024}")

log "LogGuard starting: dir=$LOG_DIR retention=${RETENTION_DAYS}d max=${MAX_SIZE_GB}GB dry_run=$DRY_RUN"

OLD_COUNT=0
while IFS= read -r -d '' file; do
  (( OLD_COUNT++ ))
  if [[ "$DRY_RUN" == true ]]; then log "[DRY RUN] old: $file"; else /bin/rm -f -- "$file" && log "Deleted old: $file"; fi
done < <(/usr/bin/find "$LOG_DIR" -type f -mtime "+$RETENTION_DAYS" -print0 2>/dev/null)
log "Retention matched $OLD_COUNT files"

CURRENT_BYTES=$(directory_bytes)
if (( CURRENT_BYTES > MAX_BYTES )); then
  log "Size limit exceeded ($CURRENT_BYTES > $MAX_BYTES); removing oldest files"
  TEMP_FILE="$(mktemp -t reolink-logguard)"
  /usr/bin/find "$LOG_DIR" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
    mtime=$(/usr/bin/stat -f "%m" "$file" 2>/dev/null)
    size=$(/usr/bin/stat -f "%z" "$file" 2>/dev/null)
    [[ -n "$mtime" && -n "$size" ]] && printf '%s\t%s\t%s\n' "$mtime" "$size" "$file"
  done | /usr/bin/sort -n > "$TEMP_FILE"

  PROJECTED_BYTES=$CURRENT_BYTES
  while IFS=$'\t' read -r mtime size file; do
    (( PROJECTED_BYTES <= MAX_BYTES )) && break
    [[ -f "$file" ]] || continue
    if [[ "$DRY_RUN" == true ]]; then
      log "[DRY RUN] size-limit delete ($size bytes): $file"
      PROJECTED_BYTES=$(( PROJECTED_BYTES - size ))
    else
      if /bin/rm -f -- "$file"; then
        log "Deleted for size limit ($size bytes): $file"
        PROJECTED_BYTES=$(( PROJECTED_BYTES - size ))
      fi
    fi
  done < "$TEMP_FILE"
  /bin/rm -f "$TEMP_FILE"
  [[ "$DRY_RUN" == true ]] && log "[DRY RUN] projected final size: $PROJECTED_BYTES bytes"
else
  log "Directory is within size limit ($CURRENT_BYTES bytes)"
fi

[[ "$DRY_RUN" == true ]] || /usr/bin/find "$LOG_DIR" -depth -type d -empty ! -path "$LOG_DIR" -delete 2>/dev/null
FINAL_BYTES=$(directory_bytes)
log "LogGuard finished: final_size=$FINAL_BYTES bytes"
