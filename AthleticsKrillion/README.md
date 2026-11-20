# Athletics Trivia — Question Generator (v1)

This starter project generates **question candidates** from a controlled template library and stores them in the Neon PostgreSQL schema designed for the project.

It does not yet query real athletics results or validate answers. That is the next stage.

## 1. Setup

1. Create a Neon PostgreSQL project.
2. Run the initial schema migration from `migrations/001_initial_schema.sql` (the schema we designed previously).
3. Copy `.env.example` to `.env` and add your Neon connection string.
4. Install dependencies:

```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
pip install -r requirements.txt
```

## 2. Generate questions

Preview candidates without connecting to Neon:

```bash
python -m generator.main --dry-run --limit 100
```

Seed the template registry and save generated candidates:

```bash
python -m generator.main --limit 500
```

The generator will:
- register/update the templates in `question_templates`;
- generate combinations from each template's parameter choices;
- create a stable candidate key to prevent duplicates;
- insert candidates into `question_candidates`.

## 3. Current template families

The initial library includes:
- performance thresholds (track, road, field and combined-event examples);
- championship medals and titles;
- Olympic and championship appearances;
- multiple-country representation;
- world-record history;
- competition and venue history;
- country achievements;
- historical/time-bounded questions;
- career achievement aggregations.

The thresholds and examples are deliberately configurable. They are starting points, not assertions that the database already contains the relevant facts.

## 4. Important current limitation

A generated candidate is **not automatically a valid game question**. It has not yet been checked against actual data, answer counts, source coverage or rarity suitability.

The next module should implement controlled query handlers for each `query_handler`, retrieve distinct answer entities, and produce a validation report. Questions should only become `approved` after that stage.

## 5. Adding a template

Add a `TemplateDefinition` to `generator/templates.py`. Use:
- a family key already present in the database;
- an answer entity type from `entity_types`;
- a stable `query_handler` name;
- a wording string using `{parameter_name}` placeholders;
- parameter choices in `parameter_definitions`.

Keep SQL out of template definitions. The Python query layer should own approved SQL statements.
