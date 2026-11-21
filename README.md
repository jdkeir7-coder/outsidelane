# OUTSIDELANE

**Think outside the box. Run obscure.**

OUTSIDELANE is an athletics rarity-trivia game. Players have **8 questions**, **25 seconds per question**, and compete for up to **800 metres**, with rare valid answers scoring more.

## Play / develop locally

Open `index.html` in a browser. The site loads the published `data/question-bank.json` when hosted, falling back to its embedded verified seed offline. No browser secrets or database credentials are needed.

## Current features

- Desktop-friendly start-to-race transition and mobile-responsive layout
- Eight questions across World Athletics, European Athletics, USATF, Diamond League, British Athletics, World Marathon Majors and world top lists
- Typo-tolerant answer matching and suggested corrections for indexed answers
- Retro pixel-art runner and athletics track with dot-matrix scoreboard
- Eight-split result card; click an individual split to explore accepted answers by score tier
- Download/shareable spoiler-free result image
- One daily attempt recorded per device; a single downward-arrow button starts today's heat

## Question creation and publishing

- `AthleticsKrillion/generator/templates.py` defines candidate question patterns. Run `PYTHONPATH=AthleticsKrillion python -m generator.main --dry-run` to preview candidate generation, or supply `DATABASE_URL` server-side to save candidates to Neon (existing database schema required).
- `python -m AthleticsKrillion.generator.publish` checks the embedded verified answer sets and writes `data/question-bank.json` for the game. Pass `--source /path/to/verified-questions.json` to use a separately reviewed and fully answered question dataset instead.
- The same publisher stages template-generated questions in `data/question-candidates.json` with `playable: false`. **Candidates do not enter the game until their correct-answer datasets and sources have been validated.** Current Neon candidate records only contain wording and parameters, not answer lists; there is not yet an automatic Neon-to-playable-question validator.
- The GitHub Action `Publish OutsideLane questions` runs the tests and publisher on relevant commits or manual dispatch, committing updated JSON. The browser reads the published playable bank before starting the day's eight-question heat; if unavailable it uses the embedded version.
- To add playable questions, provide a JSON object with `sources` and `questions`, each question containing `group`, `topic`, `prompt`, `source`, and nonempty `entries` containing `name`, `score` (0–100), and `aliases` (array). The existing daily selector currently requires the established 33-slot bank ordering; extending selection logic to new question families remains separate work.

## Important limitations of this prototype

- Some official-source-backed athlete datasets are curated **subsets** and may omit valid niche answers.
- Rarity points are **illustrative** until enough player-response data has been collected.
- Game state is stored on the device; there is currently no shared player database or global leaderboard.

## Deployment

Deploy this repository as a **static site** with the root directory as the publish path; `index.html` is the entry point. For Render, use an empty/no-op build command and publish path `.`.

This is an independent fan-created prototype and is not affiliated with the sport's governing bodies.
