"""Render a Glove80 Layout Editor (my.moergo.com) JSON export as one SVG per layer.

Usage: render.py layout.json OUTDIR
Writes NN-<layer>.svg for the layers in PAGES plus NN-combos.svg.
"""

import html
import json
import re
import sys
from pathlib import Path

# Layers worth a page (by name); the bilateral home-row-mod finger layers and
# the empty mouse speed layers are internal to TailorKey.
PAGES = ["HRM_WinLinx", "Cursor", "Symbol", "Mouse", "Lower", "Magic", "Gaming", "Autoshift", "Typing"]
TITLES = {"HRM_WinLinx": "Base"}

U = 64  # key pitch in px
KW = 0.92 * U  # key size

# Glove80 key index -> (column, row) on a 0..20 grid; the right half mirrors
# the left one.  Column stagger follows the key well (middle finger highest).
STAGGER = {0: 0.45, 1: 0.45, 2: 0.15, 3: 0.0, 4: 0.15, 5: 0.3}


def _pos():
    p = {}

    def left(idx, col, row):
        p[idx] = (col, row + STAGGER.get(col, 0))

    def right(idx, col, row):
        x, y = col, row + STAGGER.get(col, 0)
        p[idx] = (19.6 - x, y)

    for i in range(5):  # F row: columns 1..5
        left(i, i + 1, 0)
        right(9 - i, i + 1, 0)
    for r, base in ((1, 10), (2, 22), (3, 34)):
        for i in range(6):
            left(base + i, i, r)
            right(base + 11 - i, i, r)
    for i in range(6):
        left(46 + i, i, 4)
        right(63 - i, i, 4)
    for i in range(5):  # bottom row: columns 0..4
        left(64 + i, i, 5)
        right(79 - i, i, 5)
    # thumb clusters: upper 52-54 / 55-57, lower 69-71 / 72-74
    thumbs_l = {52: (6.5, 4.75), 53: (7.6, 5.05), 54: (8.7, 5.45), 69: (6.3, 5.95), 70: (7.4, 6.3), 71: (8.5, 6.7)}
    for k, (x, y) in thumbs_l.items():
        p[k] = (x, y)
    mirror = {55: 54, 56: 53, 57: 52, 72: 71, 73: 70, 74: 69}
    for k, src in mirror.items():
        x, y = thumbs_l[src]
        p[k] = (19.6 - x, y)
    return p


POS = _pos()


def where(idx):
    """Human description of a key position."""
    side = "links" if POS[idx][0] < 10 else "rechts"
    if idx in (52, 53, 54, 69, 70, 71, 55, 56, 57, 72, 73, 74):
        return f"Daumen {side}"
    if idx in range(64, 80):
        return f"unterste Reihe {side}"
    return side

