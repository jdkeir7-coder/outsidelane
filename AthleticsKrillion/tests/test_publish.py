import json
import tempfile
import unittest
from pathlib import Path

from AthleticsKrillion.generator.publish import read_seed, validate_bank, publish, ROOT


class PublishTests(unittest.TestCase):
    def test_seed_can_be_published(self):
        source = read_seed(ROOT / "index.html")
        bank = validate_bank(source)
        self.assertGreaterEqual(len(bank["questions"]), 8)
        self.assertEqual(len(bank["questions"]), len(source["questions"]))

    def test_invalid_unverified_answer_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_bank({"sources": {"s": "https://example.com"}, "questions": [{
                "group": "x", "topic": "x", "prompt": "x", "source": "s", "entries": []
            }]})

    def test_json_output_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "bank.json"
            count = publish(ROOT / "index.html", output)
            self.assertEqual(len(json.loads(output.read_text())["questions"]), count)


if __name__ == "__main__":
    unittest.main()
