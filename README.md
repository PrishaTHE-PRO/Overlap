# Overlap

Find the hours a group of friends are all free, read off screenshots of their
class schedules.

**[prishathe-pro.github.io/Overlap](https://prishathe-pro.github.io/Overlap/)**

## What it does

- **Reads a screenshot.** Course Search & Enroll, MyUW, Google Calendar, a
  photo of a printout. The image is read on your own device and never uploaded.
- **Lays out the week.** Classes collapse into one neutral band a day, so the
  time everybody shares is the only thing coloured on the grid.
- **Shares a group.** A short code puts everyone who joins in the same week.
  Your groups follow you between laptop and phone.
- **Flags overlaps.** Says when you are in the same section at the same hour as
  someone else, and when you share a course but not a section.

An account is only needed for groups. On your own it works signed out, and
nothing leaves the browser.

## Running it

It is one file with no build step.

```
git clone https://github.com/PrishaTHE-PRO/Overlap.git
cd Overlap
python3 -m http.server 8000      # then open localhost:8000
```

Opening `index.html` directly mostly works, but sign-in does not: OAuth cannot
redirect back to a `file://` page.

## Setting up the backend

Groups and sync need a Supabase project. Without one the app still runs, purely
local.

1. Create a project at [supabase.com](https://supabase.com).
2. Run [`supabase/setup.sql`](supabase/setup.sql) in the SQL editor. It is safe
   to run more than once, and creates every table and policy the app needs.
3. Turn on the Google provider under **Authentication → Sign In / Providers**,
   and add your site under **URL Configuration**.
4. Put your project URL and anon key in `OVERLAP_CONFIG` near the top of
   `index.html`.

[`supabase/audit.sql`](supabase/audit.sql) prints your policies back to you, to
check who can read what.

## Built with

| | |
|---|---|
| Frontend | One HTML file. No framework, no build step, no dependencies to install. |
| OCR | [Tesseract.js](https://tesseract.projectnaptha.com/), inlined and gzipped, run in the browser |
| HEIC photos | [libheif-js](https://github.com/catdad-experiments/libheif-js), loaded only when an iPhone photo is dropped |
| Backend | [Supabase](https://supabase.com) — Postgres, row level security, Google OAuth |
| Hosting | GitHub Pages |

The OCR bundle is embedded in the page rather than fetched, which is why the
file is a few megabytes. It loads after the app, so the week draws first.

## Licence

MIT. See [LICENSE](LICENSE).

Tesseract.js and libheif-js are Apache-2.0 and MIT respectively, and keep their
own licences.
