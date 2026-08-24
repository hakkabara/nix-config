#!/usr/bin/env python3
import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import termios
import time
import tty
from dataclasses import asdict, dataclass
from pathlib import Path

VERSION = "4.5.1"
WATCHER_UNIT = "hakkabara-monitor-watcher.service"


@dataclass
class Output:
    name: str
    connected: bool
    enabled: bool
    phys_w: int
    phys_h: int
    log_w: int
    log_h: int
    x: int = 0
    y: int = 0
    scale: float = 1.0
    priority: int = 0


def run(cmd, *, check=True, capture=True):
    proc = subprocess.run(
        cmd,
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if check and proc.returncode != 0:
        msg = proc.stderr.strip() if proc.stderr else f"command failed: {' '.join(cmd)}"
        raise RuntimeError(msg)
    return proc


def kscreen_outputs():
    data = json.loads(run(["kscreen-doctor", "-j"]).stdout)
    outs = []
    for raw in data.get("outputs", []):
        scale = float(raw.get("scale") or 1.0)
        modes = {str(mode.get("id")): mode for mode in raw.get("modes", [])}
        mode = modes.get(str(raw.get("currentModeId")))
        if mode:
            pw = int(mode.get("size", {}).get("width", 0))
            ph = int(mode.get("size", {}).get("height", 0))
        else:
            pw = ph = 0
        pos = raw.get("pos") or {}
        outs.append(
            Output(
                str(raw.get("name")),
                bool(raw.get("connected", True)),
                bool(raw.get("enabled", False)),
                pw,
                ph,
                round(pw / scale) if pw else 0,
                round(ph / scale) if ph else 0,
                int(pos.get("x", 0)),
                int(pos.get("y", 0)),
                scale,
                int(raw.get("priority") or 0),
            )
        )
    return outs


def niri_outputs():
    data = json.loads(run(["niri", "msg", "--json", "outputs"]).stdout)
    items = list(data.items()) if isinstance(data, dict) else [(str(o.get("name", "")), o) for o in data]
    outs = []
    for key, raw in items:
        name = str(raw.get("name") or key)
        cur = raw.get("current_mode")
        modes = raw.get("modes") or []
        mode = modes[cur] if isinstance(cur, int) and 0 <= cur < len(modes) else None
        pw = int((mode or {}).get("width", 0))
        ph = int((mode or {}).get("height", 0))
        logical = raw.get("logical")
        enabled = logical is not None and cur is not None
        logical = logical or {}
        outs.append(
            Output(
                name,
                True,
                enabled,
                pw,
                ph,
                int(logical.get("width", 0)),
                int(logical.get("height", 0)),
                int(logical.get("x", 0)),
                int(logical.get("y", 0)),
                float(logical.get("scale") or 1.0),
                0,
            )
        )
    return outs


def backend_name(cfg):
    backend = cfg.get("backend", "auto")
    if backend != "auto":
        return backend
    if os.environ.get("NIRI_SOCKET") and shutil.which("niri"):
        return "niri"
    if shutil.which("kscreen-doctor"):
        return "plasma"
    raise RuntimeError("unable to auto-detect monitor backend")


def get_outputs(cfg):
    return niri_outputs() if backend_name(cfg) == "niri" else kscreen_outputs()


def connected(outs):
    return [o for o in outs if o.connected]


def active(outs):
    return [o for o in outs if o.connected and o.enabled]


def snapshot_json(outs):
    return [asdict(o) for o in outs]


def load_snapshot(path):
    return [Output(**item) for item in json.loads(Path(path).read_text())]


def size_match(out, size, tolerance):
    width, height = size
    return abs(out.phys_w - width) <= tolerance and abs(out.phys_h - height) <= tolerance


def detect_profile(cfg, outs, *, include_disabled=False):
    candidates = connected(outs) if include_disabled else active(outs)
    if not include_disabled and len(candidates) == 1:
        return "single"
    if len(candidates) != 2:
        return "unknown"
    if not all(o.phys_w and o.phys_h for o in candidates):
        return "unknown"
    for name, profile in cfg.get("profiles", {}).items():
        expected = [tuple(x) for x in profile.get("matchSizes", [])]
        tolerance = int(profile.get("tolerance", 96))
        if len(expected) != 2:
            continue
        direct = size_match(candidates[0], expected[0], tolerance) and size_match(candidates[1], expected[1], tolerance)
        reverse = size_match(candidates[0], expected[1], tolerance) and size_match(candidates[1], expected[0], tolerance)
        if direct or reverse:
            return name
    return "unknown"


def choose_pair(cfg, outs, profile=None, swap=False):
    candidates = [o for o in connected(outs) if o.phys_w and o.phys_h]
    if len(candidates) != 2:
        raise RuntimeError(f"need exactly 2 connected outputs with valid sizes, got {len(candidates)}")
    profile_cfg = (cfg.get("profiles", {}).get(profile) if profile else None) or {}
    left_name = profile_cfg.get("leftOutput")
    right_name = profile_cfg.get("rightOutput")
    by_name = {o.name: o for o in candidates}
    if left_name in by_name and right_name in by_name and left_name != right_name:
        left, right = by_name[left_name], by_name[right_name]
    else:
        candidates = sorted(candidates, key=lambda o: o.name)
        left, right = candidates[0], candidates[1]
    if swap:
        left, right = right, left
    return left, right


def layout_positions(left, right, alignment="center"):
    if not left.log_w or not left.log_h or not right.log_w or not right.log_h:
        raise RuntimeError("logical output sizes unavailable")
    if alignment == "top":
        left_y = right_y = 0
    elif alignment == "bottom":
        height = max(left.log_h, right.log_h)
        left_y = height - left.log_h
        right_y = height - right.log_h
    elif alignment == "center":
        height = max(left.log_h, right.log_h)
        left_y = (height - left.log_h) // 2
        right_y = (height - right.log_h) // 2
    else:
        raise RuntimeError(f"unknown vertical alignment '{alignment}'")
    return {left.name: (0, left_y), right.name: (left.log_w, right_y)}


def runtime_file(runtime_dir, name):
    runtime_dir.mkdir(parents=True, exist_ok=True)
    return runtime_dir / name


def atomic_json(path, value):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, indent=2))
    tmp.replace(path)


