import os

import psycopg
from psycopg.types.json import Jsonb
from dotenv import load_dotenv

from .templates import TEMPLATES


def connect():
    load_dotenv()
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        raise RuntimeError("DATABASE_URL is missing. Add it to your .env file.")
    return psycopg.connect(dsn)


def seed_templates(conn):
    """Upsert the Python template definitions into question_templates."""
    with conn.cursor() as cur:
        for template in TEMPLATES:
            cur.execute(
                "SELECT id FROM question_template_families WHERE key = %s",
                (template.family_key,),
            )
            family = cur.fetchone()
            if family is None:
                raise RuntimeError(
                    f"Missing question family '{template.family_key}'. "
                    "Run the schema migration first."
                )

            cur.execute(
                """
                INSERT INTO question_templates (
                    slug, family_id, answer_entity_type, relationship_key,
                    query_handler, wording_template, parameter_definitions,
                    generation_rules, minimum_answers, active
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
                ON CONFLICT (slug) DO UPDATE SET
                    family_id = EXCLUDED.family_id,
                    answer_entity_type = EXCLUDED.answer_entity_type,
                    relationship_key = EXCLUDED.relationship_key,
                    query_handler = EXCLUDED.query_handler,
                    wording_template = EXCLUDED.wording_template,
                    parameter_definitions = EXCLUDED.parameter_definitions,
                    generation_rules = EXCLUDED.generation_rules,
                    minimum_answers = EXCLUDED.minimum_answers,
                    active = TRUE
                """,
                (
                    template.slug,
                    family[0],
                    template.answer_entity_type,
                    template.relationship_key,
                    template.query_handler,
                    template.wording_template,
                    Jsonb(
                        {"combinations": template.parameter_combinations}
                        if template.parameter_combinations is not None
                        else template.parameter_definitions
                    ),
                    Jsonb(template.generation_rules or {}),
                    template.minimum_answers,
                ),
            )
    conn.commit()


def save_candidates(conn, candidates):
    inserted = 0
    with conn.cursor() as cur:
        for candidate in candidates:
            cur.execute(
                """
                INSERT INTO question_candidates (
                    template_id, candidate_key, question_text, parameters
                )
                SELECT id, %s, %s, %s
                FROM question_templates
                WHERE slug = %s AND active = TRUE
                ON CONFLICT (candidate_key) DO NOTHING
                RETURNING id
                """,
                (
                    candidate["candidate_key"],
                    candidate["question_text"],
                    Jsonb(candidate["parameters"]),
                    candidate["template_slug"],
                ),
            )
            if cur.fetchone() is not None:
                inserted += 1
    conn.commit()
    return inserted
