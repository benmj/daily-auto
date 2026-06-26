#!/usr/bin/env python3
"""granola-match.py CALENDAR_JSON — cross-link each calendar event to a same-date
granola note whose title matches (rendered as source-granola-*.html in brain).

Generic meeting words are dropped before scoring so a lone shared token
("standup", "ben", "sync") can't create a false link (e.g. "Jungle Standup"
must not match the "Bayou standup" note). Prints "changed" or "nochange".
Shared by calendar-dump.sh (after the Google query) and granola-relink.sh.
"""
import json
import sys
import glob
import os
import re

STOP = set(("standup sync meeting weekly daily biweekly check checkin call followup "
            "follow team cross ben the and with for review catch huddle chat quick "
            "prep").split())


def norm(s):
    return set(w for w in re.sub(r"[^a-z0-9]+", " ", s.lower()).split() if len(w) > 2)


def main(out):
    if not os.path.exists(out):
        return
    try:
        cal = json.load(open(out))
    except Exception:
        return
    daily = os.path.expanduser("~/Documents/daily")
    gran = {}
    for p in glob.glob(daily + "/granola/*.md"):
        m = re.match(r"(\d{4}-\d{2}-\d{2})-(.+)", os.path.splitext(os.path.basename(p))[0])
        if m:
            gran.setdefault(m.group(1), []).append(
                (os.path.splitext(os.path.basename(p))[0], m.group(2)))
    changed = False
    for e in cal.get("events", []):
        prev = e.get("granola")
        e.pop("granola", None)
        best, bs = None, 0
        et = norm(e.get("title", "")) - STOP
        for stem, slug in gran.get(e.get("date"), []):
            sc = len(et & (norm(slug.replace("-", " ")) - STOP))
            if sc > bs:
                bs, best = sc, stem
        if best and bs >= 1:
            e["granola"] = "source-granola-" + best + ".html"
        if e.get("granola") != prev:
            changed = True
    json.dump(cal, open(out, "w"), ensure_ascii=False)
    print("changed" if changed else "nochange")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1])
