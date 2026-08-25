#!/usr/bin/env bash

set -euo pipefail

SRC="$HOME/.config/copyq/dfir-commands.ini"
DST="$HOME/.config/copyq/copyq-commands.ini"

[ -f "$SRC" ] || exit 0

mkdir -p "$(dirname "$DST")"

if [ ! -f "$DST" ]; then
    cp "$SRC" "$DST"
    exit 0
fi

if grep -q "dfir_auto_hash_tag" "$DST"; then
    exit 0
fi

python3 - "$SRC" "$DST" <<'PY'
from pathlib import Path
import sys
import re

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

source = src.read_text()
target = dst.read_text()

size = re.search(r"^size=(\d+)", target, re.MULTILINE)

if not size:
    raise SystemExit("copyq size missing")

old_size = int(size.group(1))
new_id = old_size + 1

source = source.replace("7\\", f"{new_id}\\")

target = target.replace(
    f"size={old_size}",
    f"size={new_id}"
)

target += "\n" + source.split("[Commands]\n",1)[1]

dst.write_text(target)
PY
