"""Publish a playable question bank for the static OutsideLane frontend.

Only questions with actual verified answer entries are published. Template
candidates from generator.py are intentionally excluded until a query handler
has resolved and validated their answers.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from .generator import generate_candidates

ROOT = Path(__file__).resolve().parents[2]
SEED_RE = re.compile(r'<script type="application/json" id="officialSeed">([\s\S]*?)</script>')


def read_seed(path: Path) -> dict:
    if path.suffix.lower() == ".html":
        match = SEED_RE.search(path.read_text(encoding="utf-8"))
        if not match:
            raise ValueError("Missing officialSeed script in HTML")
        data = json.loads(match.group(1))
    else:
        data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Question source must be a JSON object")
    return data


def validate_bank(seed: dict) -> dict:
    sources = seed.get("sources")
    questions = seed.get("questions")
    if not isinstance(sources, dict) or not isinstance(questions, list):
        raise ValueError("Missing sources or questions")
    validated = []
    for index, question in enumerate(questions):
        if not isinstance(question, dict):
            raise ValueError(f"Question {index} is not an object")
        for key in ("group", "topic", "prompt", "source", "entries"):
            if key not in question:
                raise ValueError(f"Question {index} missing {key}")
        if question["source"] not in sources:
            raise ValueError(f"Question {index} has unknown source")
        if not isinstance(question["entries"], list) or not question["entries"]:
            raise ValueError(f"Question {index} has no verified answers")
        seen = set()
        for entry in question["entries"]:
            if not isinstance(entry, dict) or not isinstance(entry.get("name"), str) or not entry["name"].strip():
                raise ValueError(f"Question {index} contains an invalid answer")
            if not isinstance(entry.get("score"), (int, float)) or isinstance(entry["score"], bool) or not 0 <= entry["score"] <= 100:
                raise ValueError(f"Question {index} has an invalid score")
            if not isinstance(entry.get("aliases"), list) or any(not isinstance(alias, str) for alias in entry["aliases"]):
                raise ValueError(f"Question {index} has invalid aliases")
            name = " ".join(entry["name"].casefold().split())
            if name in seen:
                raise ValueError(f"Question {index} has a duplicate answer: {name}")
            seen.add(name)
        validated.append(question)
    return {
        "version": seed.get("version", "unknown"),
        "description": seed.get("description", ""),
        "sources": sources,
        "questions": validated,
    }


def publish(source: Path, output: Path) -> int:
    bank = validate_bank(read_seed(source))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(bank, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    return len(bank["questions"])


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish verified OutsideLane questions as static JSON.")
    parser.add_argument("--source", type=Path, default=ROOT / "index.html", help="HTML seed or verified-answer JSON source")
    parser.add_argument("--output", type=Path, default=ROOT / "data" / "question-bank.json")
    parser.add_argument("--candidates-output", type=Path, default=ROOT / "data" / "question-candidates.json", help="Unvalidated template candidates for editorial review")
    args = parser.parse_args()
    count = publish(args.source, args.output)
    print(f"Published {count} verified question sets to {args.output}")
    candidates = generate_candidates()
    args.candidates_output.parent.mkdir(parents=True, exist_ok=True)
    args.candidates_output.write_text(json.dumps({"status": "unvalidated", "playable": False, "candidates": candidates}, ensure_ascii=False, separators=(",", ":")) + "\\n", encoding="utf-8")
    print(f"Staged {len(candidates)} unvalidated generated questions for review; not served to players")


if __name__ == "__main__":
    main()
