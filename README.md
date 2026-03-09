# daily-auto

Automated daily notes and tidying via Claude Code + launchd.

## Tasks

| Script                  | Schedule         | What it does                                              |
| ----------------------- | ---------------- | --------------------------------------------------------- |
| `daily-note.sh`         | 07:30 daily      | Create daily note, carry over tasks, weekly summary       |
| `granola-reconcile.sh`  | :00 every hour   | Crosslink orphaned granola meeting notes (skips Claude if none) |
| `tidy.sh`               | 12:00 daily      | Reconcile granola + ticket refs + inline URLs             |

Shared infra (env, logging, locking, network, retries) lives in `common.sh`.

## Install

```bash
cp com.ben.*.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ben.daily-note.plist
launchctl load ~/Library/LaunchAgents/com.ben.granola-reconcile.plist
launchctl load ~/Library/LaunchAgents/com.ben.daily-tidy.plist
```

## Logs

Each task writes to `~/Library/Logs/daily-note/<task-name>.log`.

## Manual trigger

```bash
launchctl start com.ben.daily-note
launchctl start com.ben.granola-reconcile
launchctl start com.ben.daily-tidy
```