NAMES = {
    **{f"N{i}": str(i) for i in range(10)},
    **{f"KP_N{i}": f"KP{i}" for i in range(10)},
    "SPACE": "␣ Space", "RET": "⏎ Enter", "ENTER": "⏎ Enter", "KP_ENTER": "KP ⏎",
    "BSPC": "⌫ Bksp", "DEL": "Del", "TAB": "⇥ Tab", "ESC": "Esc", "INS": "Ins",
    "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
    "LEFT_ARROW": "←", "RIGHT_ARROW": "→", "UP_ARROW": "↑", "DOWN_ARROW": "↓",
    "PG_UP": "PgUp", "PG_DN": "PgDn", "HOME": "Home", "END": "End",
    "LSHFT": "⇧ Shift", "RSHFT": "⇧ Shift", "LCTRL": "Ctrl", "RCTRL": "Ctrl",
    "LALT": "Alt", "RALT": "AltGr", "LGUI": "Win", "RGUI": "Win",
    "CAPS": "Caps", "K_APP": "Menu", "PRINTSCREEN": "Print", "SCROLLLOCK": "ScrLk",
    "PAUSE_BREAK": "Pause", "KP_NUM": "NumLk",
    "EQUAL": "=", "MINUS": "-", "BSLH": "\\", "FSLH": "/", "SEMI": ";", "SQT": "'",
    "SINGLE_QUOTE": "'", "GRAVE": "`", "COMMA": ",", "DOT": ".", "LBKT": "[", "RBKT": "]",
    "KP_SLASH": "KP /", "KP_MULTIPLY": "KP *", "KP_MINUS": "KP -", "KP_PLUS": "KP +", "KP_DOT": "KP .",
    "C_PP": "⏯ Play", "C_NEXT": "⏭ Next", "C_PREV": "⏮ Prev", "C_MUTE": "Mute",
    "C_VOL_UP": "Vol +", "C_VOL_DN": "Vol −", "C_BRI_UP": "Hell +", "C_BRI_DN": "Hell −",
    "LCLK": "L-Klick", "RCLK": "R-Klick", "MCLK": "M-Klick", "MB4": "Zurück", "MB5": "Vor",
    "MOVE_UP": "Maus ↑", "MOVE_DOWN": "Maus ↓", "MOVE_LEFT": "Maus ←", "MOVE_RIGHT": "Maus →",
    "SCRL_UP": "Rad ↑", "SCRL_DOWN": "Rad ↓", "SCRL_LEFT": "Rad ←", "SCRL_RIGHT": "Rad →",
}
SHIFTED = {
    "N1": "!", "N2": "@", "N3": "#", "N4": "$", "N5": "%", "N6": "^", "N7": "&", "N8": "*",
    "N9": "(", "N0": ")", "MINUS": "_", "EQUAL": "+", "LBKT": "{", "RBKT": "}", "BSLH": "|",
    "SEMI": ":", "SQT": '"', "SINGLE_QUOTE": '"', "GRAVE": "~", "COMMA": "<", "DOT": ">", "FSLH": "?",
}
MODS = {"LC": "Ctrl", "RC": "Ctrl", "LS": "Shift", "RS": "Shift", "LA": "Alt", "RA": "AltGr", "LG": "Win", "RG": "Win"}
MACROS = {
    "cur_SELECT_LINE": "Zeile wählen", "cur_SELECT_WORD": "Wort wählen",
    "cur_EXTEND_LINE": "Zeile +", "cur_EXTEND_WORD": "Wort +", "cur_SELECT_NONE": "Auswahl weg",
    "symb_dotdot": "../", "caps_word": "CapsWord", "bootloader": "Bootloader", "reset": "Reset",
}


def key(p):
    """Label of a keycode parameter such as {"value": "LC", "params": [...]}."""
    v = p.get("value")
    sub = p.get("params") or []
    if isinstance(v, int):
        return str(v)
    if v in MODS and sub:
        inner = sub[0]
        if v in ("LS", "RS") and not inner.get("params") and inner.get("value") in SHIFTED:
            return SHIFTED[inner["value"]]
        return f"{MODS[v]}+{key(inner)}"
    if v.startswith("RGB_"):
        return v[4:].title()
    return NAMES.get(v, v.replace("_", " ").title() if len(v) > 3 else v)


def clean(name):
    name = name.lstrip("&")
    name = re.sub(r"_v\d+[A-Z]?_TKZ$", "", name)
    return MACROS.get(name, name.replace("_", " "))


