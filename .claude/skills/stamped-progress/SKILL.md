---
name: stamped-progress
description: Read-only growth report for Stamped! A City Passport across YouTube Studio, App Store analytics and the portfolio site's GA4, compared with the last check. Use when George asks how Stamped's YouTube, downloads or marketing are doing, whether to record more Vision Pro content, or what Stamped videos to post next. For Tally and Squishy Butter use progress-check instead.
---

# Stamped progress

Report what changed since the last check and the one or two things worth doing next. Everything here is read-only: never publish, edit or change a setting. Keep it short and use scaled-down screenshots only if text reading fails.

## 1. Load the last check

Read the newest section of `~/.claude/progress-check/stamped-history.md` and note how many days ago it was.

## 2. YouTube (channel UCiS91UC6MJujD998mUrAisg)

Use the built-in browser, which is signed in to the Stamped channel. Studio uses shadow DOM and loads slowly: wait about 10 seconds per page.

- `https://studio.youtube.com/channel/UCiS91UC6MJujD998mUrAisg/videos/short`: `get_page_text` gives views and comment counts for every Short. A count of 1 comment is our own App Store comment.
- `https://studio.youtube.com/channel/UCiS91UC6MJujD998mUrAisg`: read with this JavaScript, since `get_page_text` misses it. It gives subscribers, 28-day views, watch time, last 48-hour top content and the newest Short's average percentage viewed.

```js
function t(n,o=[]){if(n.nodeType==3){let s=n.textContent.trim();if(s)o.push(s)}else if(!['SCRIPT','STYLE','svg'].includes(n.nodeName)){(n.shadowRoot?n.shadowRoot.childNodes:[]).forEach(c=>t(c,o));n.childNodes.forEach(c=>t(c,o))}return o};t(document.querySelector('ytcp-app')||document.body).join(' | ').slice(150,2500)
```

The `/analytics/` tabs showed "Oops, something went wrong" in the built-in browser on 2026-11-09. Try one once; if it fails, say retention by video was not available and move on.

## 3. App Store

Run `ruby .claude/skills/stamped-progress/asc_report.rb 28` from the repo root. It only sends GET requests. Use first-time downloads as the headline: the total includes auto-updates. Counts are small and Apple adds noise, so do not read much into differences of 2 or so.

The ct=youtube campaign will stay empty while description links are unclickable (phone verification, see the YouTube memory). Judge YouTube's effect from first-time downloads by day and search page views after posting dates, and say it is only a correlation.

## 4. GA4

Portfolio property: `https://analytics.google.com/analytics/web/#/a386868409p547377744/reports/intelligenthome`, read with `get_page_text`. It covers the portfolio site, including the Stamped case study page; the app itself sends nothing to GA4. Check the URL holds `p547377744`: the account can open on other properties, such as Crystal Lake Resort, which are not part of this report.

## 5. Videos on hand

Compare `docs/marketing/short-*-FINAL.mp4` and the script list in `docs/marketing/youtube-shorts-scripts.md` with what Studio shows, to list anything built but not posted and scripts not yet built.

## 6. Report

A table of metric, last check, now. Then what worked, whether Vision Pro content is earning its effort, and at most two next steps. State anything you could not read. Then append a dated section with the key numbers to `~/.claude/progress-check/stamped-history.md`.
