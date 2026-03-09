#!/usr/bin/env bash
# common.sh — Shared environment, logging, locking, and network utilities
# Source this from task scripts: source "$(dirname "$0")/common.sh"

set -euo pipefail

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export PATH="/Users/ben/.local/bin:/Users/ben/.nvm/versions/node/v22.14.0/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/ben"
unset CLAUDECODE 2>/dev/null || true

DAILY_DIR="$HOME/Documents/daily"
LOG_DIR="$HOME/Library/Logs/daily-note"
LOCK_FILE="/tmp/daily-auto-${TASK_NAME:?TASK_NAME must be set before sourcing common.sh}.lock"
LOG_FILE="$LOG_DIR/${TASK_NAME}.log"
MAX_RETRIES="${MAX_RETRIES:-2}"
RETRY_DELAY="${RETRY_DELAY:-30}"
NETWORK_TIMEOUT="${NETWORK_TIMEOUT:-30}"

mkdir -p "$LOG_DIR"

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
        ls -t "$LOG_DIR"/${TASK_NAME}.log.* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Lock file
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
        if curl -s --max-time 5 --head -o /dev/null "https://api.anthropic.com/" 2>/dev/null; then
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
# Claude runner with retries
# ---------------------------------------------------------------------------
run_claude() {
    local prompt="$1"
    local attempt=0

    while (( attempt <= MAX_RETRIES )); do
        if (( attempt > 0 )); then
            log "INFO" "Retry $attempt/$MAX_RETRIES (waiting ${RETRY_DELAY}s)"
            sleep "$RETRY_DELAY"
        fi

        log "INFO" "Running claude (attempt $((attempt + 1)))"

        local output
        output=$(cd "$DAILY_DIR" && claude --print --dangerously-skip-permissions --no-session-persistence "$prompt" 2>&1) && {
            log "INFO" "Claude completed successfully"
            log "INFO" "Output (truncated): $(echo "$output" | head -20)"
            return 0
        }

        log "ERROR" "Claude failed (attempt $((attempt + 1))): $(echo "$output" | tail -5)"
        attempt=$((attempt + 1))
    done

    log "ERROR" "All attempts exhausted"
    return 1
}

rotate_log
