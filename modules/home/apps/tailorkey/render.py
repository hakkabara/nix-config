"""Render a Glove80 Layout Editor (my.moergo.com) export as cheat-sheet pages.

Usage: render.py layout.json OUTDIR
Writes NN-<name>.svg: one page per layer in PAGES, then the hotkey pages
(layer holds, mode switches and combos as small boards, in the style of
the TailorKey hotkey page: light key = hold, green key = tap).
"""

import html
import json
import re
import sys
from pathlib import Path

# Layers worth a page; the bilateral home-row-mod finger layers, the empty
# mouse speed layers and Typing (Base without mods) are left out.
PAGES = ["HRM_WinLinx", "Cursor", "Symbol", "Mouse", "Lower", "Magic", "Gaming", "Autoshift"]
TITLES = {"HRM_WinLinx": "Base", "MouseSlow": "Slow", "MouseFast": "Fast", "MouseWarp": "Warp"}

W, H = 1400, 730
P = 62  # key pitch (px) on layer pages
MIRROR = 19.14  # x of a left key centre + x of its mirrored right key centre
BOARD_W = 19.6

C = {
    "bg": "#1a1b26", "panel": "#1f2030", "fg": "#c0caf5", "dim": "#6b7399", "faint": "#3b4261",
    "hold": "#e0af68", "layer": "#7aa2f7", "mouse": "#9ece6a", "sys": "#f7768e", "macro": "#bb9af7",
    "accent": "#ff9e64", "tap": "#9ece6a", "held": "#c0caf5",
}
# Finger tints (fill, border): calm, low saturation on the dark background.
FINGERS = {
    "pinky": ("#2b2640", "#6a5a9c", "Kleiner Finger"),
    "ring": ("#1f2e49", "#4a76b8", "Ringfinger"),
    "middle": ("#1c3639", "#3f9a94", "Mittelfinger"),
    "index": ("#2a3524", "#78a456", "Zeigefinger"),
    "thumb": ("#3a2e23", "#b98a4c", "Daumen"),
}
FINGER_OF_COL = {0: "pinky", 1: "pinky", 2: "ring", 3: "middle", 4: "index", 5: "index"}


def _geometry():
    """Key index -> (centre x, centre y, rotation deg, finger), in key units.

    Follows the real Glove80 outline: only the two pinky columns sit half a
    key lower, the F row spans columns 0-4, the thumb keys fan out rotated.
    """
    g = {}

    def put(left_idx, right_idx, col, row):
        y = row + (0.48 if col < 2 else 0.0) + 0.43
        x = col + 0.43
        finger = FINGER_OF_COL[col]
        g[left_idx] = (x, y, 0, finger)
        g[right_idx] = (MIRROR - x, y, 0, finger)

    for i in range(5):
        put(i, 9 - i, i, 0)
    for row, base in ((1, 10), (2, 22), (3, 34)):
        for i in range(6):
            put(base + i, base + 11 - i, i, row)
    for i in range(6):
        put(46 + i, 63 - i, i, 4)
    for i in range(5):
        put(64 + i, 79 - i, i, 5)
    thumbs = {52: (6.36, 5.36), 53: (7.38, 6.02), 54: (8.38, 6.83), 69: (5.48, 6.07), 70: (6.6, 6.74), 71: (7.67, 7.55)}
    mirror = {52: 57, 53: 56, 54: 55, 69: 74, 70: 73, 71: 72}
    for idx, (x, y) in thumbs.items():
        g[idx] = (x, y, 28, "thumb")
        g[mirror[idx]] = (MIRROR - x, y, -28, "thumb")
    return g


GEO = _geometry()
THUMBS = {52, 53, 54, 55, 56, 57, 69, 70, 71, 72, 73, 74}