def topology_fingerprint(outs):
    return sorted(
        [
            [o.name, o.phys_w, o.phys_h, o.log_w, o.log_h, round(o.scale, 4)]
            for o in active(outs)
        ]
    )


def mark_approved(runtime_dir, outs):
    atomic_json(runtime_file(runtime_dir, "approved-dual.json"), topology_fingerprint(outs))


def clear_approved(runtime_dir):
    try:
        runtime_file(runtime_dir, "approved-dual.json").unlink()
    except FileNotFoundError:
        pass


def approved_matches(runtime_dir, outs):
    path = runtime_file(runtime_dir, "approved-dual.json")
    if len(active(outs)) != 2 or not path.exists():
        return False
    try:
        return json.loads(path.read_text()) == topology_fingerprint(outs)
    except Exception:
        return False


def suppress(runtime_dir, seconds=5):
    runtime_file(runtime_dir, "suppress-until").write_text(str(time.monotonic() + seconds))


def suppressed(runtime_dir):
    try:
        return time.monotonic() < float(runtime_file(runtime_dir, "suppress-until").read_text())
    except Exception:
        return False


def safe_output(cfg, outs):
    names = {o.name for o in connected(outs)}
    wanted = cfg.get("safeOutput")
    if wanted in names:
        return wanted
    enabled = active(outs)
    if enabled:
        return sorted(enabled, key=lambda o: (o.priority or 999, o.name))[0].name
    if names:
        return sorted(names)[0]
    raise RuntimeError("no connected output available for safe single mode")


def plasma_single(cfg, outs, dry=False):
    safe = safe_output(cfg, outs)
    args = [
        "kscreen-doctor",
        f"output.{safe}.enable",
        f"output.{safe}.mirror.none",
        f"output.{safe}.position.0,0",
        f"output.{safe}.priority.1",
    ]
    for out in connected(outs):
        if out.name != safe:
            args.append(f"output.{out.name}.disable")
    if dry:
        print("DRY-RUN:", *args)
        return
    run(args)


def niri_single(cfg, outs, dry=False):
    safe = safe_output(cfg, outs)
    commands = [
        ["niri", "msg", "output", safe, "on"],
        ["niri", "msg", "output", safe, "position", "0", "0"],
    ]
    for out in connected(outs):
        if out.name != safe:
            commands.append(["niri", "msg", "output", out.name, "off"])
    if dry:
        for command in commands:
            print("DRY-RUN:", *command)
        return
    for command in commands:
        run(command)


def apply_single(cfg, outs=None, dry=False, runtime_dir=None):
    outs = outs or get_outputs(cfg)
    if runtime_dir and not dry:
        clear_approved(runtime_dir)
    if backend_name(cfg) == "niri":
        return niri_single(cfg, outs, dry)
    return plasma_single(cfg, outs, dry)


def resolve_primary(cfg, left, right, profile=None):
    names = {left.name, right.name}
    profile_cfg = (cfg.get("profiles", {}).get(profile) if profile else None) or {}
    wanted = profile_cfg.get("primaryOutput")
    if wanted in names:
        return wanted
    safe = cfg.get("safeOutput")
    if safe in names:
        return safe
    for out in (left, right):
        if out.priority == 1:
            return out.name
    return left.name


def plasma_layout(cfg, left, right, positions, primary_name, dry=False):
    left_priority = 1 if left.name == primary_name else 2
    right_priority = 1 if right.name == primary_name else 2
    args = [
        "kscreen-doctor",
        f"output.{left.name}.enable",
        f"output.{left.name}.mirror.none",
        f"output.{left.name}.position.{positions[left.name][0]},{positions[left.name][1]}",
        f"output.{left.name}.priority.{left_priority}",
        f"output.{right.name}.enable",
        f"output.{right.name}.mirror.none",
        f"output.{right.name}.position.{positions[right.name][0]},{positions[right.name][1]}",
        f"output.{right.name}.priority.{right_priority}",
    ]
    if dry:
        print("DRY-RUN:", *args)
        return
    run(args)


def niri_layout(cfg, left, right, positions, dry=False):
    commands = []
    for out in (left, right):
        x, y = positions[out.name]
        commands += [
            ["niri", "msg", "output", out.name, "on"],
            ["niri", "msg", "output", out.name, "position", str(x), str(y)],
        ]
    if dry:
        for command in commands:
            print("DRY-RUN:", *command)
        return
    for command in commands:
        run(command)


def verify_layout(cfg, left, right, positions, primary_name=None, tries=8):
    for _ in range(tries):
        now = {o.name: o for o in active(get_outputs(cfg))}
        if left.name in now and right.name in now:
            positions_ok = all(
                abs(now[name].x - x) <= 2 and abs(now[name].y - y) <= 2
                for name, (x, y) in positions.items()
            )
            primary_ok = True
            if backend_name(cfg) == "plasma" and primary_name:
                primary_ok = now[primary_name].priority == 1
            if positions_ok and primary_ok:
                return True
        time.sleep(0.25)
    return False


def saved_dual_snapshot(runtime_dir):
    """Load the last validated dual snapshot without requiring current dual connectivity.

    This is intentionally separate from latest_usable_snapshot(): normal layout
    application must not trust a stale topology when an output is currently
    disconnected.  The explicit popup-test command only needs representative
    menu data, so it may use the saved dual snapshot while the guest is single.
    """
    if not runtime_dir:
        return None
    path = runtime_file(runtime_dir, "hotplug-snapshot.json")
    if not path.exists():
        return None
    try:
        snap = load_snapshot(path)
    except Exception:
        return None
    pair = connected(snap)
    if len(pair) != 2:
        return None
    if not all(o.phys_w and o.phys_h and o.log_w and o.log_h for o in pair):
        return None
    return snap


