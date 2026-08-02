# SignalDesk publishing package

This directory contains channel-specific drafts derived from the authoritative
[technical case study](../portfolio-writeup.md). Update factual claims in the
case study first, then propagate them here.

## Recommended publication order

1. Merge the case study and evidence assets into the GitHub repository.
2. Publish the permanent project page on cloudwithlucien.com.
3. Publish the Medium tutorial and set the portfolio page as its canonical URL
   if the platform permits it.
4. Publish the Substack edition as a subscriber-focused engineering note that
   links to the canonical project page and GitHub repository.
5. Publish the LinkedIn launch post linking to the portfolio page as the main
   call to action.

This order establishes one durable source and avoids four independent versions
drifting apart.

## Files

- `medium-article.md` — long educational implementation narrative.
- `substack-article.md` — newsletter-oriented engineering story.
- `portfolio-entry.md` — concise case-study copy and API field map.
- `linkedin-post.md` — launch post and suggested first comment.

## Image rules

Images are stored in `../assets/screenshots/`. Before uploading publicly:

- publish only the sanitized copies from `../assets/screenshots/`;
- keep raw captures locally in the ignored `../assets/screenshots/raw/` folder;
- crop browser address bars and personal controls where practical;
- never alter technical statuses, values, or workflow results;
- never commit raw captures that contain billing identifiers or account data;
- write alt text describing the evidence, not “screenshot of a screen.”
