#!/usr/bin/env python3
"""
从 ECDICT SQLite/CSV 裁剪 MVP 词典 JSON（8k–10k 词条）。

选词策略（优先级合并去重，上限 10,000）：
1. tag 含 cet4 / cet6 / ky / ielts
2. oxford=1 或 collins>=4
3. 按 frq 升序补齐；不足 8k 时放宽 collins>=3

用法:
  python build_mvp_dict.py --input ../data/ecdict.db --output ../assets/dict/mvp_dict.json
  python build_mvp_dict.py --input ecdict.csv --output ../assets/dict/mvp_dict.json
  python build_mvp_dict.py --input ../data/ecdict.db --output ../assets/dict/mvp_dict.json \\
    --include-exchange-aliases --aliases-output ../assets/dict/mvp_dict_aliases.json
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sqlite3
import sys
from pathlib import Path

MAX_ENTRIES = 10_000
MIN_ENTRIES = 8_000

EXAM_TAG_MAP = {
    "ky": "考研",
    "cet4": "四级",
    "cet6": "六级",
    "ielts": "雅思",
}

PRIORITY_TAGS = tuple(EXAM_TAG_MAP.keys())

VALID_EXCHANGE_KEYS = frozenset({"p", "d", "i", "3", "r", "t", "s"})

POS_LINE_RE = re.compile(
    r"^((?:vt|vi|adj|adv|prep|conj|pron|aux|modal|art|num|int|pl|pref|n|v|a)\.?)\s*(.+)$",
    re.IGNORECASE,
)
DOMAIN_LINE_RE = re.compile(r"^\[([^\]]+)\]\s*(.+)$")
CORPUS_POS_RE = re.compile(r"^[a-z]+:\d+\.?$", re.IGNORECASE)


def parse_exam_tags(tag_field: str | None) -> list[str]:
    if not tag_field:
        return []
    tokens = tag_field.lower().split()
    labels: list[str] = []
    for key in PRIORITY_TAGS:
        if key in tokens and EXAM_TAG_MAP[key] not in labels:
            labels.append(EXAM_TAG_MAP[key])
    return labels


def split_meanings(text: str) -> list[str]:
    parts = re.split(r"[；;，,、]", text)
    return [p.strip() for p in parts if p.strip()]


def meaning_objects(texts: list[str], primary_count: int = 1) -> list[dict]:
    """Build {text, primary} meaning list; first [primary_count] are primary."""
    return [
        {"text": text, "primary": i < primary_count}
        for i, text in enumerate(texts)
    ]


def parse_translation(translation: str | None) -> list[dict]:
    if not translation or not translation.strip():
        return []

    lines = [ln.strip() for ln in translation.splitlines() if ln.strip()]
    if not lines:
        lines = [translation.strip()]

    senses: list[dict] = []

    for line in lines:
        pos = ""
        text = line
        match = POS_LINE_RE.match(line)
        if match:
            pos = match.group(1).lower()
            if not pos.endswith("."):
                pos = f"{pos}."
            text = match.group(2)
        else:
            domain_match = DOMAIN_LINE_RE.match(line)
            if domain_match:
                pos = f"[{domain_match.group(1)}]"
                text = domain_match.group(2)

        meanings = split_meanings(text)
        if meanings:
            senses.append({"pos": pos, "meanings": meaning_objects(meanings)})

    # merge same pos
    merged: dict[str, list[str]] = {}
    order: list[str] = []
    for sense in senses:
        pos = sense["pos"]
        if pos not in merged:
            merged[pos] = []
            order.append(pos)
        for m in sense["meanings"]:
            text = m["text"] if isinstance(m, dict) else m
            if text not in merged[pos]:
                merged[pos].append(text)

    return [
        {"pos": pos, "meanings": meaning_objects(merged[pos])}
        for pos in order
        if merged[pos]
    ]


def row_to_entry(row: dict) -> dict | None:
    word = (row.get("word") or "").strip().lower()
    if not word:
        return None

    translation = row.get("translation") or ""
    definition = row.get("definition") or ""
    senses = parse_translation(translation)

    if not senses and translation.strip():
        senses = [{"pos": "", "meanings": meaning_objects([translation.strip()])}]

    collins_raw = row.get("collins")
    try:
        collins = int(collins_raw) if collins_raw not in (None, "", "0") else None
    except ValueError:
        collins = None

    oxford_raw = row.get("oxford")
    oxford3000 = str(oxford_raw) in ("1", "True", "true")

    try:
        frq = int(row.get("frq") or 0)
    except ValueError:
        frq = 0
    if frq <= 0:
        frq = 999_999

    return {
        "_frq": frq,
        "_collins": collins or 0,
        "_oxford": oxford3000,
        "_tags": (row.get("tag") or "").lower(),
        "entry": {
            "word": word,
            "phonetic": (row.get("phonetic") or "").strip() or None,
            "senses": senses,
            "examTags": parse_exam_tags(row.get("tag")),
            "englishDefinition": definition.strip() or None,
            "fullTranslation": translation.strip() or None,
            "exchange": (row.get("exchange") or "").strip() or None,
            "collins": collins,
            "oxford3000": oxford3000,
        },
    }


def priority_score(meta: dict) -> tuple[int, int, int]:
  """Lower is higher priority."""
  tags = meta["_tags"]
  tier = 3
  if any(t in tags for t in PRIORITY_TAGS):
      tier = 0
  elif meta["_oxford"] or meta["_collins"] >= 4:
      tier = 1
  elif meta["_collins"] >= 3:
      tier = 2
  return (tier, meta["_frq"], meta["_collins"] * -1)


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
        reader = csv.DictReader(f)
        return list(reader)


def select_entries(raw_rows: list[dict]) -> dict[str, dict]:
    candidates: dict[str, dict] = {}

    for row in raw_rows:
        parsed = row_to_entry(row)
        if parsed is None:
            continue
        word = parsed["entry"]["word"]
        existing = candidates.get(word)
        if existing is None or priority_score(parsed) < priority_score(existing):
            candidates[word] = parsed

    # tier buckets
    tier0: list[dict] = []
    tier1: list[dict] = []
    tier2: list[dict] = []
    tier3: list[dict] = []

    for meta in candidates.values():
        score = priority_score(meta)
        if score[0] == 0:
            tier0.append(meta)
        elif score[0] == 1:
            tier1.append(meta)
        elif score[0] == 2:
            tier2.append(meta)
        else:
            tier3.append(meta)

    for bucket in (tier0, tier1, tier2, tier3):
        bucket.sort(key=priority_score)

    ordered = tier0 + tier1 + tier2 + tier3
    selected: dict[str, dict] = {}
    for meta in ordered:
        word = meta["entry"]["word"]
        if word in selected:
            continue
        selected[word] = meta["entry"]
        if len(selected) >= MAX_ENTRIES:
            break

    if len(selected) < MIN_ENTRIES:
        print(
            f"Warning: only {len(selected)} entries selected (target>={MIN_ENTRIES})",
            file=sys.stderr,
        )

    return selected


def strip_nulls(obj: dict) -> dict:
    return {k: v for k, v in obj.items() if v is not None and v != [] and v != ""}


def parse_exchange_field(exchange: str | None) -> list[tuple[str, str]]:
    """Parse ECDICT exchange into (exchangeKey, variantWord) pairs."""
    if not exchange or not exchange.strip():
        return []
    variants: list[tuple[str, str]] = []
    for part in exchange.split("/"):
        part = part.strip()
        if not part:
            continue
        colon = part.find(":")
        if colon <= 0:
            continue
        key = part[:colon].strip()
        value = part[colon + 1 :].strip().lower()
        if not value or key not in VALID_EXCHANGE_KEYS:
            continue
        variants.append((key, value))
    return variants


def build_phonetic_index(raw_rows: list[dict]) -> dict[str, str]:
    index: dict[str, str] = {}
    for row in raw_rows:
        word = (row.get("word") or "").strip().lower()
        phonetic = (row.get("phonetic") or "").strip()
        if word and phonetic and word not in index:
            index[word] = phonetic
    return index


def build_aliases(
    selected: dict[str, dict],
    raw_rows: list[dict] | None = None,
) -> dict[str, dict]:
    """Build variant→lemma alias map; skip variants that are lemma keys."""
    phonetics = build_phonetic_index(raw_rows) if raw_rows else {}
    aliases: dict[str, dict] = {}
    lemma_keys = set(selected.keys())

    for lemma, entry in selected.items():
        for exchange_key, variant in parse_exchange_field(entry.get("exchange")):
            if variant in lemma_keys or variant in aliases:
                continue
            record: dict[str, str] = {"lemma": lemma, "exchangeKey": exchange_key}
            phonetic = phonetics.get(variant)
            if phonetic:
                record["phonetic"] = phonetic
            aliases[variant] = record

    return aliases


def main() -> int:
    parser = argparse.ArgumentParser(description="Build MVP dictionary JSON from ECDICT")
    parser.add_argument("--input", required=True, help="ECDICT sqlite or csv path")
    parser.add_argument("--output", required=True, help="Output mvp_dict.json path")
    parser.add_argument(
        "--include-exchange-aliases",
        action="store_true",
        help="Also write mvp_dict_aliases.json from exchange fields",
    )
    parser.add_argument(
        "--aliases-output",
        help="Output path for alias JSON (required with --include-exchange-aliases)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)
    if not input_path.exists():
        print(f"Input not found: {input_path}", file=sys.stderr)
        return 1

    suffix = input_path.suffix.lower()
    if suffix == ".csv":
        raw_rows = load_csv(input_path)
    else:
        raw_rows = load_sqlite(input_path)

    print(f"Loaded {len(raw_rows)} raw rows from {input_path}")
    selected = select_entries(raw_rows)
    print(f"Selected {len(selected)} entries")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(selected, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"Wrote {output_path} ({size_mb:.2f} MB)")

    if args.include_exchange_aliases:
        if not args.aliases_output:
            print(
                "ERROR: --aliases-output is required with --include-exchange-aliases",
                file=sys.stderr,
            )
            return 1
        aliases = build_aliases(selected, raw_rows)
        aliases_path = Path(args.aliases_output)
        aliases_path.parent.mkdir(parents=True, exist_ok=True)
        with aliases_path.open("w", encoding="utf-8") as f:
            json.dump(aliases, f, ensure_ascii=False, separators=(",", ":"))
        alias_mb = aliases_path.stat().st_size / (1024 * 1024)
        print(f"Wrote {aliases_path} ({len(aliases)} aliases, {alias_mb:.2f} MB)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