def latest_usable_snapshot(runtime_dir, current):
    if not runtime_dir or len(connected(current)) != 2:
        return None
    snap = saved_dual_snapshot(runtime_dir)
    if snap is None:
        return None
    if {o.name for o in connected(snap)} != {o.name for o in connected(current)}:
        return None
    return snap


def profile_alignment(cfg, profile, override=None):
    if override:
        return override
    if profile and profile in cfg.get("profiles", {}):
        return cfg["profiles"][profile].get("verticalAlignment", "center")
    return "center"


def apply_layout(cfg, profile=None, swap=False, snapshot=None, dry=False, runtime_dir=None, alignment=None):
    current = get_outputs(cfg) if snapshot is None else snapshot
    outs = current
    if snapshot is None and len([o for o in connected(current) if o.phys_w and o.phys_h]) < 2:
        outs = latest_usable_snapshot(runtime_dir, current) or current
    left, right = choose_pair(cfg, outs, profile, swap)
    align = profile_alignment(cfg, profile, alignment)
    positions = layout_positions(left, right, align)
    primary_name = resolve_primary(cfg, left, right, profile)
    print(
        f"Layout ({align}): {left.name} {left.log_w}x{left.log_h} @ {positions[left.name][0]},{positions[left.name][1]}"
        f"  |  {right.name} {right.log_w}x{right.log_h} @ {positions[right.name][0]},{positions[right.name][1]}"
        f"  |  primary={primary_name}"
    )
    if runtime_dir and not dry:
        suppress(runtime_dir, 5)
    if backend_name(cfg) == "niri":
        niri_layout(cfg, left, right, positions, dry)
    else:
        plasma_layout(cfg, left, right, positions, primary_name, dry)
    if dry:
        return
    if not verify_layout(cfg, left, right, positions, primary_name):
        print("ERROR: applied layout verification failed; reverting to safe single", file=sys.stderr)
        apply_single(cfg, runtime_dir=runtime_dir)
        raise RuntimeError("layout verification failed")
    if runtime_dir:
        mark_approved(runtime_dir, get_outputs(cfg))


def status(cfg):
    print(f"Version: {VERSION}")
    print(f"Backend: {backend_name(cfg)}")
    for out in get_outputs(cfg):
        state = "ON" if out.enabled else "off"
        print(
            f"{out.name:14} {state:3} connected={out.connected!s:5} "
            f"physical={out.phys_w}x{out.phys_h} logical={out.log_w}x{out.log_h} "
            f"pos={out.x},{out.y} scale={out.scale:g}"
        )


def render_help(cfg):
    print(r"""
+======================================================================+
|                    HAKKABARA MONITOR CONTROL                         |
+======================================================================+
| CLI                                                                  |
|   monitor                 Open selector when a dual snapshot exists   |
|   monitor status          Show outputs + runtime/watcher summary      |
|   monitor detect          Detect current active profile               |
|   monitor profiles        Show configured profile geometry            |
|   monitor single          Force safe single-screen mode               |
|   monitor home            Apply calibrated Home Office profile        |
|   monitor office          Apply Office profile                        |
|   monitor layout          Generic two-output layout                    |
|   monitor swap            Generic two-output layout, swapped          |
|   monitor auto            Detect profile and apply it                  |
|   monitor choose          Open the interactive selector               |
|   monitor help            Show this help                              |
|   monitor version         Show helper version                         |
|   monitor watcher status  Show watcher service state                  |
|   monitor watcher start   Start automatic hotplug handling            |
|   monitor watcher stop    Stop automatic hotplug handling             |
|   monitor watcher restart Restart automatic hotplug handling          |
|   monitor popup-test      Test exact production selector launch        |
|                                                                      |
| COMMON OPTIONS                                                       |
|   --dry-run               Print commands without changing displays    |
|   --swap                  Swap left/right outputs                      |
|   --align top|center|bottom                                           |
|                                                                      |
| SELECTOR KEYS                                                        |
|   UP/DOWN or j/k          Move selection                              |
|   ENTER                   Apply selected layout                       |
|   ESC or q                Close menu / keep current state             |
|   ? or h                  Show in-selector help                       |
|                                                                      |
| SAFETY                                                               |
|   Trigger: 1->2 connected OR 1->2 active (VMware variants)          |
|   Hotplug: dual detected -> safe single -> selector                   |
|   Timeout: no input -> stay single                                    |
|   Apply failure: automatic rollback to safe single                    |
+======================================================================+
""".strip("\n"))
    print(f"Backend: {backend_name(cfg)}")
    print(f"Safe output: {cfg.get('safeOutput') or 'auto'}")
    watcher_cfg = cfg.get('watcher', {})
    print(
        "Watcher: "
        f"settle<={watcher_cfg.get('debounceSeconds', 1)}s, "
        f"fallback={watcher_cfg.get('fallbackPollSeconds', 30)}s, "
        f"selector-timeout={watcher_cfg.get('promptTimeoutSeconds', 10)}s, "
        f"popup-delay={watcher_cfg.get('popupDelayMilliseconds', 250)}ms"
    )
    state = run(["systemctl", "--user", "is-active", WATCHER_UNIT], check=False).stdout.strip()
    print(f"Watcher service: {state or 'unknown'}")


