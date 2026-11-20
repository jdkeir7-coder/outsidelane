import unittest

from generator.generator import (
    generate_candidates,
    make_candidate_key,
    render_question,
)
from generator.templates import TEMPLATES


class GeneratorTests(unittest.TestCase):
    def test_generates_candidates(self):
        candidates = generate_candidates()
        self.assertGreater(len(candidates), 0)

    def test_candidate_keys_are_stable(self):
        first = make_candidate_key("example", {"year": 2000})
        second = make_candidate_key("example", {"year": 2000})
        self.assertEqual(first, second)

    def test_candidate_keys_change_with_parameters(self):
        first = make_candidate_key("example", {"year": 2000})
        second = make_candidate_key("example", {"year": 2004})
        self.assertNotEqual(first, second)

    def test_wording_has_no_unfilled_placeholders(self):
        for candidate in generate_candidates():
            self.assertNotIn("{", candidate["question_text"])
            self.assertNotIn("}", candidate["question_text"])

    def test_limit_is_respected(self):
        self.assertEqual(len(generate_candidates(limit=7)), 7)


if __name__ == "__main__":
    unittest.main()
