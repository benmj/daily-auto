#!/usr/bin/env bash
# tidy.sh — Reconcile granola, ticket refs, and inline URLs (daily at noon)
TASK_NAME="tidy"
source "$(dirname "$0")/common.sh"

log "INFO" "=== Starting tidy ==="
acquire_lock

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

run_claude "/daily tidy"
exit_code=$?

log "INFO" "=== Finished (exit $exit_code) ==="
exit "$exit_code"