NAMES = {
    **{f"N{i}": str(i) for i in range(10)},
    **{f"KP_N{i}": f"KP{i}" for i in range(10)},
    "SPACE": "␣", "RET": "⏎", "ENTER": "⏎", "KP_ENTER": "KP ⏎",
    "BSPC": "⌫", "DEL": "⌦", "TAB": "⇥", "ESC": "Esc", "INS": "Insert",
    "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
    "LEFT_ARROW": "←", "RIGHT_ARROW": "→", "UP_ARROW": "↑", "DOWN_ARROW": "↓",
    "PG_UP": "PgUp", "PG_DN": "PgDn", "HOME": "Home", "END": "End",
    "LSHFT": "⇧", "RSHFT": "⇧", "LCTRL": "Ctrl", "RCTRL": "Ctrl",
    "LALT": "Alt", "RALT": "AltGr", "LGUI": "Win", "RGUI": "Win",
    "CAPS": "Caps", "K_APP": "Menu", "PRINTSCREEN": "Print", "SCROLLLOCK": "ScrLk",
    "PAUSE_BREAK": "Pause", "KP_NUM": "NumLk",
    "EQUAL": "=", "MINUS": "-", "BSLH": "\\", "FSLH": "/", "SEMI": ";", "SQT": "'",
    "SINGLE_QUOTE": "'", "GRAVE": "`", "COMMA": ",", "DOT": ".", "LBKT": "[", "RBKT": "]",
    "KP_SLASH": "KP /", "KP_MULTIPLY": "KP *", "KP_MINUS": "KP -", "KP_PLUS": "KP +", "KP_DOT": "KP .",
    "C_PP": "⏯", "C_NEXT": "⏭", "C_PREV": "⏮", "C_MUTE": "Mute",
    "C_VOL_UP": "Vol +", "C_VOL_DN": "Vol −", "C_BRI_UP": "☀ +", "C_BRI_DN": "☀ −",
    "LCLK": "Left click", "RCLK": "Right click", "MCLK": "Middle click", "MB4": "Back", "MB5": "Forward",
    "MOVE_UP": "Mouse ↑", "MOVE_DOWN": "Mouse ↓", "MOVE_LEFT": "Mouse ←", "MOVE_RIGHT": "Mouse →",
    "SCRL_UP": "Scroll ↑", "SCRL_DOWN": "Scroll ↓", "SCRL_LEFT": "Scroll ←", "SCRL_RIGHT": "Scroll →",
}
# Key faces as in the TailorKey documentation: a glyph gets its name as a
# small caption, a shortcut shows the action with the keys underneath.
CAPTIONS = {
    "⏎": "Enter", "⌫": "Backspace", "␣": "Space", "⇥": "Tab", "⇧": "Shift", "⌦": "Delete",
    "⏯": "Play", "⏭": "Next", "⏮": "Prev",
}
ACTIONS = {
    "Ctrl+X": "Cut", "Ctrl+C": "Copy", "Ctrl+V": "Paste", "Ctrl+Z": "Undo", "Ctrl+Y": "Redo",
    "Ctrl+A": "Select all", "Ctrl+F": "Find", "Ctrl+G": "Find next", "Ctrl+⇧+G": "Find prev",
    "Ctrl+H": "Replace", "⇧+Win+S": "Screenshot", "⇧+⇥": "Back tab",
}
# Plain names for running text (the glyphs alone are too terse there).
WORDS = {**CAPTIONS, "⌦": "Delete"}
SHIFTED = {
    "N1": "!", "N2": "@", "N3": "#", "N4": "$", "N5": "%", "N6": "^", "N7": "&", "N8": "*",
    "N9": "(", "N0": ")", "MINUS": "_", "EQUAL": "+", "LBKT": "{", "RBKT": "}", "BSLH": "|",
    "SEMI": ":", "SQT": '"', "SINGLE_QUOTE": '"', "GRAVE": "~", "COMMA": "<", "DOT": ">", "FSLH": "?",
}
MODS = {"LC": "Ctrl", "RC": "Ctrl", "LS": "⇧", "RS": "⇧", "LA": "Alt", "RA": "AltGr", "LG": "Win", "RG": "Win"}
MACROS = {
    "cur_SELECT_LINE": "Select line", "cur_SELECT_WORD": "Select word",
    "cur_EXTEND_LINE": "Extend line", "cur_EXTEND_WORD": "Extend word", "cur_SELECT_NONE": "Select none",
    "symb_dotdot": "../", "caps_word": "CapsWord", "bootloader": "Boot", "reset": "Reset",
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
        rest = key(inner)
        return rest if rest.startswith(MODS[v] + "+") else f"{MODS[v]}+{rest}"
    if v.startswith("RGB_"):
        return v[4:].title()
    return NAMES.get(v, v.replace("_", " ").title() if len(v) > 3 else v)


def clean(name):
    name = re.sub(r"_v\d+[A-Z]?_TKZ$", "", name.lstrip("&"))
    return MACROS.get(name, name.replace("_", " "))


def binding(b, names):
    """Return (tap, hold, kind) for one key binding."""
    v = b["value"]
    p = b.get("params") or []

    def lname(i):
        return TITLES.get(names[i], names[i]) if isinstance(i, int) and i < len(names) else str(i)

    if v == "&trans":
        return "▽", "", "trans"
    if v == "&none":
        return "", "", "none"
    if v == "&kp":
        return key(p[0]), "", "kp"
    if v == "&mt":
        return key(p[1]), key(p[0]), "hold"
    if v in ("&lt", "&thumb_v2_TKZ", "&space_v3_TKZ"):
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
    if v == "&caps_word":
        return "CapsWord", "", "macro"
    tap = clean(v)
    if p:
        tap += " " + " ".join(key(x) for x in p)
    return tap, "", "macro"


def face(tap):
    """Split a tap label into (main, caption) for the key face."""
    if tap in ACTIONS:
        return ACTIONS[tap], tap
    if tap in CAPTIONS:
        return tap, CAPTIONS[tap]
    return tap, ""


def esc(text):
    return html.escape(str(text))


def wrap(text, width):
    lines, cur = [], ""
    for word in text.split(" "):
        if cur and len(cur) + 1 + len(word) > width:
            lines.append(cur)
            cur = word
        else:
            cur = f"{cur} {word}".strip()
    lines.append(cur)
    return lines


def text(x, y, s, size, color, anchor="start", weight="normal"):
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" text-anchor="{anchor}" '
        f'font-weight="{weight}" style="fill:{color}">{esc(s)}</text>'
    )


