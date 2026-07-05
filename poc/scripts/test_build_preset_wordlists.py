#!/usr/bin/env python3
"""Unit tests for build_preset_wordlists."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from build_preset_wordlists import (
    TIER_TARGETS,
    build_incremental_lists,
    build_word_index,
    has_any_tag,
    normalize_word,
    parse_tag_tokens,
    row_to_meta,
    select_tier_words,
)


def _meta(word: str, frq: int, tags: str, collins: int = 0, oxford: bool = False):
    from build_preset_wordlists import WordMeta

    return WordMeta(
        word=word,
        frq=frq,
        collins=collins,
        oxford=oxford,
        tags=parse_tag_tokens(tags),
    )


class NormalizeWordTests(unittest.TestCase):
    def test_lowercase_and_trim_edges(self) -> None:
        self.assertEqual(normalize_word("Hello"), "hello")
        self.assertEqual(normalize_word('"world"'), "world")
        self.assertEqual(normalize_word("(test)"), "test")

    def test_preserves_internal_apostrophe(self) -> None:
        self.assertEqual(normalize_word("don't"), "don't")

    def test_strips_edge_apostrophe(self) -> None:
        self.assertEqual(normalize_word("'hello'"), "hello")


class TagMatchingTests(unittest.TestCase):
    def test_parse_tag_tokens(self) -> None:
        self.assertEqual(parse_tag_tokens("zk gk cet4"), frozenset({"zk", "gk", "cet4"}))

    def test_has_any_tag(self) -> None:
        meta = _meta("apple", 10, "gk cet4")
        self.assertTrue(has_any_tag(meta, ("gk", "cet4")))
        self.assertFalse(has_any_tag(meta, ("cet6",)))


class RowToMetaTests(unittest.TestCase):
    def test_row_to_meta_normalizes_word(self) -> None:
        meta = row_to_meta({"word": "  Hello  ", "tag": "cet4", "frq": "100"})
        assert meta is not None
        self.assertEqual(meta.word, "hello")
        self.assertEqual(meta.frq, 100)
        self.assertIn("cet4", meta.tags)


class SelectionTests(unittest.TestCase):
    def test_incremental_files_do_not_overlap(self) -> None:
        rows = [
            {"word": f"w{i}", "tag": "cet4", "frq": i}
            for i in range(1, 5_001)
        ]
        rows += [
            {"word": f"c{i}", "tag": "cet6", "frq": i}
            for i in range(1, 2_001)
        ]
        rows += [
            {"word": f"t{i}", "tag": "ielts", "frq": i}
            for i in range(1, 3_001)
        ]
        rows += [
            {"word": f"a{i}", "tag": "ky", "frq": i}
            for i in range(1, 5_001)
        ]

        all_words = build_word_index(rows)
        incremental = build_incremental_lists(all_words)

        seen: set[str] = set()
        cumulative = 0
        for filename, target, _ in TIER_TARGETS:
            words = incremental[filename]
            self.assertTrue(
                all(word not in seen for word in words),
                f"overlap in {filename}",
            )
            seen.update(words)
            cumulative += len(words)
            self.assertEqual(cumulative, target, filename)

    def test_select_tier_respects_cumulative_target(self) -> None:
        all_words = {
            f"w{i}": _meta(f"w{i}", i, "cet4") for i in range(1, 100)
        }
        selected: set[str] = set()
        added = select_tier_words(all_words, selected, 50, ("cet4",))
        self.assertEqual(len(added), 50)
        self.assertEqual(len(selected), 50)

    def test_backfill_when_tag_pool_insufficient(self) -> None:
        all_words = {
            "alpha": _meta("alpha", 1, "cet4"),
            "beta": _meta("beta", 2, "", collins=5, oxford=True),
            "gamma": _meta("gamma", 3, "", collins=1),
        }
        selected: set[str] = set()
        added = select_tier_words(all_words, selected, 3, ("cet4",))
        self.assertEqual(added, ["alpha", "beta", "gamma"])


class WriteIntegrationTests(unittest.TestCase):
    def test_main_script_writes_four_files(self) -> None:
        import csv
        import sys
        from unittest.mock import patch

        rows = [
            {"word": f"w{i}", "tag": "gk cet4", "frq": i, "collins": 3}
            for i in range(1, 5_001)
        ]
        rows += [
            {"word": f"c{i}", "tag": "cet6", "frq": i}
            for i in range(1, 2_001)
        ]
        rows += [
            {"word": f"t{i}", "tag": "toefl", "frq": i}
            for i in range(1, 3_001)
        ]
        rows += [
            {"word": f"a{i}", "tag": "gre", "frq": i}
            for i in range(1, 5_001)
        ]

        with tempfile.TemporaryDirectory() as tmp:
            csv_path = Path(tmp) / "sample.csv"
            with csv_path.open("w", encoding="utf-8", newline="") as f:
                writer = csv.DictWriter(
                    f, fieldnames=["word", "tag", "frq", "collins", "oxford"]
                )
                writer.writeheader()
                writer.writerows(rows)

            out_dir = Path(tmp) / "presets"
            with patch.object(
                sys,
                "argv",
                [
                    "build_preset_wordlists.py",
                    "--input",
                    str(csv_path),
                    "--output-dir",
                    str(out_dir),
                ],
            ):
                from build_preset_wordlists import main as run_main

                self.assertEqual(run_main(), 0)

            cumulative = 0
            for filename, target, _ in TIER_TARGETS:
                path = out_dir / filename
                self.assertTrue(path.exists(), filename)
                lines = [ln for ln in path.read_text(encoding="utf-8").splitlines() if ln]
                self.assertGreater(len(lines), 0, filename)
                cumulative += len(lines)
            self.assertEqual(cumulative, 12_000)


if __name__ == "__main__":
    unittest.main()