def tui_help_overlay(cfg, detected):
    sys.stdout.write("\x1b[2J\x1b[H")
    print("+------------------------------------------------------------+")
    print("|                 MONITOR SELECTOR HELP                     |")
    print("+------------------------------------------------------------+")
    print("| VMware hotplug is first returned to SAFE SINGLE.          |")
    print("| The detected profile is preselected; ENTER applies it.    |")
    print("| FORCE SINGLE explicitly disables all but the safe output. |")
    print("| ESC/q only closes the menu. Any key stops the countdown.  |")
    print("| UP/DOWN or j/k moves; ?/h opens this help.                |")
    print("+------------------------------------------------------------+")
    print(f"| Backend : {backend_name(cfg):<48}|")
    print(f"| Detected: {detected:<48}|")
    print("+------------------------------------------------------------+")
    print("Press any key to return...")
    sys.stdout.flush()
    os.read(sys.stdin.fileno(), 1)


def tui(cfg, snap, detected, timeout, runtime_dir):
    if not sys.stdin.isatty():
        raise RuntimeError("interactive selector requires a TTY")
    profiles = cfg.get("profiles", {})
    choices = []
    if detected in profiles:
        profile = profiles[detected]
        label = profile.get("label", detected.title())
        choices += [
            (label + "  [detected]", detected, False),
            (label + "  [swap displays]", detected, True),
        ]
        for name, other in profiles.items():
            if name == detected:
                continue
            other_label = other.get("label", name.title())
            choices += [(other_label, name, False), (other_label + "  [swap displays]", name, True)]
        choices += [("Auto Layout  [current sizes]", None, False), ("Auto Layout  [swap displays]", None, True)]
    else:
        choices += [("Auto Layout  [current sizes]  [detected]", None, False), ("Auto Layout  [swap displays]", None, True)]
        for name, profile in profiles.items():
            label = profile.get("label", name.title())
            choices += [(label, name, False), (label + "  [swap displays]", name, True)]
    choices += [(f"Force Safe Single  [{cfg.get('safeOutput') or 'auto'} only]", "single", False)]

    connected_count = len(connected(snap))
    live_at_open = get_outputs(cfg)
    active_at_open = len(active(live_at_open))
    state_label = "single-screen safety mode active" if active_at_open == 1 else f"{active_at_open} active outputs"
    index = 0
    deadline = time.monotonic() + timeout
    countdown = True
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    tty.setcbreak(fd)
    try:
        while True:
            remain = max(0, int(deadline - time.monotonic() + 0.999)) if countdown else None
            sys.stdout.write("\x1b[2J\x1b[H")
            print("+------------------------------------------------------------+")
            print("|              HAKKABARA MONITOR CONTROL                   |")
            print("|                SAFE DISPLAY SELECTOR                     |")
            print("+------------------------------------------------------------+")
            print(f"| Backend   : {backend_name(cfg):<47}|")
            print(f"| Detected  : {detected:<47}|")
            print(f"| Snapshot  : {connected_count} connected output(s){' ':26}|")
            print(f"| Safe      : {(cfg.get('safeOutput') or 'auto'):<47}|")
            print(f"| State     : {state_label:<47}|")
            print("+------------------------------------------------------------+")
            for i, (label, _, __) in enumerate(choices):
                print(f"| {'>' if i == index else ' '} {label:<56}|")
            print("+------------------------------------------------------------+")
            print("| UP/DOWN,j/k move | ENTER apply | ESC/q close | ? help    |")
            if countdown:
                print(f"| No input: stay single in {remain:2d}s{' ':31}|")
            else:
                print("| Countdown stopped; choose without time limit.             |")
            print("+------------------------------------------------------------+")
            sys.stdout.flush()

            ready, _, _ = select.select([sys.stdin], [], [], 0.25 if countdown else None)
            if not ready:
                if countdown and time.monotonic() >= deadline:
                    return 0
                continue
            char = os.read(fd, 1)
            countdown = False
            if char in (b"\r", b"\n"):
                _, profile, swap = choices[index]
                if profile == "single":
                    apply_single(cfg, runtime_dir=runtime_dir)
                    return 0
                apply_layout(cfg, profile, swap, snapshot=snap, runtime_dir=runtime_dir)
                return 0
            if char in (b"q", b"Q"):
                return 0
            if char in (b"?", b"h", b"H"):
                tui_help_overlay(cfg, detected)
                continue
            if char == b"\x1b":
                ready2, _, _ = select.select([sys.stdin], [], [], 0.03)
                if not ready2:
                    return 0
                sequence = os.read(fd, 2)
                if sequence == b"[A":
                    index = (index - 1) % len(choices)
                elif sequence == b"[B":
                    index = (index + 1) % len(choices)
            elif char in (b"k", b"K"):
                index = (index - 1) % len(choices)
            elif char in (b"j", b"J"):
                index = (index + 1) % len(choices)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

def wait_for_active_count(cfg, wanted, timeout, stable_samples=2):
    deadline = time.monotonic() + timeout
    previous = None
    stable = 0
    last = get_outputs(cfg)
    while time.monotonic() < deadline:
        outs = get_outputs(cfg)
        last = outs
        enabled = active(outs)
        fingerprint = [
            (o.name, o.phys_w, o.phys_h, o.log_w, o.log_h, o.x, o.y, o.enabled)
            for o in outs
        ]
        valid = len(enabled) == wanted
        if wanted == 2:
            valid = valid and all(o.phys_w and o.phys_h and o.log_w and o.log_h for o in enabled)
        if valid and fingerprint == previous:
            stable += 1
            if stable >= stable_samples:
                return outs
        else:
            stable = 0
        previous = fingerprint
        time.sleep(0.08)
    return last


def wait_for_connected_pair(cfg, timeout):
    """Wait only long enough for two connectors to expose usable mode sizes.

    The watcher deliberately does not wait for a stable two-screen desktop: the
    whole point is to return to safe single as soon as VMware exposes the second
    connector.
    """
    deadline = time.monotonic() + timeout
    last = get_outputs(cfg)
    while time.monotonic() < deadline:
        outs = get_outputs(cfg)
        last = outs
        pair = connected(outs)
        if len(pair) == 2 and all(o.phys_w and o.phys_h and o.log_w and o.log_h for o in pair):
            return outs
        time.sleep(0.06)
    return last

