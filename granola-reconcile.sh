#!/usr/bin/env bash
# granola-reconcile.sh — Crosslink orphaned granola notes (hourly)
# Runs the fast bash check first; only invokes Claude if orphans exist.
TASK_NAME="granola-reconcile"
MAX_RETRIES=1
source "$(dirname "$0")/common.sh"

log "INFO" "=== Starting granola-reconcile ==="
acquire_lock

# Fast check — no network/Claude needed if everything is linked
reconcile_output=$("$DAILY_DIR/granola/reconcile" 2>&1) || true

if echo "$reconcile_output" | grep -q "All granola notes are crosslinked"; then
    log "INFO" "No orphans found, skipping Claude"
    log "INFO" "=== Finished (nothing to do) ==="
    exit 0
fi

orphan_count=$(echo "$reconcile_output" | grep -oE '^[0-9]+' | head -1)
log "INFO" "Found ${orphan_count:-some} orphaned granola note(s), invoking Claude"

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

run_claude "/daily tidy"
exit_code=$?

log "INFO" "=== Finished (exit $exit_code) ==="
exit "$exit_code"
