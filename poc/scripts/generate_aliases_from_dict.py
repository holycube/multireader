#!/usr/bin/env python3
"""Generate mvp_dict_aliases.json from an existing mvp_dict.json (no ECDICT required)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from build_mvp_dict import build_aliases


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            f"Usage: {sys.argv[0]} <mvp_dict.json> [mvp_dict_aliases.json]",
            file=sys.stderr,
        )
        return 1

    dict_path = Path(sys.argv[1])
    aliases_path = (
        Path(sys.argv[2])
        if len(sys.argv) == 3
        else dict_path.parent / "mvp_dict_aliases.json"
    )

    selected = json.loads(dict_path.read_text(encoding="utf-8"))
    aliases = build_aliases(selected, None)
    aliases_path.write_text(
        json.dumps(aliases, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    size_mb = aliases_path.stat().st_size / (1024 * 1024)
    print(f"Wrote {aliases_path} ({len(aliases)} aliases, {size_mb:.2f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
