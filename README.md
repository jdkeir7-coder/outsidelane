# OUTSIDELANE

**Think outside the box. Run obscure.**

OUTSIDELANE is an athletics rarity-trivia game. Players have **8 questions**, **25 seconds per question**, and compete for up to **800 metres**, with rare valid answers scoring more.

## Play / develop locally

Open `index.html` in a browser. The current demo is a single-file static site, with the game, styles, scripts, and sample answer database embedded in the page. No build tool or environment variables are required.

## Current features

- Desktop-friendly start-to-race transition and mobile-responsive layout
- Eight questions across World Athletics, European Athletics, USATF, Diamond League, British Athletics, World Marathon Majors and world top lists
- Typo-tolerant answer matching and suggested corrections for indexed answers
- Retro pixel-art runner and athletics track with dot-matrix scoreboard
- Eight-split result card; click an individual split to explore accepted answers by score tier
- Download/shareable spoiler-free result image
- Daily attempt recorded in the browser, with practice mode

## Important limitations of this prototype

- Some official-source-backed athlete datasets are curated **subsets** and may omit valid niche answers.
- Rarity points are **illustrative** until enough player-response data has been collected.
- Game state is stored on the device; there is currently no shared player database or global leaderboard.

## Deployment

Deploy this repository as a **static site** with the root directory as the publish path; `index.html` is the entry point. For Render, use an empty/no-op build command and publish path `.`.

This is an independent fan-created prototype and is not affiliated with the sport's governing bodies.