def binding(b, layer_names):
    """Return (tap, hold, kind) for one key binding."""
    v = b["value"]
    p = b.get("params") or []
    lname = lambda i: TITLES.get(layer_names[i], layer_names[i]) if isinstance(i, int) and i < len(layer_names) else str(i)
    if v == "&trans":
        return "▽", "", "trans"
    if v == "&none":
        return "", "", "none"
    if v == "&kp":
        return key(p[0]), "", "kp"
    if v in ("&mt",):
        return key(p[1]), key(p[0]), "hold"
    if v == "&lt":
        return key(p[1]), lname(p[0]["value"]), "layer"
    if v in ("&thumb_v2_TKZ", "&space_v3_TKZ"):
        return key(p[1]), lname(p[0]["value"]), "layer"
    if v.startswith("&HRM_") and len(p) == 2:
        return key(p[1]), key(p[0]), "hold"
    if v == "&mo":
        return "", lname(p[0]["value"]), "layer"
    if v == "&to":
        return "→ " + lname(p[0]["value"]), "", "layer"
    if v == "&tog":
        return "⇄ " + lname(p[0]["value"]), "", "layer"
    if v == "&sl":
        return "1× " + lname(p[0]["value"]), "", "layer"
    if v == "&sk":
        return "1× " + key(p[0]), "", "kp"
    if v == "&lower":
        return "", "Lower", "layer"
    if v == "&magic":
        return "", "Magic", "layer"
    if v in ("&mkp", "&mmv", "&msc"):
        return key(p[0]), "", "mouse"
    if v == "&rgb_ug":
        return "RGB " + key(p[0]), "", "sys"
    if v == "&bt":
        return {"BT_CLR": "BT löschen", "BT_CLR_ALL": "BT alle löschen"}.get(p[0]["value"], key(p[0])), "", "sys"
    if re.fullmatch(r"&bt_\d", v):
        return "BT " + v[-1], "", "sys"
    if v == "&out":
        return key(p[0]).replace("Out ", ""), "", "sys"
    if v in ("&bootloader", "&reset"):
        return clean(v), "", "sys"
    if v == "&AS_v1_TKZ":
        return key(p[0]), "auto-⇧", "kp"
    if v == "&mod_tab_chord_v2_TKZ":
        return key(p[0]) + "+Tab", "", "kp"
    # macros and other custom behaviours
    tap = clean(v)
    if p:
        tap += " " + " ".join(key(x) for x in p)
    return tap, "", "macro"


COLORS = {
    "bg": "#1a1b26", "key": "#24283b", "key_dim": "#1f2335", "border": "#3b4261",
    "fg": "#c0caf5", "dim": "#565f89", "hold": "#e0af68", "layer": "#7aa2f7",
    "mouse": "#9ece6a", "sys": "#f7768e", "macro": "#bb9af7", "act": "#ff9e64",
}


def wrap(text, width=9):
    words = text.split(" ")
    lines, cur = [], ""
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    lines.append(cur)
    return lines[:3]


def svg_page(title, subtitle, keys, highlight, notes):
    width, height = int(21.3 * U), int(9.9 * U)
    ox, oy = 0.5 * U, 1.35 * U
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect width="100%" height="100%" fill="{COLORS["bg"]}"/>',
        f'<style>text{{font-family:"DejaVu Sans",sans-serif;fill:{COLORS["fg"]}}}</style>',
        f'<text x="{ox}" y="{0.6 * U}" font-size="28" font-weight="bold">{html.escape(title)}</text>',
        f'<text x="{ox}" y="{1.0 * U}" font-size="16" fill="{COLORS["dim"]}" style="fill:{COLORS["dim"]}">{html.escape(subtitle)}</text>',
    ]
    for idx, (tap, hold, kind) in enumerate(keys):
        cx, cy = POS[idx]
        x, y = ox + cx * U, oy + cy * U
        fill = COLORS["key_dim"] if kind in ("none", "trans") else COLORS["key"]
        stroke = COLORS["act"] if idx in highlight else COLORS["border"]
        sw = 3 if idx in highlight else 1
        out.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{KW:.1f}" height="{KW:.1f}" rx="7" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
        color = {"trans": COLORS["dim"], "layer": COLORS["layer"], "mouse": COLORS["mouse"], "sys": COLORS["sys"], "macro": COLORS["macro"]}.get(kind, COLORS["fg"])
        lines = wrap(tap)
        size = 15 if max((len(line) for line in lines), default=0) <= 6 else 11
        top = y + KW / 2 - (len(lines) - 1) * size * 0.6 - (6 if hold else 0)
        for n, line in enumerate(lines):
            out.append(f'<text x="{x + KW / 2:.1f}" y="{top + n * size * 1.15 + size * 0.35:.1f}" font-size="{size}" text-anchor="middle" style="fill:{color}">{html.escape(line)}</text>')
        if hold:
            out.append(f'<text x="{x + KW / 2:.1f}" y="{y + KW - 6:.1f}" font-size="10" text-anchor="middle" style="fill:{COLORS["layer"] if kind == "layer" else COLORS["hold"]}">{html.escape(hold)}</text>')
    ny = oy + 7.75 * U
    for n, line in enumerate(notes[:4]):
        out.append(f'<text x="{ox}" y="{ny + n * 22:.1f}" font-size="15" style="fill:{COLORS["dim"]}">{html.escape(line)}</text>')
    out.append("</svg>")
    return "\n".join(out)


