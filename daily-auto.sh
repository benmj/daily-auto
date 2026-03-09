#!/usr/bin/env bash
set -euo pipefail

# daily-auto.sh — Automated daily note creation via Claude Code
# Intended to be run by launchd (com.ben.daily-note) at 07:30 daily

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
# launchd runs with minimal env, so set PATH explicitly
export PATH="/Users/ben/.local/bin:/Users/ben/.nvm/versions/node/v22.14.0/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/ben"

DAILY_DIR="$HOME/Documents/daily"
LOG_DIR="$HOME/Library/Logs/daily-note"
LOG_FILE="$LOG_DIR/daily-note.log"
LOCK_FILE="/tmp/daily-note.lock"
MAX_RETRIES=2
RETRY_DELAY=30
NETWORK_TIMEOUT=30

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]] && (( $(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0) > 1048576 )); then
        mv "$LOG_FILE" "$LOG_FILE.$(date '+%Y%m%d%H%M%S')"
        log "INFO" "Log rotated"
        # Keep only the 5 most recent rotated logs
        ls -t "$LOG_DIR"/daily-note.log.* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Lock file (prevent overlapping runs)
# ---------------------------------------------------------------------------
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log "WARN" "Already running (PID $old_pid), exiting"
            exit 0
        fi
        log "INFO" "Removing stale lock (PID $old_pid)"
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}
trap release_lock EXIT

# ---------------------------------------------------------------------------
# Network check
# ---------------------------------------------------------------------------
wait_for_network() {
    local elapsed=0
    while (( elapsed < NETWORK_TIMEOUT )); do
        if curl -sf --max-time 5 "https://api.anthropic.com/" >/dev/null 2>&1; then
            log "INFO" "Network available (${elapsed}s)"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    log "ERROR" "Network unavailable after ${NETWORK_TIMEOUT}s"
    return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
rotate_log

log "INFO" "=== Starting daily-auto ==="

acquire_lock

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

attempt=0
while (( attempt <= MAX_RETRIES )); do
    if (( attempt > 0 )); then
        log "INFO" "Retry $attempt/$MAX_RETRIES (waiting ${RETRY_DELAY}s)"
        sleep "$RETRY_DELAY"
    fi

    log "INFO" "Running claude (attempt $((attempt + 1)))"

    output=$(cd "$DAILY_DIR" && claude --print --dangerously-skip-permissions --no-session-persistence "/daily" 2>&1) && {
        log "INFO" "Claude completed successfully"
        log "INFO" "Output (truncated): $(echo "$output" | head -20)"
        log "INFO" "=== Finished ==="
        exit 0
    }

    log "ERROR" "Claude failed (attempt $((attempt + 1))): $(echo "$output" | tail -5)"
    attempt=$((attempt + 1))
done

log "ERROR" "All attempts exhausted, giving up"
exit 1