def plasma_selector_windows():
    if not shutil.which("kdotool"):
        return []
    proc = run(
        ["kdotool", "search", "--class", "hakkabara-monitor-selector"],
        check=False,
    )
    if proc.returncode != 0:
        return []
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def current_plasma_desktop():
    if not shutil.which("kdotool"):
        return None
    proc = run(["kdotool", "get_desktop"], check=False)
    desktop = proc.stdout.strip() if proc.returncode == 0 else ""
    return desktop or None


def place_selector_on_desktop(window_id, desktop, runtime_dir):
    """Move/focus the selector after KWin has created its Wayland window.

    The selector has a dedicated Wayland app-id, but generic Kitty/KWin rules can
    still place or maximize terminal windows.  Hotplug recovery must therefore
    verify the actual KWin window, move it onto the desktop that was active before
    launch, and focus it instead of treating a successful systemd-run as success.
    """
    commands = []
    if desktop:
        commands.append(["kdotool", "set_desktop_for_window", window_id, desktop])
    commands.extend(
        [
            ["kdotool", "windowactivate", window_id],
            ["kdotool", "windowraise", window_id],
        ]
    )
    errors = []
    for command in commands:
        proc = run(command, check=False)
        if proc.returncode != 0:
            errors.append((proc.stderr or proc.stdout or "command failed").strip())

    after = run(["kdotool", "get_desktop_for_window", window_id], check=False)
    actual = after.stdout.strip() if after.returncode == 0 else "unknown"
    log_path = runtime_file(runtime_dir, "popup-placement.log")
    log_path.write_text(
        f"window={window_id} target-desktop={desktop or 'unknown'} "
        f"actual-desktop={actual} errors={errors}\n"
    )
    return not errors, actual


def wait_and_place_selector(existing_windows, target_desktop, runtime_dir, timeout=1.5):
    if not shutil.which("kdotool"):
        raise RuntimeError("kdotool is required for Plasma selector placement")

    deadline = time.monotonic() + timeout
    existing = set(existing_windows)
    last_seen = []
    while time.monotonic() < deadline:
        last_seen = plasma_selector_windows()
        new_windows = [window_id for window_id in last_seen if window_id not in existing]
        candidates = new_windows or last_seen
        if candidates:
            window_id = candidates[-1]
            ok, actual = place_selector_on_desktop(
                window_id,
                target_desktop,
                runtime_dir,
            )
            if not ok:
                raise RuntimeError(
                    f"selector window {window_id} created but placement/focus failed; "
                    f"actual desktop={actual}"
                )
            return window_id, actual
        time.sleep(0.05)

    raise RuntimeError(
        "selector process launched but no KWin window appeared within "
        f"{timeout:.1f}s (last_seen={last_seen})"
    )


def spawn_popup(cfg, snap_path, detected, runtime_dir):
    unit = "hakkabara-monitor-selector.service"
    active_check = run(["systemctl", "--user", "is-active", "--quiet", unit], check=False)
    if active_check.returncode == 0:
        return False

    # A completed transient unit may still have a failed state for a short time.
    run(["systemctl", "--user", "reset-failed", unit], check=False)

    plasma = backend_name(cfg) == "plasma"
    target_desktop = current_plasma_desktop() if plasma else None
    existing_windows = plasma_selector_windows() if plasma else []

    monitor_bin = os.environ.get("HAKKABARA_MONITOR_BIN", "monitor")
    command = [
        "systemd-run",
        "--user",
        "--collect",
        "--unit=hakkabara-monitor-selector",
        "kitty",
        "--start-as",
        "normal",
        "--class",
        "hakkabara-monitor-selector",
        "--title",
        "Monitor Setup",
        monitor_bin,
        "choose",
        "--snapshot",
        str(snap_path),
        "--detected",
        detected,
    ]
    proc = run(command, check=False)
    if proc.returncode != 0:
        log_path = runtime_file(runtime_dir, "popup-error.log")
        log_path.write_text((proc.stderr or proc.stdout or "systemd-run popup failed") + "\n")
        raise RuntimeError(f"selector launch failed; see {log_path}")

    if plasma:
        window_id, actual_desktop = wait_and_place_selector(
            existing_windows,
            target_desktop,
            runtime_dir,
        )
        print(
            f"WATCHER: selector visible window={window_id} "
            f"desktop={actual_desktop} target={target_desktop}",
            flush=True,
        )
    return True


def event_source_command(cfg):
    backend = backend_name(cfg)
    if backend == "plasma" and shutil.which("kscreen-console"):
        # Important: `kscreen-console monitor` only registers ConfigMonitor and
        # does NOT print configurationChanged events. Running kscreen-console
        # without a command calls monitorAndPrint(), which emits output whenever
        # KScreen's configurationChanged signal fires.
        return ["kscreen-console"], "kscreen-console-config-events-stderr"
    if backend == "niri" and shutil.which("niri"):
        return ["niri", "msg", "--json", "event-stream"], "niri-event-stream"
    if shutil.which("udevadm"):
        return ["udevadm", "monitor", "--udev", "--subsystem-match=drm"], "udevadm-drm"
    return None, "poll-only"


def event_source_environment(cfg):
    env = os.environ.copy()
    if backend_name(cfg) == "plasma":
        # kscreen-console uses qDebug() for configurationChanged output.  On
        # systemd-based Plasma sessions Qt may route those messages directly to
        # the journal instead of the child stderr pipe.  Force Qt logging back
        # to stderr so select() receives the event immediately instead of only
        # noticing the topology on the 30-second fallback poll.
        env["QT_FORCE_STDERR_LOGGING"] = "1"
    return env


def start_event_source(cfg):
    command, label = event_source_command(cfg)
    if command is None:
        return None, label
    proc = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
        env=event_source_environment(cfg),
    )
    return proc, label


