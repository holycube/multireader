#!/usr/bin/env python3
"""Validate mvp_dict.json schema and optional mvp_dict_aliases.json."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

MIN_ENTRIES = 8_000
MAX_ENTRIES = 10_500

CORPUS_POS_RE = re.compile(r"^[a-z]+:\d+\.?$", re.IGNORECASE)

REQUIRED_ALIAS_KEYS = frozenset({"lemma", "exchangeKey"})
VALID_EXCHANGE_KEYS = frozenset({"p", "d", "i", "3", "r", "t", "s"})

def validate_meaning(meaning: object, key: str, sense_idx: int, meaning_idx: int) -> list[str]:
    errors: list[str] = []
    label = f"{key} sense[{sense_idx}] meaning[{meaning_idx}]"
    if isinstance(meaning, str):
        errors.append(f"{label}: string meaning deprecated (use migrate_dict_meanings.py)")
        return errors
    if not isinstance(meaning, dict):
        errors.append(f"{label}: must be object with text/primary")
        return errors
    text = meaning.get("text")
    if not isinstance(text, str) or not text.strip():
        errors.append(f"{label}: text must be non-empty string")
    primary = meaning.get("primary")
    if primary is not None and not isinstance(primary, bool):
        errors.append(f"{label}: primary must be boolean when present")
    return errors


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    if not path.exists():
        return [f"File not found: {path}"]

    with path.open(encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, dict):
        errors.append("Root must be a JSON object")
        return errors

    count = len(data)
    if count < MIN_ENTRIES:
        errors.append(f"entryCount {count} < {MIN_ENTRIES}")
    if count > MAX_ENTRIES:
        errors.append(f"entryCount {count} > {MAX_ENTRIES}")

    sample_keys = list(data.keys())[:50]
    for key in sample_keys:
        entry = data[key]
        if not isinstance(entry, dict):
            errors.append(f"{key}: entry must be object")
            continue
        if entry.get("word") != key:
            errors.append(f"{key}: word field mismatch")
        senses = entry.get("senses")
        if not isinstance(senses, list) or not senses:
            errors.append(f"{key}: senses must be non-empty array")
            continue
        for sense_idx, sense in enumerate(senses):
            if not isinstance(sense, dict):
                errors.append(f"{key}: invalid sense")
                break
            meanings = sense.get("meanings")
            if not isinstance(meanings, list) or not meanings:
                errors.append(f"{key}: meanings must be non-empty")
                break
            for meaning_idx, meaning in enumerate(meanings):
                errors.extend(
                    validate_meaning(meaning, key, sense_idx, meaning_idx)
                )

    size_mb = path.stat().st_size / (1024 * 1024)
    print(f"Entries: {count}, Size: {size_mb:.2f} MB")

    corpus_hits: list[str] = []
    for key, entry in data.items():
        if not isinstance(entry, dict):
            continue
        for sense in entry.get("senses") or []:
            if not isinstance(sense, dict):
                continue
            pos = sense.get("pos") or ""
            if pos and CORPUS_POS_RE.match(pos):
                corpus_hits.append(f"{key}: pos={pos!r}")

    if corpus_hits:
        errors.append(
            f"corpus-stat pos in senses ({len(corpus_hits)} hits); "
            f"examples: {', '.join(corpus_hits[:10])}"
        )

    return errors


def validate_aliases(dict_data: dict, aliases_path: Path) -> list[str]:
    errors: list[str] = []
    if not aliases_path.exists():
        return errors

    with aliases_path.open(encoding="utf-8") as f:
        aliases = json.load(f)

    if not isinstance(aliases, dict):
        errors.append(f"{aliases_path}: root must be a JSON object")
        return errors

    for variant, meta in aliases.items():
        if not isinstance(variant, str) or not variant.strip():
            errors.append(f"{aliases_path}: invalid alias key {variant!r}")
            continue
        if not isinstance(meta, dict):
            errors.append(f"{variant}: alias entry must be object")
            continue

        missing = REQUIRED_ALIAS_KEYS - meta.keys()
        if missing:
            errors.append(f"{variant}: missing fields {sorted(missing)}")
            continue

        lemma = meta.get("lemma")
        exchange_key = meta.get("exchangeKey")
        if not isinstance(lemma, str) or not lemma.strip():
            errors.append(f"{variant}: lemma must be non-empty string")
            continue
        if lemma not in dict_data:
            errors.append(f"{variant}: lemma {lemma!r} not in dictionary")
        if variant == lemma:
            errors.append(f"{variant}: self-loop alias")
        if exchange_key not in VALID_EXCHANGE_KEYS:
            errors.append(f"{variant}: invalid exchangeKey {exchange_key!r}")

        phonetic = meta.get("phonetic")
        if phonetic is not None and (not isinstance(phonetic, str) or not phonetic.strip()):
            errors.append(f"{variant}: phonetic must be non-empty string when present")

    alias_mb = aliases_path.stat().st_size / (1024 * 1024)
    print(f"Aliases: {len(aliases)}, Size: {alias_mb:.2f} MB")

    return errors


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            f"Usage: {sys.argv[0]} <mvp_dict.json> [mvp_dict_aliases.json]",
            file=sys.stderr,
        )
        return 1
    path = Path(sys.argv[1])
    aliases_path = (
        Path(sys.argv[2])
        if len(sys.argv) == 3
        else path.parent / "mvp_dict_aliases.json"
    )

    with path.open(encoding="utf-8") as f:
        dict_data = json.load(f)

    errors = validate(path)
    if isinstance(dict_data, dict):
        errors.extend(validate_aliases(dict_data, aliases_path))
    else:
        errors.append("Root must be a JSON object")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