def main():
    src, outdir = Path(sys.argv[1]), Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    d = json.loads(src.read_text())
    names = d["layer_names"]
    layers = d["layers"]
    base = [binding(b, names) for b in layers[0]]
    label = lambda i: base[i][0] or base[i][1]

    # How each layer is reached: keys on the base layer that hold/toggle it,
    # Magic-layer &to entries, and combos.
    reach = {i: [] for i in range(len(names))}
    for idx, b in enumerate(layers[0]):
        v, p = b["value"], b.get("params") or []
        target = None
        if v in ("&thumb_v2_TKZ", "&space_v3_TKZ", "&lt", "&mo") and p:
            target = p[0].get("value")
        elif v == "&lower":
            target = names.index("Lower")
        elif v == "&magic":
            target = names.index("Magic")
        if isinstance(target, int):
            tap = base[idx][0]
            what = f"{tap}-Taste" if tap else f"{base[idx][1]}-Taste"
            reach[target].append((idx, f"Halten: {what} ({where(idx)})"))
    magic = names.index("Magic")
    for idx, b in enumerate(layers[magic]):
        if b["value"] == "&to":
            t = b["params"][0]["value"]
            reach[t].append((idx, f"Magic halten + Taste der Position „{label(idx)}“ (dauerhaft)"))
    combos = []
    for c in d.get("combos", []):
        tap = binding(c["binding"], names)[0]
        keys = " + ".join(
            f"{label(k)} ({where(k)})" if where(k).startswith("Daumen") else label(k) for k in c["keyPositions"]
        )
        combos.append(f"{keys}  →  {tap}")
        b = c["binding"]
        if b["value"] in ("&tog", "&to"):
            reach[b["params"][0]["value"]].append((c["keyPositions"][0], f"Combo {keys} (umschalten)"))

    n = 0
    for name in PAGES:
        if name not in names:
            continue
        li = names.index(name)
        keys = [binding(b, names) for b in layers[li]]
        how = reach.get(li, [])
        subtitle = " · ".join(h for _, h in how) if how else ("Grundebene" if li == 0 else "")
        if li == 0:
            subtitle = "Grundebene · unten klein: beim Halten (Mod/Layer)"
        highlight = {i for i, _ in how} if li != 0 else set()
        notes = []
        if li == 0:
            notes = ["Gelb = Halten (Home-Row-Mods), Blau = Layer, ▽ = durchgereicht, leer = keine Funktion",
                     "Esc schließt · ←/→ blättert · Combos auf der letzten Seite"]
        n += 1
        title = f"{n}/{len(PAGES) + 1}  {TITLES.get(name, name)}"
        (outdir / f"{n:02d}-{name}.svg").write_text(svg_page(title, subtitle, keys, highlight, notes))

    # combos page
    width, height = int(21.3 * U), int(9.9 * U)
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
             f'<rect width="100%" height="100%" fill="{COLORS["bg"]}"/>',
             f'<style>text{{font-family:"DejaVu Sans",sans-serif;fill:{COLORS["fg"]}}}</style>',
             f'<text x="{0.5 * U}" y="{0.6 * U}" font-size="28" font-weight="bold">{len(PAGES) + 1}/{len(PAGES) + 1}  Combos (gleichzeitig drücken)</text>']
    for i, c in enumerate(combos):
        lines.append(f'<text x="{0.5 * U}" y="{1.4 * U + i * 30}" font-size="20">{html.escape(c)}</text>')
    lines.append(f'<text x="{0.5 * U}" y="{1.4 * U + (len(combos) + 1) * 30}" font-size="15" style="fill:{COLORS["dim"]}">{html.escape(d.get("title", ""))}</text>')
    lines.append("</svg>")
    (outdir / f"{len(PAGES) + 1:02d}-combos.svg").write_text("\n".join(lines))


if __name__ == "__main__":
    main()
