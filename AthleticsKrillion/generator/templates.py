"""Declarative question template library.

Each template describes a question shape and parameter choices. It does not
contain SQL. Query handlers will be implemented separately during validation.
"""

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class TemplateDefinition:
    slug: str
    family_key: str
    answer_entity_type: str
    relationship_key: str
    query_handler: str
    wording_template: str
    parameter_definitions: dict[str, Any]
    parameter_combinations: list[dict[str, Any]] | None = None
    minimum_answers: int = 10
    generation_rules: dict[str, Any] | None = None


TEMPLATES = [
    TemplateDefinition(
        slug="athlete_performance_threshold",
        family_key="performance",
        answer_entity_type="athlete",
        relationship_key="achieved_performance",
        query_handler="athlete_performance_threshold",
        wording_template="Name an athlete who has achieved {discipline} {condition} {threshold}.",
        parameter_definitions={},
        parameter_combinations=[
            {"discipline": "100m", "condition": "under", "threshold": "10.00 seconds"},
            {"discipline": "100m", "condition": "under", "threshold": "10.50 seconds"},
            {"discipline": "200m", "condition": "under", "threshold": "20.00 seconds"},
            {"discipline": "400m", "condition": "under", "threshold": "45.00 seconds"},
            {"discipline": "800m", "condition": "under", "threshold": "1:45.00"},
            {"discipline": "1500m", "condition": "under", "threshold": "3:30.00"},
            {"discipline": "5000m", "condition": "under", "threshold": "13:00.00"},
            {"discipline": "10000m", "condition": "under", "threshold": "27:00.00"},
            {"discipline": "marathon", "condition": "under", "threshold": "2:10:00"},
            {"discipline": "110m hurdles", "condition": "under", "threshold": "13.00 seconds"},
            {"discipline": "400m hurdles", "condition": "under", "threshold": "48.00 seconds"},
            {"discipline": "long jump", "condition": "over", "threshold": "8.00 metres"},
            {"discipline": "high jump", "condition": "over", "threshold": "2.30 metres"},
            {"discipline": "pole vault", "condition": "over", "threshold": "6.00 metres"},
            {"discipline": "triple jump", "condition": "over", "threshold": "17.00 metres"},
            {"discipline": "shot put", "condition": "over", "threshold": "20.00 metres"},
            {"discipline": "discus", "condition": "over", "threshold": "65.00 metres"},
            {"discipline": "javelin", "condition": "over", "threshold": "85.00 metres"}
        ],
    ),
    TemplateDefinition(
        slug="athlete_championship_medal",
        family_key="achievement",
        answer_entity_type="athlete",
        relationship_key="won_medal_at",
        query_handler="athlete_championship_medal",
        wording_template="Name an athlete who won a {medal} medal at the {competition}.",
        parameter_definitions={
            "medal": ["gold", "silver", "bronze"],
            "competition": [
                "Olympic Games", "World Athletics Championships",
                "World Indoor Championships", "European Athletics Championships",
                "Commonwealth Games"
            ],
        },
    ),
    TemplateDefinition(
        slug="athlete_championship_title",
        family_key="achievement",
        answer_entity_type="athlete",
        relationship_key="won_title_at",
        query_handler="athlete_championship_title",
        wording_template="Name an athlete who won an individual title at the {competition}.",
        parameter_definitions={
            "competition": [
                "Olympic Games", "World Athletics Championships",
                "World Indoor Championships", "European Athletics Championships"
            ],
        },
    ),
    TemplateDefinition(
        slug="athlete_appearances",
        family_key="participation",
        answer_entity_type="athlete",
        relationship_key="participated_in",
        query_handler="athlete_appearances",
        wording_template="Name an athlete who competed at {count} or more editions of the {competition}.",
        parameter_definitions={
            "count": [3, 4, 5, 6],
            "competition": [
                "Olympic Games", "World Athletics Championships",
                "European Athletics Championships", "Commonwealth Games"
            ],
        },
    ),
    TemplateDefinition(
        slug="athlete_multiple_representations",
        family_key="representation",
        answer_entity_type="athlete",
        relationship_key="represented_multiple_countries",
        query_handler="athlete_multiple_representations",
        wording_template="Name an athlete who has represented at least {count} different countries.",
        parameter_definitions={"count": [2, 3]},
    ),
    TemplateDefinition(
        slug="athlete_world_record_holder",
        family_key="records",
        answer_entity_type="athlete",
        relationship_key="held_record",
        query_handler="athlete_world_record_holder",
        wording_template="Name an athlete who has held a world record in {discipline}.",
        parameter_definitions={
            "discipline": [
                "100m", "200m", "400m", "800m", "1500m", "5000m",
                "10000m", "marathon", "long jump", "high jump",
                "pole vault", "shot put", "javelin"
            ],
        },
    ),
    TemplateDefinition(
        slug="competition_hosted_record",
        family_key="competition",
        answer_entity_type="competition_edition",
        relationship_key="hosted_record",
        query_handler="competition_hosted_record",
        wording_template="Name a competition meeting or edition at which a world record was set.",
        parameter_definitions={},
    ),
    TemplateDefinition(
        slug="venue_hosted_championship",
        family_key="geography",
        answer_entity_type="venue",
        relationship_key="hosted_competition",
        query_handler="venue_hosted_championship",
        wording_template="Name a venue that has hosted the {competition}.",
        parameter_definitions={
            "competition": [
                "Olympic Games", "World Athletics Championships",
                "World Indoor Championships", "European Athletics Championships"
            ],
        },
    ),
    TemplateDefinition(
        slug="country_olympic_medal",
        family_key="achievement",
        answer_entity_type="country",
        relationship_key="won_olympic_athletics_medal",
        query_handler="country_olympic_medal",
        wording_template="Name a country that has won an Olympic athletics {medal} medal.",
        parameter_definitions={"medal": ["gold", "silver", "bronze"]},
    ),
    TemplateDefinition(
        slug="country_multiple_medallists",
        family_key="aggregation",
        answer_entity_type="country",
        relationship_key="has_at_least_n_medallists",
        query_handler="country_multiple_medallists",
        wording_template="Name a country with at least {count} different Olympic athletics medallists.",
        parameter_definitions={"count": [5, 10, 20, 50]},
    ),
    TemplateDefinition(
        slug="athlete_multiple_world_medals",
        family_key="aggregation",
        answer_entity_type="athlete",
        relationship_key="has_at_least_n_medals",
        query_handler="athlete_multiple_world_medals",
        wording_template="Name an athlete who has won at least {count} medals at the World Athletics Championships.",
        parameter_definitions={"count": [3, 4, 5, 6]},
    ),
    TemplateDefinition(
        slug="athlete_achievement_since_year",
        family_key="historical",
        answer_entity_type="athlete",
        relationship_key="achieved_since_year",
        query_handler="athlete_achievement_since_year",
        wording_template="Name an athlete who won an Olympic athletics medal since {year}.",
        parameter_definitions={"year": [1980, 1992, 2000, 2008, 2012, 2016, 2020]},
    ),
]
