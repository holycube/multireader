#!/usr/bin/env python3
"""
从 ECDICT SQLite/CSV 生成分层预置词表（增量 txt）。

累积目标（与 PRD 一致）：
  cet4.txt      → 4,500（gk / cet4）
  + cet6.txt    → 6,000（cet6）
  + toefl.txt   → 8,000（ielts / toefl）
  + advanced.txt → 12,000（ky / gre，不足时 oxford / collins / frq 补齐）

用法:
  python build_preset_wordlists.py \\
    --input ../data/ecdict-extracted/stardict.db \\
    --output-dir ../assets/presets/
"""

from __future__ import annotations

import argparse
import csv
import re
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path

# 累积词数目标
TIER_TARGETS: list[tuple[str, int, tuple[str, ...]]] = [
    ("cet4.txt", 4_500, ("gk", "cet4")),
    ("cet6.txt", 6_000, ("cet6",)),
    ("toefl.txt", 8_000, ("ielts", "toefl")),
    ("advanced.txt", 12_000, ("ky", "gre")),
]

TOLERANCE_RATIO = 0.05

_LETTER_OR_DIGIT = re.compile(r"[\w]", re.UNICODE)


@dataclass(frozen=True)
class WordMeta:
    word: str
    frq: int
    collins: int
    oxford: bool
    tags: frozenset[str]


def _is_edge_punctuation(char: str) -> bool:
    if char == "'":
        return True
    return _LETTER_OR_DIGIT.match(char) is None


def normalize_word(raw: str) -> str:
    """对齐 poc/lib/vocab/word_normalizer.dart。"""
    lower = raw.lower()
    if not lower:
        return ""

    start = 0
    end = len(lower)
    while start < end and _is_edge_punctuation(lower[start]):
        start += 1
    while end > start and _is_edge_punctuation(lower[end - 1]):
        end -= 1
    return lower[start:end]


def parse_tag_tokens(tag_field: str | None) -> frozenset[str]:
    if not tag_field:
        return frozenset()
    return frozenset(tag_field.lower().split())


def parse_frq(value: object) -> int:
    try:
        frq = int(value or 0)
    except (TypeError, ValueError):
        frq = 0
    return frq if frq > 0 else 999_999


def parse_collins(value: object) -> int:
    try:
        collins = int(value) if value not in (None, "", "0") else 0
    except (TypeError, ValueError):
        collins = 0
    return collins


def parse_oxford(value: object) -> bool:
    return str(value) in ("1", "True", "true")


def row_to_meta(row: dict) -> WordMeta | None:
    word = normalize_word((row.get("word") or "").strip())
    if not word:
        return None
    return WordMeta(
        word=word,
        frq=parse_frq(row.get("frq")),
        collins=parse_collins(row.get("collins")),
        oxford=parse_oxford(row.get("oxford")),
        tags=parse_tag_tokens(row.get("tag")),
    )


def load_sqlite(path: Path) -> list[dict]:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")]
    table = "stardict" if "stardict" in tables else tables[0]
    rows = cur.execute(f"SELECT * FROM {table}").fetchall()
    conn.close()
    return [dict(r) for r in rows]


def load_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def build_word_index(raw_rows: list[dict]) -> dict[str, WordMeta]:
    """去重：同一词保留 frq 更优（更小）的条目。"""
    index: dict[str, WordMeta] = {}
    for row in raw_rows:
        meta = row_to_meta(row)
        if meta is None:
            continue
        existing = index.get(meta.word)
        if existing is None or meta.frq < existing.frq:
            index[meta.word] = meta
    return index


def has_any_tag(meta: WordMeta, keys: tuple[str, ...]) -> bool:
    return any(key in meta.tags for key in keys)


def tag_pool_sort_key(meta: WordMeta) -> tuple[int, int]:
    return (meta.frq, -meta.collins)


def backfill_sort_key(meta: WordMeta) -> tuple[int, int, int]:
    """oxford / collins 优先，再按 frq。"""
    tier = 3
    if meta.oxford or meta.collins >= 4:
        tier = 0
    elif meta.collins >= 3:
        tier = 1
    elif meta.collins >= 1:
        tier = 2
    return (tier, meta.frq, -meta.collins)


def select_tier_words(
    all_words: dict[str, WordMeta],
    selected: set[str],
    cumulative_target: int,
    tag_keys: tuple[str, ...],
) -> list[str]:
    added: list[str] = []

    tag_pool = [
        meta
        for meta in all_words.values()
        if meta.word not in selected and has_any_tag(meta, tag_keys)
    ]
    tag_pool.sort(key=tag_pool_sort_key)

    for meta in tag_pool:
        if len(selected) >= cumulative_target:
            break
        selected.add(meta.word)
        added.append(meta.word)

    if len(selected) < cumulative_target:
        needed = cumulative_target - len(selected)
        print(
            f"Warning: tag pool {tag_keys!r} short by {needed}; backfilling",
            file=sys.stderr,
        )
        backfill = [
            meta for meta in all_words.values() if meta.word not in selected
        ]
        backfill.sort(key=backfill_sort_key)
        for meta in backfill:
            if len(selected) >= cumulative_target:
                break
            selected.add(meta.word)
            added.append(meta.word)

    return sorted(added)


def build_incremental_lists(
    all_words: dict[str, WordMeta],
) -> dict[str, list[str]]:
    selected: set[str] = set()
    incremental: dict[str, list[str]] = {}

    for filename, cumulative_target, tag_keys in TIER_TARGETS:
        added = select_tier_words(all_words, selected, cumulative_target, tag_keys)
        incremental[filename] = added

    return incremental


def write_wordlists(incremental: dict[str, list[str]], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    cumulative = 0
    for filename, cumulative_target, _ in TIER_TARGETS:
        words = incremental[filename]
        cumulative += len(words)
        path = output_dir / filename
        path.write_text("\n".join(words) + ("\n" if words else ""), encoding="utf-8")
        print(f"Wrote {path.name}: +{len(words)} (cumulative {cumulative}, target {cumulative_target})")

        low = int(cumulative_target * (1 - TOLERANCE_RATIO))
        high = int(cumulative_target * (1 + TOLERANCE_RATIO))
        if cumulative < low or cumulative > high:
            print(
                f"Warning: cumulative {cumulative} for {filename} "
                f"outside ±{int(TOLERANCE_RATIO * 100)}% of {cumulative_target}",
                file=sys.stderr,
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build preset word lists from ECDICT")
    parser.add_argument("--input", required=True, help="ECDICT sqlite or csv path")
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Output directory for cet4/cet6/toefl/advanced txt files",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output_dir)
    if not input_path.exists():
        print(f"Input not found: {input_path}", file=sys.stderr)
        return 1

    suffix = input_path.suffix.lower()
    if suffix == ".csv":
        raw_rows = load_csv(input_path)
    else:
        raw_rows = load_sqlite(input_path)

    print(f"Loaded {len(raw_rows)} raw rows from {input_path}")
    all_words = build_word_index(raw_rows)
    print(f"Indexed {len(all_words)} unique normalized words")

    incremental = build_incremental_lists(all_words)
    write_wordlists(incremental, output_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
