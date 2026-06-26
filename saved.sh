#!/usr/bin/env bash
# saved.sh — Triage new Slack saved items into the daily system + prune the reading queue (07:45 daily)
TASK_NAME="saved"
source "$(dirname "$0")/common.sh"

log "INFO" "=== Starting saved triage ==="
acquire_lock

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

# Triage only NEW saved items (ledger dedup; stops paging at first known ts),
# then archive checked/stale items out of the reading queue.
run_claude "/saved"
triage_code=$?

run_claude "/saved prune"
prune_code=$?

exit_code=$(( triage_code != 0 ? triage_code : prune_code ))
log "INFO" "=== Finished (triage $triage_code, prune $prune_code) ==="
exit "$exit_code"
