#!/usr/bin/env bash
# capture-dispatch.sh — act on a single captured inbox item with a background
# headless Claude session, then file the result into today's note and flip the
# item's inbox line ⏳ → ✓. Invoked detached by `cap!` (see ~/.zshrc).
#
#   capture-dispatch.sh "<YYYY-MM-DD HH:MM>" "<item text>"
#
# Reuses common.sh for PATH/logging/network/retry, but deliberately does NOT
# acquire the shared lock — multiple captures may run concurrently.
TASK_NAME="capture"
source "$(dirname "$0")/common.sh"

ts="${1:?timestamp required}"
text="${2:?item text required}"

log "INFO" "=== capture dispatch: [$ts] $text ==="

if ! wait_for_network; then
    log "ERROR" "Aborting: no network (item left ⏳ in inbox for later triage)"
    exit 1
fi

# Invoke the capture skill in process-one mode. The skill acts on the item,
# files the result per /daily conventions, and updates the inbox line.
run_claude "/capture ${ts}::${text}"
exit_code=$?

log "INFO" "=== capture dispatch finished (exit $exit_code) ==="
exit "$exit_code"
