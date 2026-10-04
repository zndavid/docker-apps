"""Regression cases for the release-title rules imported into Radarr."""
import itertools
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREFERENCE = json.loads((ROOT / "radarr_custom_format.json").read_text())
REJECTION = json.loads((ROOT / "radarr_dv_only_custom_format.json").read_text())


def rule_match(spec, title):
    matched = re.search(spec["fields"]["value"], title) is not None
    return not matched if spec["negate"] else matched


def preference_matches(title):
    # All rules share one specification type. Radarr requires all required
    # rules and at least one matched rule in that type group.
    rules = PREFERENCE["specifications"]
    return all(rule_match(s, title) for s in rules if s["required"]) and any(
        rule_match(s, title) for s in rules
    )


def dv_only(title):
    return rule_match(REJECTION["specifications"][0], title)


class ReleaseTitleTests(unittest.TestCase):
    def test_hdr_dv_order_and_separators(self):
        for dv in ("DV", "DoVi", "DolbyVision", "Dolby.Vision", "Dolby_Vision"):
            for hdr in ("HDR", "HDR10", "HDR10+", "HDR10P", "HDR10Plus", "HDRPlus"):
                for separator in (".", "_", "-", " "):
                    for tokens in itertools.permutations((dv, hdr)):
                        title = separator.join(("Movie", *tokens, "2160p"))
                        with self.subTest(title=title):
                            self.assertTrue(preference_matches(title))
                            self.assertFalse(dv_only(title))

    def test_dv_only_is_rejected(self):
        for title in ("Movie.DV.2160p", "Movie_DoVi_2160p", "Movie.Dolby.Vision",
                      "movie.dv", "DV.Movie", "Movie.DV.HDRip", "Movie.DV.HDR100"):
            with self.subTest(title=title):
                self.assertTrue(dv_only(title))
                self.assertFalse(preference_matches(title))

    def test_plain_hdr_and_sdr(self):
        self.assertTrue(preference_matches("Movie.HDR10.2160p"))
        self.assertFalse(dv_only("Movie.HDR10.2160p"))
        for title in ("Movie.SDR.1080p", "Movie.1080p", "Movie.HLG", "Movie.HDR10.SDR",
                      "Movie_HDR10_SDR", "Movie_HDR10_HLG"):
            with self.subTest(title=title):
                self.assertFalse(preference_matches(title))
                self.assertFalse(dv_only(title))

    def test_token_boundaries_and_shared_pattern(self):
        self.assertFalse(dv_only("Movie.DVD.1080p"))
        self.assertFalse(dv_only("Movie.Adventure.1080p"))
        exclusion = next(s for s in PREFERENCE["specifications"] if s["negate"] and "DV-only" in s["name"])
        self.assertEqual(exclusion["fields"]["value"], REJECTION["specifications"][0]["fields"]["value"])


if __name__ == "__main__":
    unittest.main()
