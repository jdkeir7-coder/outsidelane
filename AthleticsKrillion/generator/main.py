import argparse

from .generator import generate_candidates


def main():
    parser = argparse.ArgumentParser(description="Generate athletics trivia question candidates.")
    parser.add_argument("--limit", type=int, default=500, help="Maximum candidates to generate.")
    parser.add_argument("--dry-run", action="store_true", help="Preview only; do not connect to Neon.")
    args = parser.parse_args()

    candidates = generate_candidates(limit=args.limit)

    print(f"Generated {len(candidates)} candidate questions.\n")
    for index, candidate in enumerate(candidates[:30], start=1):
        print(f"{index:>3}. [{candidate['template_slug']}] {candidate['question_text']}")
    if len(candidates) > 30:
        print(f"... and {len(candidates) - 30} more.")

    if args.dry_run:
        print("\nDry run complete. Nothing was saved.")
        return

    from .database import connect, save_candidates, seed_templates

    with connect() as conn:
        seed_templates(conn)
        inserted = save_candidates(conn, candidates)

    print(f"\nSaved {inserted} new candidates to Neon.")
    print(f"Skipped {len(candidates) - inserted} candidates already present.")


if __name__ == "__main__":
    main()