def drain_event(proc, *, quiet=0.08, max_duration=1.5):
    if proc is None or proc.stdout is None:
        return 0
    fd = proc.stdout.fileno()
    total = 0
    deadline = time.monotonic() + max_duration
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], quiet)
        if not ready:
            break
        chunk = os.read(fd, 65536)
        if not chunk:
            raise RuntimeError("monitor event source exited")
        total += len(chunk)
    return total


def prime_event_source(proc):
    if proc is None:
        return
    # kscreen-console prints a full pivot config at startup. Drain that initial
    # burst so it cannot be mistaken for a hotplug event.
    drain_event(proc, quiet=0.15, max_duration=2.0)

def hotplug_transition(previous_active, previous_connected, outs):
    """Return the VMware/KScreen edge that should open the safe selector.

    VMware exposes two real-world variants on this guest:

    * host single -> host dual can reconnect Virtual-2 already DISABLED because
      KScreen remembers our safe-single state.  That is a 1 -> 2 CONNECTED edge
      with the active count still at one.
    * while Virtual-2 stays connected, VMware can enable it in place.  That is a
      1 -> 2 ACTIVE edge with the connected count already at two.

    Supporting both edges is necessary.  Suppression plus previous-state tracking
    prevents our own safe-single changes from retriggering the watcher.
    """
    current_active = len(active(outs))
    current_connected = len(connected(outs))
    if previous_connected <= 1 and current_connected == 2:
        return "connected"
    if previous_active <= 1 and current_active == 2:
        return "active"
    return None


def watcher(cfg, runtime_dir):
    runtime_dir.mkdir(parents=True, exist_ok=True)
    initial = get_outputs(cfg)
    previous_active = len(active(initial))
    previous_connected = len(connected(initial))
    if previous_active <= 1:
        clear_approved(runtime_dir)

    event_proc, source_label = start_event_source(cfg)
    prime_event_source(event_proc)
    runtime_file(runtime_dir, "event-source").write_text(source_label)
    poll = max(2, int(cfg.get("watcher", {}).get("fallbackPollSeconds", 30)))
    settle = max(0.2, float(cfg.get("watcher", {}).get("debounceSeconds", 1)))
    popup_delay = max(0.0, float(cfg.get("watcher", {}).get("popupDelayMilliseconds", 250)) / 1000.0)
    print(
        f"WATCHER: backend={backend_name(cfg)} event-source={source_label} "
        f"fallback={poll}s settle<={settle:g}s popup-delay={popup_delay:g}s "
        f"initial-active={previous_active} initial-connected={previous_connected}",
        flush=True,
    )

    try:
        while True:
            got_event = False
            if event_proc is not None and event_proc.stdout is not None:
                ready, _, _ = select.select([event_proc.stdout.fileno()], [], [], poll)
                if ready:
                    drain_event(event_proc)
                    got_event = True
            else:
                time.sleep(poll)

            # Layout changes initiated by this helper must not become new hotplug
            # edges.  In particular, safe-single disables Virtual-2 itself.
            if suppressed(runtime_dir):
                continue

            check_started = time.monotonic()
            outs = get_outputs(cfg)
            current_active = len(active(outs))
            current_connected = len(connected(outs))

            # A real host-side return to one connector fully rearms the connected
            # edge and invalidates any previously approved dual layout.
            if current_connected <= 1:
                if previous_connected > 1 or previous_active > 1:
                    clear_approved(runtime_dir)
                previous_active = current_active
                previous_connected = current_connected
                continue

            # A dual layout explicitly applied/approved by this helper must stay
            # untouched; otherwise its own KScreen events would reopen the menu.
            if current_active == 2 and approved_matches(runtime_dir, outs):
                previous_active = 2
                previous_connected = current_connected
                continue

            reason = hotplug_transition(previous_active, previous_connected, outs)

            # KScreen may first report only one connector/active output and emit
            # another event moments later.  We normally rely on that next event,
            # but on an active-edge candidate give it a short chance to settle.
            if reason is None and previous_active <= 1 and got_event and current_connected >= 2:
                candidate = wait_for_active_count(cfg, 2, min(settle, 1.0), stable_samples=1)
                if len(active(candidate)) == 2:
                    outs = candidate
                    current_active = 2
                    current_connected = len(connected(candidate))
                    reason = hotplug_transition(previous_active, previous_connected, outs)

            if reason is not None:
                snapshot = outs
                if reason == "connected":
                    pair = connected(snapshot)
                    if len(pair) != 2 or not all(o.phys_w and o.phys_h and o.log_w and o.log_h for o in pair):
                        snapshot = wait_for_connected_pair(cfg, min(settle, 1.0))
                        pair = connected(snapshot)
                    if len(pair) != 2:
                        print("WATCHER: connected dual edge did not settle; waiting for next event", flush=True)
                        previous_active = len(active(snapshot))
                        previous_connected = len(connected(snapshot))
                        continue
                    detected = detect_profile(cfg, snapshot, include_disabled=True)
                else:
                    pair = active(snapshot)
                    if len(pair) != 2 or not all(o.phys_w and o.phys_h and o.log_w and o.log_h for o in pair):
                        snapshot = wait_for_active_count(cfg, 2, min(settle, 1.0), stable_samples=1)
                        pair = active(snapshot)
                    if len(pair) != 2:
                        print("WATCHER: active dual edge did not settle; waiting for next event", flush=True)
                        previous_active = len(active(snapshot))
                        previous_connected = len(connected(snapshot))
                        continue
                    detected = detect_profile(cfg, snapshot)

                snapshot_path = runtime_file(runtime_dir, "hotplug-snapshot.json")
                atomic_json(snapshot_path, snapshot_json(snapshot))
                elapsed_ms = int((time.monotonic() - check_started) * 1000)
                print(
                    f"WATCHER: dual {reason} edge detected profile={detected} after {elapsed_ms}ms; "
                    "entering safe single",
                    flush=True,
                )

                apply_single(cfg, outs=snapshot, runtime_dir=runtime_dir)
                single_started = time.monotonic()
                single = wait_for_active_count(cfg, 1, 1.2, stable_samples=1)
                if len(active(single)) != 1:
                    log_path = runtime_file(runtime_dir, "watcher-error.log")
                    log_path.write_text("safe single did not stabilize after hotplug\n")
                    print(f"WATCHER: ERROR safe single failed; see {log_path}", flush=True)
                    previous_active = len(active(single))
                    previous_connected = len(connected(single))
                    continue

                if popup_delay:
                    time.sleep(popup_delay)
                try:
                    spawned = spawn_popup(cfg, snapshot_path, detected, runtime_dir)
                except Exception as exc:
                    log_path = runtime_file(runtime_dir, "popup-error.log")
                    log_path.write_text(f"{type(exc).__name__}: {exc}\n")
                    single_ms = int((time.monotonic() - single_started) * 1000)
                    total_ms = int((time.monotonic() - check_started) * 1000)
                    print(
                        f"WATCHER: ERROR selector visibility failed after {total_ms}ms: {exc}; "
                        f"safe single remains active; see {log_path}",
                        flush=True,
                    )
                    previous_active = 1
                    previous_connected = len(connected(single))
                    continue

                single_ms = int((time.monotonic() - single_started) * 1000)
                total_ms = int((time.monotonic() - check_started) * 1000)
                print(
                    f"WATCHER: safe single stable in {single_ms}ms; "
                    + ("selector visible" if spawned else "selector already running")
                    + f"; total={total_ms}ms",
                    flush=True,
                )
                previous_active = 1
                previous_connected = len(connected(single))
                continue

            previous_active = current_active
            previous_connected = current_connected
    finally:
        if event_proc is not None:
            event_proc.terminate()

