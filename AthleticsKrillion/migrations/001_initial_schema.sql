-- Initial schema from the project design.
-- Run this once in the Neon SQL Editor before running the Python generator.

CREATE TABLE IF NOT EXISTS entity_types (
    key TEXT PRIMARY KEY,
    display_name TEXT NOT NULL
);

INSERT INTO entity_types (key, display_name) VALUES
    ('athlete', 'Athlete'),
    ('country', 'Country'),
    ('discipline', 'Athletics discipline'),
    ('competition', 'Competition'),
    ('competition_edition', 'Competition edition'),
    ('venue', 'Venue'),
    ('location', 'Location')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS entities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type TEXT NOT NULL REFERENCES entity_types(key),
    canonical_name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (entity_type, normalized_name)
);

CREATE TABLE IF NOT EXISTS entity_aliases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id BIGINT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    alias TEXT NOT NULL,
    normalized_alias TEXT NOT NULL,
    UNIQUE (entity_id, normalized_alias)
);

CREATE TABLE IF NOT EXISTS athletes (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    gender TEXT,
    birth_date DATE,
    death_date DATE
);

CREATE TABLE IF NOT EXISTS countries (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    iso_code CHAR(3) UNIQUE
);

CREATE TABLE IF NOT EXISTS locations (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    country_id BIGINT REFERENCES countries(entity_id),
    region TEXT
);

CREATE TABLE IF NOT EXISTS venues (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    location_id BIGINT REFERENCES locations(entity_id)
);

CREATE TABLE IF NOT EXISTS disciplines (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    discipline_group TEXT NOT NULL,
    measurement_type TEXT NOT NULL,
    standard_unit TEXT NOT NULL,
    indoor_eligible BOOLEAN DEFAULT FALSE,
    outdoor_eligible BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS competitions (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    competition_type TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS competition_editions (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id),
    competition_id BIGINT NOT NULL REFERENCES competitions(entity_id),
    edition_year INTEGER,
    start_date DATE,
    end_date DATE,
    venue_id BIGINT REFERENCES venues(entity_id),
    location_id BIGINT REFERENCES locations(entity_id)
);

CREATE TABLE IF NOT EXISTS athlete_representations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    athlete_id BIGINT NOT NULL REFERENCES athletes(entity_id),
    country_id BIGINT NOT NULL REFERENCES countries(entity_id),
    start_year INTEGER,
    end_year INTEGER
);

CREATE TABLE IF NOT EXISTS performances (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    athlete_id BIGINT NOT NULL REFERENCES athletes(entity_id),
    discipline_id BIGINT NOT NULL REFERENCES disciplines(entity_id),
    competition_edition_id BIGINT REFERENCES competition_editions(entity_id),
    performance_value NUMERIC(14,5) NOT NULL,
    unit TEXT NOT NULL,
    performance_date DATE,
    wind_speed NUMERIC(5,2),
    result_status TEXT DEFAULT 'valid'
);

CREATE TABLE IF NOT EXISTS competition_results (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    athlete_id BIGINT NOT NULL REFERENCES athletes(entity_id),
    discipline_id BIGINT NOT NULL REFERENCES disciplines(entity_id),
    competition_edition_id BIGINT NOT NULL REFERENCES competition_editions(entity_id),
    performance_id BIGINT REFERENCES performances(id),
    placing INTEGER,
    medal TEXT,
    round_name TEXT,
    CHECK (medal IS NULL OR medal IN ('gold', 'silver', 'bronze'))
);

CREATE TABLE IF NOT EXISTS records (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    discipline_id BIGINT NOT NULL REFERENCES disciplines(entity_id),
    record_type TEXT NOT NULL,
    performance_id BIGINT REFERENCES performances(id),
    ratified_date DATE,
    held_from DATE,
    held_until DATE
);

CREATE TABLE IF NOT EXISTS question_template_families (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT
);

INSERT INTO question_template_families (key, name, description) VALUES
    ('achievement', 'Achievements', 'Medals, titles and victories'),
    ('performance', 'Performances', 'Times, distances and heights'),
    ('participation', 'Participation', 'Appearances and competition entries'),
    ('records', 'Records', 'World, continental and other records'),
    ('representation', 'Representation', 'Nationalities and countries represented'),
    ('competition', 'Competition history', 'Competitions and meetings'),
    ('geography', 'Geography', 'Venues, locations and hosting'),
    ('historical', 'Historical', 'Time-based and historical questions'),
    ('aggregation', 'Aggregations', 'Career totals and calculated statistics')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS question_templates (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    family_id BIGINT NOT NULL REFERENCES question_template_families(id),
    answer_entity_type TEXT NOT NULL REFERENCES entity_types(key),
    relationship_key TEXT NOT NULL,
    query_handler TEXT NOT NULL,
    wording_template TEXT NOT NULL,
    parameter_definitions JSONB NOT NULL DEFAULT '{}',
    generation_rules JSONB NOT NULL DEFAULT '{}',
    minimum_answers INTEGER NOT NULL DEFAULT 10,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS question_candidates (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    template_id BIGINT NOT NULL REFERENCES question_templates(id),
    candidate_key TEXT NOT NULL UNIQUE,
    question_text TEXT NOT NULL,
    parameters JSONB NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'generated'
        CHECK (status IN ('generated', 'validated', 'rejected', 'approved')),
    answer_count INTEGER NOT NULL DEFAULT 0,
    coverage_status TEXT NOT NULL DEFAULT 'unknown'
        CHECK (coverage_status IN ('unknown', 'partial', 'complete')),
    validation_report JSONB NOT NULL DEFAULT '{}',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    validated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS question_candidate_answers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_id BIGINT NOT NULL REFERENCES question_candidates(id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES entities(id),
    evidence JSONB NOT NULL DEFAULT '{}',
    UNIQUE (candidate_id, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_question_templates_active
    ON question_templates(active, family_id);
CREATE INDEX IF NOT EXISTS idx_question_candidates_status
    ON question_candidates(status, generated_at);
