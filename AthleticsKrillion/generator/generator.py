from __future__ import annotations

from dataclasses import asdict
from hashlib import sha256
from itertools import product
import json
import re
from typing import Iterable

from .templates import TemplateDefinition, TEMPLATES


def _slugify(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def expand_template(template: TemplateDefinition) -> Iterable[dict]:
    """Yield parameter dictionaries for every configured combination."""
    if template.parameter_combinations is not None:
        yield from template.parameter_combinations
        return

    definitions = template.parameter_definitions
    if not definitions:
        yield {}
        return

    keys = list(definitions.keys())
    values = [definitions[key] for key in keys]
    for combination in product(*values):
        yield dict(zip(keys, combination))


def render_question(template: TemplateDefinition, parameters: dict) -> str:
    return template.wording_template.format(**parameters)


def make_candidate_key(template_slug: str, parameters: dict) -> str:
    canonical = json.dumps(
        {"template": template_slug, "parameters": parameters},
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    )
    digest = sha256(canonical.encode("utf-8")).hexdigest()[:24]
    return f"{_slugify(template_slug)}-{digest}"


def generate_candidates(templates=TEMPLATES, limit: int | None = None) -> list[dict]:
    candidates = []
    for template in templates:
        for parameters in expand_template(template):
            candidates.append({
                "template_slug": template.slug,
                "candidate_key": make_candidate_key(template.slug, parameters),
                "question_text": render_question(template, parameters),
                "parameters": parameters,
            })
            if limit is not None and len(candidates) >= limit:
                return candidates
    return candidates
