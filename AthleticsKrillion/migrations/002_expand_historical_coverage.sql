-- 002_expand_historical_coverage.sql
-- Run after 001_initial_schema.sql in Neon.
-- Adds the competition hierarchy, source provenance and coverage tracking.
-- Existing edition-level records are preserved; no synthetic meetings are invented.

BEGIN;

-- 1. Shared entity catalogue and edition metadata.
INSERT INTO entity_types (key, display_name) VALUES
    ('meeting', 'Competition meeting'),
    ('meeting_event', 'Event contested at a meeting'),
    ('team', 'Athletics team')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE competition_editions
    ADD COLUMN IF NOT EXISTS edition_name TEXT,
    ADD COLUMN IF NOT EXISTS edition_code TEXT,
    ADD COLUMN IF NOT EXISTS edition_type TEXT NOT NULL DEFAULT 'edition';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'competition_editions_edition_type_check'
          AND conrelid = 'competition_editions'::regclass
    ) THEN
        ALTER TABLE competition_editions
            ADD CONSTRAINT competition_editions_edition_type_check
            CHECK (edition_type IN ('season', 'edition', 'championship', 'tour', 'other'));
    END IF;
END $$;

-- 2. A competition series can have an edition/season containing many meetings.
-- Examples: Diamond League -> 2024 season -> London / Brussels / Final.
-- Olympics -> Paris 2024 edition -> athletics meeting/programme.
CREATE TABLE IF NOT EXISTS competition_meetings (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id) ON DELETE CASCADE,
    competition_edition_id BIGINT NOT NULL
        REFERENCES competition_editions(entity_id) ON DELETE RESTRICT,
    meeting_code TEXT,
    meeting_number INTEGER,
    start_date DATE,
    end_date DATE,
    venue_id BIGINT REFERENCES venues(entity_id),
    location_id BIGINT REFERENCES locations(entity_id),
    meeting_stage TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_competition_meetings_edition
    ON competition_meetings(competition_edition_id);
CREATE INDEX IF NOT EXISTS idx_competition_meetings_dates
    ON competition_meetings(start_date, end_date);
CREATE UNIQUE INDEX IF NOT EXISTS uq_competition_meetings_edition_code
    ON competition_meetings(competition_edition_id, meeting_code)
    WHERE meeting_code IS NOT NULL;

-- 3. The actual discipline contest at a meeting, e.g. men's 1500m or women's javelin.
CREATE TABLE IF NOT EXISTS meeting_events (
    entity_id BIGINT PRIMARY KEY REFERENCES entities(id) ON DELETE CASCADE,
    meeting_id BIGINT NOT NULL
        REFERENCES competition_meetings(entity_id) ON DELETE CASCADE,
    discipline_id BIGINT NOT NULL
        REFERENCES disciplines(entity_id) ON DELETE RESTRICT,
    gender TEXT,
    event_category TEXT NOT NULL DEFAULT 'senior',
    event_variant TEXT,
    event_order INTEGER,
    notes TEXT,
    UNIQUE (meeting_id, discipline_id, gender, event_category, event_variant)
);

