# daily-auto

Automated daily note creation via Claude Code + launchd.

## What it does

Runs `/daily` (a Claude Code skill) every morning at 7:30 AM to create a daily note, carry over open tasks, reconcile granola meeting notes, and generate a weekly summary.

## Files

| File                    | Purpose                                              |
| ----------------------- | ---------------------------------------------------- |
| `daily-auto.sh`         | Shell wrapper: env setup, locking, logging, retries  |
| `com.ben.daily-note.plist` | launchd agent: daily at 7:30 AM                   |

## Install

```bash
# Copy plist to LaunchAgents
cp com.ben.daily-note.plist ~/Library/LaunchAgents/

# Load the agent
launchctl load ~/Library/LaunchAgents/com.ben.daily-note.plist
```

## Logs

`~/Library/Logs/daily-note/daily-note.log`

## Manual trigger

```bash
# Direct
bash daily-auto.sh

# Via launchd
launchctl start com.ben.daily-note
```