def header(page_no, tabs, subtitle):
    """Tab strip with the page keys (1-9, 0) and the line how to reach the layer."""
    out = [f'<rect x="0" y="0" width="{W}" height="58" fill="{C["panel"]}"/>']
    x = 24
    for n, name in enumerate(tabs, start=1):
        label = f"{n % 10} {name}"
        width = 22 + len(label) * 8.6
        active = n == page_no
        if active:
            out.append(f'<rect x="{x:.1f}" y="13" width="{width:.1f}" height="32" rx="16" fill="{C["layer"]}"/>')
        out.append(text(x + width / 2, 34.5, label, 15, C["bg"] if active else C["dim"], "middle", "bold" if active else "normal"))
        x += width + 8
    out.append(text(W / 2, 92, subtitle, 17, C["fg"], "middle"))
    return out


def footer(items, hint="1–9, 0 = Seite · ← → blättern · Esc schließt"):
    """Legend chips (colour, label) on the left, the key hint on the right."""
    out, x, y = [], 28, H - 26
    for color, label in items:
        out.append(f'<rect x="{x}" y="{y - 12}" width="16" height="16" rx="4" fill="{color[0]}" stroke="{color[1]}"/>')
        out.append(text(x + 23, y + 1, label, 13, C["dim"]))
        x += 36 + len(label) * 7.4
    out.append(text(W - 28, y + 1, hint, 13, C["dim"], "end"))
    return out


def key_shape(cx, cy, size, rot, fill, stroke, sw=1.2, radius=None):
    r = radius if radius is not None else size * 0.16
    rect = (
        f'<rect x="{-size / 2:.1f}" y="{-size / 2:.1f}" width="{size:.1f}" height="{size:.1f}" '
        f'rx="{r:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
    )
    return f'<g transform="translate({cx:.1f},{cy:.1f}) rotate({rot})">{rect}</g>'