CREATE INDEX IF NOT EXISTS idx_meeting_events_meeting ON meeting_events(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_events_discipline ON meeting_events(discipline_id);

-- 4. More precise links for new imported performances/results.
-- Keep competition_edition_id for compatibility and edition-level queries.
ALTER TABLE performances
    ADD COLUMN IF NOT EXISTS meeting_id BIGINT
        REFERENCES competition_meetings(entity_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS meeting_event_id BIGINT
        REFERENCES meeting_events(entity_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS source_note TEXT;

ALTER TABLE competition_results
    ADD COLUMN IF NOT EXISTS meeting_id BIGINT
        REFERENCES competition_meetings(entity_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS meeting_event_id BIGINT
        REFERENCES meeting_events(entity_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS wind_speed NUMERIC(5,2),
    ADD COLUMN IF NOT EXISTS result_status TEXT NOT NULL DEFAULT 'valid',
    ADD COLUMN IF NOT EXISTS source_note TEXT;

CREATE INDEX IF NOT EXISTS idx_performances_meeting ON performances(meeting_id);
CREATE INDEX IF NOT EXISTS idx_performances_meeting_event ON performances(meeting_event_id);
CREATE INDEX IF NOT EXISTS idx_performances_athlete_discipline
    ON performances(athlete_id, discipline_id);
CREATE INDEX IF NOT EXISTS idx_competition_results_meeting ON competition_results(meeting_id);
CREATE INDEX IF NOT EXISTS idx_competition_results_meeting_event
    ON competition_results(meeting_event_id);
CREATE INDEX IF NOT EXISTS idx_competition_results_athlete
    ON competition_results(athlete_id);
CREATE INDEX IF NOT EXISTS idx_competition_results_edition
    ON competition_results(competition_edition_id);
CREATE INDEX IF NOT EXISTS idx_performances_edition
    ON performances(competition_edition_id);

-- 5. Additional historical/verification metadata.
ALTER TABLE athlete_representations
    ADD COLUMN IF NOT EXISTS representation_name TEXT,
    ADD COLUMN IF NOT EXISTS source_note TEXT;
CREATE INDEX IF NOT EXISTS idx_athlete_representations_athlete_years
    ON athlete_representations(athlete_id, start_year, end_year);

ALTER TABLE records
    ADD COLUMN IF NOT EXISTS record_scope TEXT,
    ADD COLUMN IF NOT EXISTS ratification_status TEXT NOT NULL DEFAULT 'ratified',
    ADD COLUMN IF NOT EXISTS source_note TEXT;

-- 6. Source catalogue and imported source-record identity.
CREATE TABLE IF NOT EXISTS data_sources (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    base_url TEXT,
    source_type TEXT NOT NULL DEFAULT 'website',
    licence_name TEXT,
    licence_url TEXT,
    terms_url TEXT,
    attribution_required BOOLEAN NOT NULL DEFAULT FALSE,
    access_notes TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS source_records (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id BIGINT NOT NULL REFERENCES data_sources(id) ON DELETE RESTRICT,
    source_record_key TEXT NOT NULL,
    source_url TEXT,
    source_updated_at TIMESTAMPTZ,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_payload JSONB NOT NULL DEFAULT '{}',
    UNIQUE (source_id, source_record_key)
);
CREATE INDEX IF NOT EXISTS idx_source_records_source ON source_records(source_id);

-- Polymorphic fact reference: fact_table + fact_id. The importer must verify
-- that the referenced row exists; PostgreSQL cannot FK this to several tables.
CREATE TABLE IF NOT EXISTS fact_provenance (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_record_id BIGINT NOT NULL
        REFERENCES source_records(id) ON DELETE CASCADE,
    fact_table TEXT NOT NULL,
    fact_id BIGINT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'unverified'
        CHECK (verification_status IN ('unverified', 'verified', 'disputed', 'rejected')),
    confidence NUMERIC(4,3)
        CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
    is_primary_source BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_record_id, fact_table, fact_id)
);
CREATE INDEX IF NOT EXISTS idx_fact_provenance_fact ON fact_provenance(fact_table, fact_id);
CREATE INDEX IF NOT EXISTS idx_fact_provenance_status ON fact_provenance(verification_status);

CREATE TABLE IF NOT EXISTS entity_source_links (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id BIGINT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    source_record_id BIGINT NOT NULL
        REFERENCES source_records(id) ON DELETE CASCADE,
    is_primary_source BOOLEAN NOT NULL DEFAULT FALSE,
    verification_status TEXT NOT NULL DEFAULT 'unverified'
        CHECK (verification_status IN ('unverified', 'verified', 'disputed', 'rejected')),
    notes TEXT,
    UNIQUE (entity_id, source_record_id)
);
CREATE INDEX IF NOT EXISTS idx_entity_source_links_source
    ON entity_source_links(source_record_id);

-- 7. Track how complete each imported data area is. Unknown/partial coverage
-- must never be treated as an exhaustive answer pool by the question validator.
CREATE TABLE IF NOT EXISTS data_coverage (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    coverage_key TEXT NOT NULL UNIQUE,
    data_domain TEXT NOT NULL,
    subject_type TEXT,
    subject_id BIGINT REFERENCES entities(id) ON DELETE SET NULL,
    scope JSONB NOT NULL DEFAULT '{}',
    coverage_status TEXT NOT NULL DEFAULT 'unknown'
        CHECK (coverage_status IN ('unknown', 'not_started', 'partial', 'complete', 'not_applicable')),
    records_imported BIGINT NOT NULL DEFAULT 0 CHECK (records_imported >= 0),
    records_expected BIGINT CHECK (records_expected IS NULL OR records_expected >= 0),
    coverage_percent NUMERIC(5,2)
        CHECK (coverage_percent IS NULL OR (coverage_percent >= 0 AND coverage_percent <= 100)),
    source_id BIGINT REFERENCES data_sources(id) ON DELETE SET NULL,
    checked_at TIMESTAMPTZ,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_data_coverage_domain_status
    ON data_coverage(data_domain, coverage_status);
CREATE INDEX IF NOT EXISTS idx_data_coverage_subject
    ON data_coverage(subject_type, subject_id);
CREATE INDEX IF NOT EXISTS idx_data_coverage_scope ON data_coverage USING GIN(scope);

CREATE TABLE IF NOT EXISTS question_candidate_coverage (
    candidate_id BIGINT NOT NULL
        REFERENCES question_candidates(id) ON DELETE CASCADE,
    coverage_id BIGINT NOT NULL
        REFERENCES data_coverage(id) ON DELETE RESTRICT,
    relevance TEXT NOT NULL DEFAULT 'required'
        CHECK (relevance IN ('required', 'supporting', 'informational')),
    PRIMARY KEY (candidate_id, coverage_id)
);
CREATE INDEX IF NOT EXISTS idx_question_candidate_coverage_coverage
    ON question_candidate_coverage(coverage_id);

-- 8. General lookup indexes.
CREATE INDEX IF NOT EXISTS idx_entities_type_name
    ON entities(entity_type, normalized_name);
CREATE INDEX IF NOT EXISTS idx_entity_aliases_normalized
    ON entity_aliases(normalized_alias);
CREATE INDEX IF NOT EXISTS idx_competition_editions_competition_year
    ON competition_editions(competition_id, edition_year);

-- 9. Document intended semantics in the database.
COMMENT ON TABLE competitions IS
    'Competition series or recurring identity, e.g. Olympic Games, World Championships, Diamond League.';
COMMENT ON TABLE competition_editions IS
    'A season or specific edition, e.g. Diamond League 2024 season or Paris 2024 Olympic Games.';
COMMENT ON TABLE competition_meetings IS
    'An individual meeting/stage within an edition or season, e.g. London Diamond League 2024 or the Diamond League Final.';
COMMENT ON TABLE meeting_events IS
    'A specific discipline contest held at a meeting, e.g. mens 1500m or womens javelin.';
COMMENT ON TABLE data_coverage IS
    'Tracks completeness of imported data. Partial/unknown coverage is not an exhaustive answer pool.';
COMMENT ON TABLE fact_provenance IS
    'Links imported fact rows to source records, verification status and confidence.';

COMMIT;