def self_test():
    cfg = {
        "backend": "plasma",
        "profiles": {
            "homeoffice": {
                "matchSizes": [[2560, 1440], [1920, 1080]],
                "tolerance": 96,
                "leftOutput": "Virtual-2",
                "rightOutput": "Virtual-1",
                "primaryOutput": "Virtual-1",
                "verticalAlignment": "top",
            },
            "office": {
                "matchSizes": [[2560, 1440], [2560, 1440]],
                "tolerance": 96,
                "leftOutput": "Virtual-1",
                "rightOutput": "Virtual-2",
                "primaryOutput": "Virtual-1",
                "verticalAlignment": "top",
            },
        }
    }
    home = [
        Output("Virtual-1", True, True, 2560, 1440, 2560, 1440),
        Output("Virtual-2", True, True, 1920, 1080, 1920, 1080),
    ]
    assert detect_profile(cfg, home) == "homeoffice"
    left, right = choose_pair(cfg, home, "homeoffice", False)
    assert (left.name, right.name) == ("Virtual-2", "Virtual-1")
    assert layout_positions(left, right, "top") == {"Virtual-2": (0, 0), "Virtual-1": (1920, 0)}
    assert layout_positions(left, right, "center") == {"Virtual-2": (0, 180), "Virtual-1": (1920, 0)}
    assert layout_positions(left, right, "bottom") == {"Virtual-2": (0, 360), "Virtual-1": (1920, 0)}
    assert resolve_primary(cfg, left, right, "homeoffice") == "Virtual-1"
    left, right = choose_pair(cfg, home, "homeoffice", True)
    assert layout_positions(left, right, "top") == {"Virtual-1": (0, 0), "Virtual-2": (2560, 0)}
    assert resolve_primary(cfg, left, right, "homeoffice") == "Virtual-1"
    office = [
        Output("Virtual-1", True, True, 2560, 1440, 2560, 1440),
        Output("Virtual-2", True, True, 2560, 1440, 2560, 1440),
    ]
    assert detect_profile(cfg, office) == "office"
    near = [
        Output("Virtual-1", True, True, 2558, 1438, 2558, 1438),
        Output("Virtual-2", True, True, 1918, 1078, 1918, 1078),
    ]
    assert detect_profile(cfg, near) == "homeoffice"
    unknown = [
        Output("A", True, True, 3840, 2160, 1920, 1080, scale=2),
        Output("B", True, True, 1920, 1200, 1920, 1200),
    ]
    assert detect_profile(cfg, unknown) == "unknown"
    assert detect_profile(cfg, [home[0]]) == "single"
    safe_single_with_connected_second = [
        Output("Virtual-1", True, True, 2560, 1440, 2560, 1440),
        Output("Virtual-2", True, False, 1920, 1080, 1920, 1080),
    ]
    assert detect_profile(cfg, safe_single_with_connected_second) == "single"
    assert detect_profile(cfg, safe_single_with_connected_second, include_disabled=True) == "homeoffice"
    # VMware has two observed hotplug variants.  A host single -> dual switch
    # can reconnect Virtual-2 already disabled, while another path enables an
    # already-connected Virtual-2.  Both must trigger exactly once.
    assert len(connected(safe_single_with_connected_second)) == 2
    assert len(active(safe_single_with_connected_second)) == 1
    assert hotplug_transition(1, 1, safe_single_with_connected_second) == "connected"
    assert hotplug_transition(1, 2, safe_single_with_connected_second) is None
    assert hotplug_transition(1, 2, home) == "active"
    assert hotplug_transition(2, 2, home) is None
    assert hotplug_transition(1, 1, [home[0]]) is None
    event_env = event_source_environment(cfg)
    assert event_env.get("QT_FORCE_STDERR_LOGGING") == "1"
    print("SELF-TEST: PASS")


