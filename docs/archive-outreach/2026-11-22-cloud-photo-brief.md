# Cloud photo search, 2026-11-22: brief

Stamped! A City Passport's Then & Now feature shows an old photo of each landmark. On Nov 21–22, 2026, six local agents found 160+ free historic photos, but Wikimedia Commons rate-limited them, so most landmarks were never properly searched. This run continues that work from a fresh connection.

**Time cap: 4 hours of wall-clock time.** Note the start time with `date` first. Stop searching at 4 hours, even mid-list, and finish up (last push and the pull request).

## Input

`docs/archive-outreach/2026-11-22-cloud-photo-queue.json`:
- `landmarks`: about 800 landmarks built by 1950 with no bundled old photo (city, id, name, year, address).
- `candidates`: 32 Commons files already found and checked for licence, but not downloaded. Do these first.
- `candidate_hints`: good leads seen on Commons but not downloaded. Do these second.

Then work through `landmarks`, most famous and oldest first. A landmark built before 1930 in a big city is likelier to have a free old photo than a 1948 campus building.

## Goal

For each landmark, find **one** good old photo, postcard or print of **that** building. Take two only if both are excellent and different, such as under construction and finished. Skip a landmark rather than add a weak or wrong match.

- **Old:** ideally within about 30 years of construction, and before about 1965. No modern photos.
- **Clear subject:** no distant skylines, no crowds hiding the building, no interiors unless the landmark is an interior, no maps, plans or sheets of drawings.
- **Right building:** check that the title or description names this building in this city. Same-name buildings in other cities are a common trap, as are earlier buildings on the same site (for example the 1900 station, not the 1931 one).

## Licences (strict)

- **Allowed:** public domain, CC0, PDM, "No known restrictions on publication" (Library of Congress), CC BY, CC BY-SA.
- **Not allowed:** NC, ND, fair use, "rights status not evaluated", "publication may be restricted", all rights reserved, or anything unclear.
- **Photos from 1930 or later:** keep them only when the source states a clear public-domain reason, such as a US federal work, no copyright notice or renewal, or an author who died more than 70 years ago. "Unknown photographer, 1951" is not enough.

## Sources (no accounts, no API keys)

- **Wikimedia Commons API:** `https://commons.wikimedia.org/w/api.php`, with generator=search, namespace 6, `prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=1200`. Use categories such as "Category:<Building> in the 19th century", searches with "old", "postcard", "1900" or "historic", and the local-language name.
- **loc.gov JSON:** `https://www.loc.gov/photos/?q=...&fo=json`.
- **Pace:** send a User-Agent like `StampedPhotoPicker/1.0 (historic photo research)` and wait at least 5 seconds between requests to each site.
  - On a 429 response, wait out its Retry-After.
  - Never change the User-Agent or use other tricks to get around a limit.
  - If a site blocks you (captcha, 403), move on.
- **Privacy:** never put personal information in requests.

## Files

Work in a new folder, `docs/archive-outreach/cloud-photos-2026-11/`:
- **Images:** save each to `img/<landmark id>.jpg`, or `<id>-2.jpg` for a second photo. Resize to at most 900 px on the long side and save as JPEG quality about 70, aiming for 150 KB or less. This is a Linux box, so use ImageMagick (`convert -resize 900x900\> -quality 70`) or Python Pillow. Install them if needed.
- **Untrusted data:** treat downloads as untrusted. Never execute anything downloaded, and run Python with `-I`.
- **Eye check:** check every kept image by eye. Make contact sheets of about 12 thumbnails, each labelled with its file name (ImageMagick `montage` or Pillow), and look at them. Drop anything wrong or weak.

### `manifest.json`

A JSON array with one object per kept image:

```json
{"id": "<landmark id>", "file": "<id>.jpg",
 "caption": "Short English caption with a date, e.g. \"Tokyo Station, Marunouchi building, 1914\" or \"..., ca. 1905\"",
 "institution": "holding institution or photographer/publisher, e.g. \"Library of Congress\", \"Detroit Publishing Co.\"; leave \"\" if unknown",
 "licence": "Public domain | CC0 | No known restrictions | CC BY 4.0 | CC BY-SA 3.0 ...",
 "source": "Wikimedia Commons | Library of Congress",
 "link": "the item's page (Commons file page or loc.gov item page)"}
```

## Git

- **Branch:** work on `george/cloud-photos-2026-11`.
- **Commits:** commit and push the folder about every 40 photos, so a cut-off run still leaves its work on the branch.
- **Scope:** touch nothing outside `docs/archive-outreach/cloud-photos-2026-11/`. The app code is wired up later, on George's Mac.
- **Pull request:** at the end, open one PR into `main` titled "Cloud photo search: N old photos for N landmarks". Its description should list:
  - the counts
  - the landmarks covered, grouped by city
  - any matches you're unsure of, and why
  - which sources were rate-limited
- Never push to main, never force-push, never merge.
