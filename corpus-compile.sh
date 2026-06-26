#!/usr/bin/env bash
# corpus-compile.sh — compile the previous (settled) day into the second-brain
# wiki, refresh the index, and lint. Runs headless before the morning briefing
# so the briefing can surface lint findings (stale threads, etc.).
#
#   corpus-compile.sh [YYYY-MM-DD]   # default: yesterday
#
# `corpus compile` shells out to `claude --print` ONCE for extraction, applies
# the edits deterministically + idempotently (append-only), then reindexes.
TASK_NAME="corpus-compile"
source "$(dirname "$0")/common.sh"

CORPUS="$HOME/Documents/daily/bin/corpus"
target="${1:-$(date -v-1d +%F)}"   # macOS date: yesterday

log "INFO" "=== Starting corpus-compile for $target ==="
acquire_lock

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

# compile (idempotent; safe to re-run). This rebuilds wiki/index.md + the FTS
# index + manifest itself, then we lint. Pipe output to the log line-by-line.
"$CORPUS" compile "$target" 2>&1 | while IFS= read -r l; do log "INFO" "compile: $l"; done || true
# lint → log (the briefing reads `corpus lint` itself for the human-facing surface)
"$CORPUS" lint 2>&1 | while IFS= read -r l; do log "INFO" "lint: $l"; done || true

# Publish the private web hub (brain.benbybenjacobs.com). Generation must happen
# HERE — the Mac has every note local; Benito's iCloud copies are dataless and
# generating there hangs on on-demand downloads. Benito just serves the static
# output, so we rsync it over.
WEB="$HOME/Documents/daily/.corpus/web"
"$CORPUS" web --out "$WEB" 2>&1 | while IFS= read -r l; do log "INFO" "web: $l"; done || true
if rsync -az --delete "$WEB/" benito@benitos-mac-mini:/srv/benbybenjacobs.com/brain/ 2>>"$LOG_FILE"; then
    log "INFO" "brain published to Benito"
else
    log "WARN" "brain rsync to Benito failed (non-fatal; will retry next run)"
fi

log "INFO" "=== Finished corpus-compile ==="
exit 0