def add_layout_args(parser, allow_swap=True):
    if allow_swap:
        parser.add_argument("--swap", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--align", choices=["top", "center", "bottom"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("status")
    sub.add_parser("backend")
    sub.add_parser("detect")
    sub.add_parser("profiles")
    sub.add_parser("event-source")
    sub.add_parser("self-test")
    sub.add_parser("help")
    sub.add_parser("version")
    sub.add_parser("popup-test")
    watcher_cmd = sub.add_parser("watcher")
    watcher_cmd.add_argument("action", choices=["status", "start", "stop", "restart"], nargs="?", default="status")
    single = sub.add_parser("single")
    single.add_argument("--dry-run", action="store_true")
    for name in ("homeoffice", "home", "office", "layout"):
        command = sub.add_parser(name)
        add_layout_args(command)
    swap = sub.add_parser("swap")
    add_layout_args(swap, allow_swap=False)
    auto = sub.add_parser("auto")
    add_layout_args(auto, allow_swap=False)
    choose = sub.add_parser("choose")
    choose.add_argument("--snapshot")
    choose.add_argument("--detected")
    sub.add_parser("watch")

    parser.set_defaults(snapshot=None, detected=None, dry_run=False, align=None, swap=False)
    args = parser.parse_args()
    cfg = json.loads(Path(args.config).read_text())
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/runtime-{os.getuid()}")) / "hakkabara-monitor"

    if args.cmd is None:
        args.cmd = "choose" if sys.stdin.isatty() else "status"

    if args.cmd == "self-test":
        self_test()
        return
    if args.cmd == "help":
        render_help(cfg)
        return
    if args.cmd == "version":
        print(VERSION)
        return
    if args.cmd == "popup-test":
        current = get_outputs(cfg)
        saved = saved_dual_snapshot(runtime)
        snapshot = latest_usable_snapshot(runtime, current) or saved or current
        if len(connected(snapshot)) != 2:
            raise RuntimeError("popup-test needs a saved or current two-output snapshot")
        source = "current-compatible saved dual" if len(connected(current)) == 2 else "saved dual while current topology is single"
        print(f"popup-test snapshot: {source}")
        detected = detect_profile(cfg, snapshot, include_disabled=True)
        spawned = spawn_popup(
            cfg,
            runtime_file(runtime, "hotplug-snapshot.json"),
            detected,
            runtime,
        )
        print("popup-test: visible" if spawned else "popup-test: selector already running")
        return
    if args.cmd == "watcher":
        action = args.action
        if action == "status":
            proc = run(["systemctl", "--user", "is-active", WATCHER_UNIT], check=False)
            print(proc.stdout.strip() or "unknown")
            return
        proc = run(["systemctl", "--user", action, WATCHER_UNIT], check=False)
        if proc.returncode != 0:
            raise RuntimeError((proc.stderr or proc.stdout or f"failed to {action} watcher").strip())
        state = run(["systemctl", "--user", "is-active", WATCHER_UNIT], check=False).stdout.strip()
        print(f"watcher: {state or 'unknown'}")
        return
    if args.cmd == "status":
        status(cfg)
        current = get_outputs(cfg)
        print(f"Detected: {detect_profile(cfg, current)}")
        print(f"Connected: {len(connected(current))}  Active: {len(active(current))}")
        event_path = runtime / "event-source"
        print(f"Event source: {event_path.read_text().strip() if event_path.exists() else 'not started'}")
        snap_path = runtime / "hotplug-snapshot.json"
        print(f"Saved dual snapshot: {'yes' if snap_path.exists() else 'no'}")
        watcher_state = run(["systemctl", "--user", "is-active", WATCHER_UNIT], check=False).stdout.strip()
        print(f"Watcher service: {watcher_state or 'unknown'}")
        print("Watcher trigger: 1->2 connected OR 1->2 active")
        print("Hint: monitor help")
        return
    if args.cmd == "backend":
        print(backend_name(cfg))
        return
    if args.cmd == "detect":
        print(detect_profile(cfg, get_outputs(cfg)))
        return
    if args.cmd == "profiles":
        for name, profile in cfg.get("profiles", {}).items():
            print(
                f"{name:12} {profile.get('label', name)}  {profile.get('matchSizes')}  "
                f"left={profile.get('leftOutput')} right={profile.get('rightOutput')} "
                f"primary={profile.get('primaryOutput')} align={profile.get('verticalAlignment', 'center')}"
            )
        return
    if args.cmd == "event-source":
        _, label = event_source_command(cfg)
        print(label)
        return
    if args.cmd == "single":
        apply_single(cfg, dry=args.dry_run, runtime_dir=runtime)
        return
    if args.cmd in ("homeoffice", "home", "office", "layout", "swap", "auto"):
        if args.cmd == "auto":
            current = get_outputs(cfg)
            snapshot = latest_usable_snapshot(runtime, current) or current
            detected = detect_profile(cfg, snapshot)
            profile = detected if detected in cfg.get("profiles", {}) else None
            apply_layout(cfg, profile, False, snapshot=snapshot, dry=args.dry_run, runtime_dir=runtime, alignment=args.align)
            return
        profile = "homeoffice" if args.cmd == "home" else (None if args.cmd in ("layout", "swap") else args.cmd)
        swap_outputs = True if args.cmd == "swap" else args.swap
        apply_layout(cfg, profile, swap_outputs, dry=args.dry_run, runtime_dir=runtime, alignment=args.align)
        return
    if args.cmd == "choose":
        if getattr(args, "snapshot", None):
            snapshot = load_snapshot(args.snapshot)
        else:
            current = get_outputs(cfg)
            snapshot = latest_usable_snapshot(runtime, current) or current
        if len(connected(snapshot)) != 2:
            print("No usable two-output topology is available.")
            print("Enable VMware multi-monitor first, or use 'monitor help'.")
            return
        detected = getattr(args, "detected", None) or detect_profile(cfg, snapshot, include_disabled=True)
        tui(cfg, snapshot, detected, int(cfg.get("watcher", {}).get("promptTimeoutSeconds", 10)), runtime)
        return
    if args.cmd == "watch":
        watcher(cfg, runtime)
        return


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