def layer_page(page_no, tabs, subtitle, keys, highlight):
    ox = (W - BOARD_W * P) / 2
    oy = 118
    out = header(page_no, tabs, subtitle)
    size = P * 0.9
    for idx, (tap, hold, kind) in enumerate(keys):
        ux, uy, rot, finger = GEO[idx]
        cx, cy = ox + ux * P, oy + uy * P
        fill, stroke, _ = FINGERS[finger]
        if kind == "none":
            fill, stroke = "#1c1d2a", "#2a2c40"
        hot = idx in highlight
        out.append(key_shape(cx, cy, size, rot, fill, C["accent"] if hot else stroke, 3 if hot else 1.2))
        color = {
            "trans": C["faint"], "layer": C["layer"], "mouse": C["mouse"], "sys": C["sys"], "macro": C["macro"],
        }.get(kind, C["fg"])
        main, caption = face(tap)
        longest = max((len(w) for w in main.split(" ")), default=0)
        if len(main) <= 2:
            fs, lines = 21, [main]
        elif len(main) <= 5:
            fs, lines = 15, [main]
        else:
            fs = 11 if longest <= 8 else 9
            lines = wrap(main, 8)[: 2 if caption else 3]
        # Stack: main lines, caption, then the hold label at the bottom edge.
        block = len(lines) * fs * 1.16 + (11 if caption else 0)
        top = cy - block / 2 - (7 if hold else 0)
        for n, line in enumerate(lines):
            out.append(text(cx, top + n * fs * 1.16 + fs * 0.86, line, fs, color, "middle"))
        if caption:
            out.append(text(cx, top + len(lines) * fs * 1.16 + 9.5, caption, 9, C["dim"], "middle"))
        if hold:
            # Rotated thumb keys: keep the hold label inside the diamond.
            hy = cy + (17 if rot else size / 2 - 6)
            out.append(text(cx, hy, hold, 10, C["layer"] if kind == "layer" else C["hold"], "middle"))
    legend = [((FINGERS[f][0], FINGERS[f][1]), FINGERS[f][2]) for f in ("pinky", "ring", "middle", "index", "thumb")]
    out += footer(legend)
    out.append(text(28, H - 52, "klein unten = beim Halten (gelb Mod, blau Layer) · ▽ durchgereicht · dunkel = keine Funktion", 13, C["dim"]))
    return out


def mini_board(x, y, pitch, held, tapped):
    """Small outline board: light = hold, green = tap, as on the TailorKey page."""
    out = []
    for idx, (ux, uy, rot, _) in GEO.items():
        if idx in held:
            fill, stroke = C["held"], C["held"]
        elif idx in tapped:
            fill, stroke = C["tap"], C["tap"]
        else:
            fill, stroke = "none", C["faint"]
        out.append(key_shape(x + ux * pitch, y + uy * pitch, pitch * 0.82, rot, fill, stroke, 1))
    return out


def hotkey_page(page_no, tabs, cards):
    out = header(page_no, tabs, "Hotkeys: Layer, Modi und Combos")
    pitch = 16
    card_w, card_h = 330, 268
    gap = (W - 4 * card_w) / 5
    for n, card in enumerate(cards):
        col, row = n % 4, n // 4
        x = gap + col * (card_w + gap)
        y = 116 + row * (card_h + 14)
        out.append(f'<rect x="{x:.1f}" y="{y}" width="{card_w}" height="{card_h}" rx="14" fill="{C["panel"]}"/>')
        out.append(text(x + 16, y + 30, card["title"], 17, C["fg"], weight="bold"))
        out += mini_board(x + (card_w - BOARD_W * pitch) / 2, y + 44, pitch, card["held"], card["tapped"])
        for i, line in enumerate(card["lines"][:3]):
            out.append(text(x + 16, y + 208 + i * 19, line, 13, C["dim"] if i else C["fg"]))
    out += footer([((C["held"], C["held"]), "halten"), ((C["tap"], C["tap"]), "tippen / gleichzeitig drücken")])
    return out


def svg(body):
    return "\n".join(
        [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
            f'<rect width="100%" height="100%" fill="{C["bg"]}"/>',
            '<style>text{font-family:"DejaVu Sans",sans-serif}</style>',
            *body,
            "</svg>",
        ]
    )


def word(label):
    return WORDS.get(label, label)


