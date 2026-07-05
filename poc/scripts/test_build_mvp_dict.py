#!/usr/bin/env python3
"""Unit tests for build_mvp_dict.parse_translation POS parsing."""

from __future__ import annotations

import re
import unittest

from build_mvp_dict import (
    CORPUS_POS_RE,
    build_aliases,
    meaning_objects,
    parse_exchange_field,
    parse_translation,
)

MEAN_TRANSLATION = """\
a. 卑劣的, 吝啬的, 简陋的, 刻薄的, 平均的, 平庸的, 中等的, 普通的
vt. 意谓, 想要, 预定, 预定
vi. 用意, 有倾向
n. 平均数, 中间, 折衷"""

NAME_TRANSLATION = """\
n. 名字, 名称, 名誉, 名人, 名义, 文件名
vt. 取名, 称呼, 提名, 任命, 列举
a. 著名的, 据以取名
[计] 名字, 文件名, 命名"""

IN_TRANSLATION = """\
prep. 在...期间, 在...之内, 处于...之中, 从事于, 按照, 穿着
adv. 进入, 朝里, 在里面, 在屋里
a. 在里面的, 在朝的
n. 执政者, 交情"""

VT_LINE = "vt. 意谓, 想要, 预定"


def assert_no_corpus_pos(senses: list[dict]) -> None:
    """Reject corpus-frequency tags like n:9, v:28, i:95."""
    for sense in senses:
        pos = sense.get("pos", "")
        if pos and CORPUS_POS_RE.match(pos):
            raise AssertionError(f"corpus-stat pos found: {pos!r}")


class ParseTranslationTests(unittest.TestCase):
    def test_mean_first_sense_is_adjective(self) -> None:
        senses = parse_translation(MEAN_TRANSLATION)
        self.assertTrue(senses)
        self.assertEqual(senses[0]["pos"], "a.")
        pos_set = {s["pos"] for s in senses}
        self.assertIn("vt.", pos_set)
        self.assertIn("vi.", pos_set)
        self.assertIn("n.", pos_set)
        assert_no_corpus_pos(senses)
        self.assertNotIn("n:9.", pos_set)

    def test_name_no_corpus_pos(self) -> None:
        senses = parse_translation(NAME_TRANSLATION)
        pos_set = {s["pos"] for s in senses}
        self.assertTrue("a." in pos_set or "[计]" in pos_set)
        assert_no_corpus_pos(senses)
        self.assertNotIn("v:28.", pos_set)

    def test_in_no_corpus_pos(self) -> None:
        senses = parse_translation(IN_TRANSLATION)
        pos_set = {s["pos"] for s in senses}
        self.assertIn("a.", pos_set)
        assert_no_corpus_pos(senses)
        self.assertNotIn("i:95.", pos_set)

    def test_vt_not_split_as_v_and_t(self) -> None:
        senses = parse_translation(VT_LINE)
        self.assertEqual(len(senses), 1)
        self.assertEqual(senses[0]["pos"], "vt.")
        pos_set = {s["pos"] for s in senses}
        self.assertNotIn("v.", pos_set)
        self.assertNotIn("t.", pos_set)

    def test_assert_no_corpus_pos_rejects_bad_tags(self) -> None:
        with self.assertRaises(AssertionError):
            assert_no_corpus_pos([{"pos": "n:9.", "meanings": meaning_objects(["x"])}])
        with self.assertRaises(AssertionError):
            assert_no_corpus_pos([{"pos": "v:28", "meanings": meaning_objects(["x"])}])

    def test_meaning_objects_primary_first(self) -> None:
        objs = meaning_objects(["a", "b", "c"])
        self.assertEqual(objs[0], {"text": "a", "primary": True})
        self.assertEqual(objs[1], {"text": "b", "primary": False})
        self.assertEqual(objs[2], {"text": "c", "primary": False})


class ExchangeAliasTests(unittest.TestCase):
    def test_parse_exchange_field(self) -> None:
        variants = parse_exchange_field("p:walked/d:walked/i:walking/3:walks/s:walks")
        self.assertEqual(
            variants,
            [
                ("p", "walked"),
                ("d", "walked"),
                ("i", "walking"),
                ("3", "walks"),
                ("s", "walks"),
            ],
        )

    def test_build_aliases_skips_lemma_keys(self) -> None:
        selected = {
            "walk": {
                "word": "walk",
                "exchange": "p:walked/d:walked/i:walking/3:walks/s:walks",
                "senses": [{"pos": "v.", "meanings": meaning_objects(["走"])}],
            },
            "walked": {
                "word": "walked",
                "exchange": "0:walk/1:walks",
                "senses": [{"pos": "v.", "meanings": meaning_objects(["走过"])}],
            },
        }
        aliases = build_aliases(selected)
        self.assertIn("walking", aliases)
        self.assertEqual(aliases["walking"]["lemma"], "walk")
        self.assertEqual(aliases["walking"]["exchangeKey"], "i")
        self.assertNotIn("walked", aliases)


if __name__ == "__main__":
    unittest.main()
