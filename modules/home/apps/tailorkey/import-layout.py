"""Reduce a Glove80 Layout Editor export to what render.py reads.

Usage: import-layout.py EXPORT.json [layout.json]

Drops account data (creator, uuid), notes and firmware snippets, so only
the key assignments end up in the repository.
"""

import json
import sys
from pathlib import Path


def main():
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).with_name("layout.json")
    d = json.loads(src.read_text())
    keep = {k: d[k] for k in ("title", "keyboard", "layer_names", "layers")}
    keep["combos"] = [
        {"name": c["name"], "binding": c["binding"], "keyPositions": c["keyPositions"], "layers": c.get("layers", [])}
        for c in d.get("combos", [])
    ]
    dst.write_text(json.dumps(keep, indent=1, ensure_ascii=False) + "\n")
    print(f"{dst}: {len(keep['layers'])} layers, {len(keep['combos'])} combos")


if __name__ == "__main__":
    main()