def main():
    src, outdir = Path(sys.argv[1]), Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    d = json.loads(src.read_text())
    names, layers = d["layer_names"], d["layers"]
    rendered = [[binding(b, names) for b in layer] for layer in layers]

    def label(idx, layer=0):
        tap, hold, _ = rendered[layer][idx]
        return word(tap or hold)

    def side(idx):
        where = "links" if GEO[idx][0] < MIRROR / 2 else "rechts"
        return f"Daumen {where}" if idx in THUMBS else where

    # How each layer is reached.
    reach = {i: [] for i in range(len(names))}  # layer -> [(key indexes, text)]
    holds = {}  # layer -> base key index that holds it
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
            holds[target] = idx
            reach[target].append(([idx], f"{label(idx)}-Taste halten ({side(idx)})"))
    magic = names.index("Magic")
    modes = []  # (target layer, key index on the Magic layer)
    for idx, b in enumerate(layers[magic]):
        if b["value"] == "&to":
            target = b["params"][0]["value"]
            modes.append((target, idx))
            reach[target].append(([idx], f"Magic halten + „{label(idx)}“ tippen (bleibt aktiv)"))
    for c in d.get("combos", []):
        b = c["binding"]
        if b["value"] in ("&tog", "&to"):
            target = b["params"][0]["value"]
            a, z = c["keyPositions"]
            how = (
                f"Combo: {label(a, target)} + {label(z, target)} gleichzeitig (ein/aus) · "
                f"auf der Grundebene sind das {label(a)} + {label(z)}"
            )
            reach[target].append(([a, z], how))

    # Hotkey cards.
    cards = []
    mode_titles = {
        "HRM_WinLinx": ("Home-Row-Mods an", "Zurück zur Grundebene"),
        "Typing": ("Mods + Autoshift aus", "Typing-Layer: Home-Row ohne Mods"),
        "Autoshift": ("Autoshift an", "Länger halten = Großbuchstabe/Shift"),
    }
    for target, idx in modes:
        title, note = mode_titles.get(names[target], (TITLES.get(names[target], names[target]), ""))
        cards.append({"title": title, "held": {holds[magic]}, "tapped": {idx},
                      "lines": [f"Magic halten + „{label(idx)}“ tippen", note]})
    arrows = {"←", "→", "↑", "↓"}
    layer_notes = {
        "Cursor": "Pfeile, Auswahl, Cut/Copy/Paste, Undo, Find",
        "Symbol": "Klammern und Sonderzeichen",
        "Mouse": "Mauszeiger, Klicks, Scrollrad",
        "Lower": "Media-Tasten, Nummernblock, F11/F12",
    }
    for name, note in layer_notes.items():
        li = names.index(name)
        if li not in holds:
            continue
        tapped = {i for i, (tap, _, kind) in enumerate(rendered[li]) if tap in arrows or (name != "Cursor" and kind == "mouse")}
        if name == "Lower":
            tapped = {i for i, b in enumerate(layers[li]) if b["value"] == "&kp" and str(b["params"][0]["value"]).startswith("C_")}
        cards.append({"title": f"{name}-Layer", "held": {holds[li]}, "tapped": tapped,
                      "lines": [f"{label(holds[li])}-Taste halten ({side(holds[li])})", note]})
    combo_titles = [
        ("alt_tab", "Task Switcher (Alt+Tab)", "Halten, mit Pfeilen wählen"),
        ("ctrl_tab", "Tab Switcher (Ctrl+Tab)", "Browser-/Editor-Tabs"),
        ("win_tab", "Task View (Win+Tab)", "niri: Übersicht"),
        ("meh", "Meh (Alt+Ctrl+Shift)", "Modifier für eigene Kürzel"),
        ("gaming", "Gaming-Layer ein/aus", ""),
        ("caps_lock", "Caps Lock", "links oder rechts"),
        ("caps_word", "Caps Word", "links oder rechts · ein Wort groß"),
        ("F11", "F11", ""),
        ("F12", "F12", ""),
    ]
    for needle, title, note in combo_titles:
        hits = [c for c in d.get("combos", []) if needle in c["name"]]
        if not hits:
            continue
        tapped = {k for c in hits for k in c["keyPositions"]}
        a, z = hits[0]["keyPositions"]
        first = f"{label(a)} + {label(z)} gleichzeitig"
        if needle == "gaming":
            target = hits[0]["binding"]["params"][0]["value"]
            first = f"{label(a, target)} + {label(z, target)} gleichzeitig"
            note = f"auf der Grundebene: {label(a)} + {label(z)}"
        cards.append({"title": title, "held": set(), "tapped": tapped, "lines": [first, note]})

    hot_pages = [cards[i:i + 8] for i in range(0, len(cards), 8)]
    layer_names = [n for n in PAGES if n in names]
    tabs = [TITLES.get(n, n) for n in layer_names] + [f"Hotkeys {i + 1}" for i in range(len(hot_pages))]

    for no, name in enumerate(layer_names, start=1):
        li = names.index(name)
        how = reach.get(li, [])
        if li == 0:
            subtitle, highlight = "Grundebene mit Home-Row-Mods", set()
        else:
            subtitle = "  ·  ".join(t for _, t in how) or name
            highlight = {k for keys, _ in how for k in keys}
        (outdir / f"{no:02d}-{name}.svg").write_text(svg(layer_page(no, tabs, subtitle, rendered[li], highlight)))
    for i, page in enumerate(hot_pages):
        no = len(layer_names) + i + 1
        (outdir / f"{no:02d}-hotkeys{i + 1}.svg").write_text(svg(hotkey_page(no, tabs, page)))


if __name__ == "__main__":
    main()
