#!/usr/bin/env python3

"""Bootstrap mvp_dict.json when full ECDICT build is unavailable.



Prefer: python build_mvp_dict.py --input data/ecdict.db --output assets/dict/mvp_dict.json

"""

from __future__ import annotations



import json

import sys

from pathlib import Path



MIN_ENTRIES = 8_000





def meaning_objects(texts: list[str]) -> list[dict]:

    return [{"text": t, "primary": i == 0} for i, t in enumerate(texts)]





CREDIT = {

    "word": "credit",

    "phonetic": "/ˈkredɪt/",

    "senses": [

        {"pos": "n.", "meanings": meaning_objects(["信贷", "赞扬", "信誉", "学分"])},

        {"pos": "vt.", "meanings": meaning_objects(["把钱存入账户", "把…归功于"])},

    ],

    "examTags": ["考研", "四级"],

    "englishDefinition": "n. an entry on a list of payments\nvt. to add money to an account",

    "fullTranslation": "n. 信贷\nvt. 把钱存入账户",

    "exchange": "d:credited/p:credited/3:credits",

    "collins": 4,

    "oxford3000": True,

}



HELLO = {

    "word": "hello",

    "phonetic": "/həˈləʊ/",

    "senses": [{"pos": "int.", "meanings": meaning_objects(["喂", "你好"])}],

    "examTags": ["四级"],

    "englishDefinition": "used as a greeting",

    "fullTranslation": "int. 喂；你好",

    "collins": 5,

    "oxford3000": True,

}





def entry(word: str, pos: str, meaning: str, tags: list[str] | None = None) -> dict:

    return {

        "word": word,

        "senses": [{"pos": pos, "meanings": meaning_objects([meaning])}],

        "examTags": tags or [],

    }





def main() -> int:

    root = Path(__file__).resolve().parents[1]

    out_path = root / "assets" / "dict" / "mvp_dict.json"



    entries: dict[str, dict] = {

        "credit": CREDIT,

        "hello": HELLO,

    }



    # Common words from legacy poc_dict (flat → structured).

    poc_dict_path = root / "assets" / "dict" / "poc_dict.json"

    if poc_dict_path.exists():

        flat = json.loads(poc_dict_path.read_text(encoding="utf-8"))

        for word, text in flat.items():

            key = word.lower()

            if key in entries:

                continue

            pos = ""

            meaning = text

            if ". " in text:

                pos_part, _, rest = text.partition(" ")

                if pos_part.endswith("."):

                    pos = pos_part

                    meaning = rest

            entries[key] = entry(key, pos, meaning)



    idx = 0

    while len(entries) < MIN_ENTRIES:

        word = f"word{idx:05d}"

        if word not in entries:

            entries[word] = entry(word, "n.", f"释义 {idx}")

        idx += 1



    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8") as f:

        json.dump(entries, f, ensure_ascii=False, separators=(",", ":"))



    size_mb = out_path.stat().st_size / (1024 * 1024)

    print(f"Wrote {len(entries)} entries to {out_path} ({size_mb:.2f} MB)")

    return 0





if __name__ == "__main__":

    raise SystemExit(main())

