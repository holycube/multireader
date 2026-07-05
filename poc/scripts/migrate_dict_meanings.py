#!/usr/bin/env python3

"""Migrate mvp_dict.json meanings from string[] to {text, primary} objects."""



from __future__ import annotations



import argparse

import json

import sys

from pathlib import Path





def migrate_meanings(meanings: list) -> list[dict]:

    if not meanings:

        return []

    if isinstance(meanings[0], dict):

        return meanings

    return [

        {"text": text, "primary": i == 0}

        for i, text in enumerate(meanings)

        if isinstance(text, str) and text.strip()

    ]





def migrate_dict(data: dict) -> tuple[dict, int]:

    migrated_senses = 0

    for entry in data.values():

        if not isinstance(entry, dict):

            continue

        senses = entry.get("senses")

        if not isinstance(senses, list):

            continue

        for sense in senses:

            if not isinstance(sense, dict):

                continue

            raw = sense.get("meanings")

            if not isinstance(raw, list) or not raw:

                continue

            if isinstance(raw[0], str):

                sense["meanings"] = migrate_meanings(raw)

                migrated_senses += 1

    return data, migrated_senses





def main() -> int:

    parser = argparse.ArgumentParser(

        description="Migrate dict meanings to {text, primary} format"

    )

    parser.add_argument(

        "path",

        nargs="?",

        default="poc/assets/dict/mvp_dict.json",

        help="Path to mvp_dict.json",

    )

    args = parser.parse_args()



    path = Path(args.path)

    if not path.exists():

        print(f"File not found: {path}", file=sys.stderr)

        return 1



    with path.open(encoding="utf-8") as f:

        data = json.load(f)



    if not isinstance(data, dict):

        print("Root must be a JSON object", file=sys.stderr)

        return 1



    data, count = migrate_dict(data)



    with path.open("w", encoding="utf-8") as f:

        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))



    print(f"Migrated {count} senses in {path}")

    return 0





if __name__ == "__main__":

    raise SystemExit(main())

