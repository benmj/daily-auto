# daily-auto

Automated daily notes and tidying via Claude Code + launchd.

## Tasks

| Script                  | Schedule         | What it does                                              |
| ----------------------- | ---------------- | --------------------------------------------------------- |
| `briefing.sh`           | 06:00 daily      | Morning briefing (calendar/email/Slack/Linear/weather) → Slack DM to self via `/briefing` skill |
| `corpus-compile.sh`     | 06:45 daily      | Compile yesterday into the second-brain `wiki/` (threads/entities), reindex, lint — before briefing reads lint findings |
| `daily-note.sh`         | 07:30 daily      | Create daily note, carry over tasks, weekly summary; then `corpus reindex` |
| `granola-reconcile.sh`  | :00 every hour   | Crosslink orphaned granola meeting notes (skips Claude if none) |
| `tidy.sh`               | 12:00 daily      | Reconcile granola + ticket refs + inline URLs             |
| `saved.sh`              | 07:45 daily      | Triage new Slack saved items (`is:saved`) → daily note / reading queue / refs, then prune the queue, via `/saved` |

Shared infra (env, logging, locking, network, retries) lives in `common.sh`.

## Install

```bash
cp com.ben.*.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ben.briefing.plist
launchctl load ~/Library/LaunchAgents/com.ben.corpus-compile.plist
launchctl load ~/Library/LaunchAgents/com.ben.daily-note.plist
launchctl load ~/Library/LaunchAgents/com.ben.granola-reconcile.plist
launchctl load ~/Library/LaunchAgents/com.ben.daily-tidy.plist
launchctl load ~/Library/LaunchAgents/com.ben.saved.plist
```

To disable the saved-items triage: `launchctl unload ~/Library/LaunchAgents/com.ben.saved.plist`.

## Logs

Each task writes to `~/Library/Logs/daily-note/<task-name>.log`.

## Manual trigger

```bash
launchctl start com.ben.briefing
launchctl start com.ben.corpus-compile
launchctl start com.ben.daily-note
launchctl start com.ben.granola-reconcile
launchctl start com.ben.daily-tidy
launchctl start com.ben.saved
```
