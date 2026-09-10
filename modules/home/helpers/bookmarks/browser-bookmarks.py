#!/usr/bin/env python3
"""SOPS-encrypted bookmark manager for Gecko browsers."""

from __future__ import annotations

import argparse
import html
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit


VERSION = "0.4.0"

PROGRAM_NAME = os.environ.get(
    "BROWSER_BOOKMARK_PROGRAM_NAME",
    "browser-bookmarks",
)

REPO_ROOT = Path(
    os.environ.get(
        "BROWSER_BOOKMARK_REPO_ROOT",
        str(Path.home() / "nix-config"),
    )
).expanduser()

BOOKMARK_SOURCE = os.environ.get(
    "BROWSER_BOOKMARK_SOURCE",
    "secrets/browser-bookmarks",
)

BOOKMARK_SOURCE_PATH = Path(BOOKMARK_SOURCE)
BOOKMARK_FILE = REPO_ROOT / BOOKMARK_SOURCE_PATH

SOPS_AGE_KEY_FILE = Path(
    os.environ.get(
        "BROWSER_BOOKMARK_AGE_KEY_FILE",
        "/var/lib/sops-nix/key.txt",
    )
).expanduser()

SOPS_FILENAME_OVERRIDE = BOOKMARK_SOURCE_PATH.as_posix()

DOCUMENT_TITLE = os.environ.get(
    "BROWSER_BOOKMARK_DOCUMENT_TITLE",
    "Browser Bookmarks",
)

MAX_IMPORT_BYTES = 20 * 1024 * 1024


class FbmError(Exception):
    """Expected user/runtime error."""


def validate_configuration() -> None:
    if not REPO_ROOT.is_absolute():
        raise FbmError(
            "configured repository root must be an absolute path"
        )

    if not BOOKMARK_SOURCE.strip():
        raise FbmError(
            "configured bookmark source must not be empty"
        )

    source = Path(BOOKMARK_SOURCE)

    if source.is_absolute():
        raise FbmError(
            "configured bookmark source must be relative "
            "to the repository root"
        )

    if ".." in source.parts:
        raise FbmError(
            "configured bookmark source must not contain '..'"
        )

    if not DOCUMENT_TITLE.strip():
        raise FbmError(
            "configured bookmark document title must not be empty"
        )


@dataclass
class Bookmark:
    title: str
    url: str


@dataclass
class Folder:
    name: str
    children: list[Folder | Bookmark] = field(default_factory=list)
    personal_toolbar: bool = False


@dataclass(frozen=True)
class BookmarkSummary:
    folder_count: int
    bookmark_count: int


@dataclass(frozen=True)
class ImportCandidate:
    path: Path
    root: Folder
    summary: BookmarkSummary


class NetscapeBookmarkParser(HTMLParser):
    """Parse Netscape/Firefox bookmark HTML into a simple tree."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.document = Folder("__document__")
        self.folder_stack = [self.document]
        self.dl_pushes: list[bool] = []
        self.capture: str | None = None
        self.text: list[str] = []
        self.link_href: str | None = None
        self.pending_folder: Folder | None = None
        self.h3_toolbar = False

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()

        if tag == "dl":
            if self.pending_folder is not None:
                self.folder_stack.append(self.pending_folder)
                self.pending_folder = None
                self.dl_pushes.append(True)
            else:
                self.dl_pushes.append(False)
            return

        if tag == "h3":
            self.capture = "h3"
            self.text = []
            attributes = {
                key.lower(): value
                for key, value in attrs
                if key is not None
            }
            self.h3_toolbar = (
                str(attributes.get("personal_toolbar_folder", "")).lower()
                == "true"
            )
            return

        if tag == "a":
            self.capture = "a"
            self.text = []
            attributes = {
                key.lower(): value
                for key, value in attrs
                if key is not None
            }
            self.link_href = attributes.get("href")

    def handle_data(self, data):
        if self.capture is not None:
            self.text.append(data)

    def handle_endtag(self, tag):
        tag = tag.lower()

        if tag == "dl":
            if self.dl_pushes:
                pushed = self.dl_pushes.pop()
                if pushed and len(self.folder_stack) > 1:
                    self.folder_stack.pop()
            return

        if tag != self.capture:
            return

        text = "".join(self.text).strip()

        if tag == "h3" and text:
            folder = Folder(
                text,
                personal_toolbar=self.h3_toolbar,
            )
            self.folder_stack[-1].children.append(folder)
            self.pending_folder = folder

        elif tag == "a" and text and self.link_href:
            self.folder_stack[-1].children.append(
                Bookmark(title=text, url=self.link_href)
            )

        self.capture = None
        self.text = []
        self.link_href = None
        self.h3_toolbar = False


def clean_text(value: str, label: str) -> str:
    value = value.strip()
    if not value:
        raise FbmError(f"{label} must not be empty")
    if any(ord(character) < 32 for character in value):
        raise FbmError(f"{label} contains control characters")
    return value


def clean_folder_name(value: str) -> str:
    value = clean_text(value, "folder name")
    if "/" in value:
        raise FbmError("folder name must not contain '/'")
    return value


def path_parts(path: str) -> list[str]:
    path = path.strip()
    if not path:
        raise FbmError("path must not be empty")

    parts = path.split("/")
    if any(not part.strip() for part in parts):
        raise FbmError("path contains an empty component")

    return [clean_folder_name(part) for part in parts]


def folder_children(folder: Folder) -> list[Folder]:
    return [child for child in folder.children if isinstance(child, Folder)]


def bookmark_children(folder: Folder) -> list[Bookmark]:
    return [child for child in folder.children if isinstance(child, Bookmark)]


def find_child_by_name(folder: Folder, name: str) -> Folder | Bookmark | None:
    wanted = name.casefold()
    for child in folder.children:
        child_name = child.name if isinstance(child, Folder) else child.title
        if child_name.casefold() == wanted:
            return child
    return None


def walk_folders(root: Folder):
    yield root
    for child in root.children:
        if isinstance(child, Folder):
            yield from walk_folders(child)


def summarize_tree(root: Folder) -> BookmarkSummary:
    folders = 0
    bookmarks = 0
    for folder in walk_folders(root):
        folders += 1
        bookmarks += len(bookmark_children(folder))
    return BookmarkSummary(folders, bookmarks)


def parse_document(data: str) -> Folder:
    if not data or not data.strip():
        raise FbmError("bookmark source is empty")

    if "NETSCAPE-Bookmark-file-1" not in data[:2048]:
        raise FbmError("bookmark source is not a Netscape bookmark document")

    parser = NetscapeBookmarkParser()
    try:
        parser.feed(data)
        parser.close()
    except Exception as error:
        raise FbmError(f"failed to parse bookmark HTML: {error}") from error

    return parser.document


def extract_toolbar(document: Folder) -> Folder:
    flagged = [
        child
        for child in document.children
        if isinstance(child, Folder)
        and child.personal_toolbar
    ]

    if len(flagged) == 1:
        return flagged[0]

    if len(flagged) > 1:
        raise FbmError(
            "multiple PERSONAL_TOOLBAR_FOLDER entries found"
        )

    named = [
        child
        for child in document.children
        if isinstance(child, Folder)
        and child.name.casefold() == "bookmarks toolbar".casefold()
    ]

    if len(named) != 1:
        raise FbmError(
            "required Bookmarks Toolbar folder is missing or ambiguous"
        )

    return named[0]


def parse_bookmark_html(data: str) -> Folder:
    return extract_toolbar(parse_document(data))


def validate_bookmark_html(data: str) -> BookmarkSummary:
    return summarize_tree(parse_bookmark_html(data))


def _strip_root_prefix(root: Folder, parts: list[str]) -> list[str]:
    if parts and parts[0].casefold() == root.name.casefold():
        return parts[1:]
    return parts


def find_folder(root: Folder, path: str) -> Folder:
    parts = _strip_root_prefix(root, path_parts(path))
    current = root

    for part in parts:
        match = next(
            (
                child
                for child in folder_children(current)
                if child.name.casefold() == part.casefold()
            ),
            None,
        )
        if match is None:
            raise FbmError(f"folder not found: {path}")
        current = match

    return current


def create_folder(root: Folder, path: str) -> Folder:
    parts = _strip_root_prefix(root, path_parts(path))
    if not parts:
        raise FbmError(f"folder already exists: {root.name}")

    parent = root if len(parts) == 1 else find_folder(root, "/".join(parts[:-1]))
    name = parts[-1]

    if find_child_by_name(parent, name) is not None:
        raise FbmError(f"item already exists in '{parent.name}': {name}")

    folder = Folder(name)
    parent.children.append(folder)
    return folder


def validate_url(url: str) -> str:
    url = url.strip()

    if not url:
        raise FbmError("URL must not be empty")

    if any(ord(character) < 32 for character in url):
        raise FbmError("URL contains control characters")

    parsed = urlsplit(url)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise FbmError("URL must use http:// or https://")

    if not parsed.netloc:
        raise FbmError("URL must be an absolute http(s) URL")

    return url


def resolve_add_url(cli_url: str | None) -> str:
    if cli_url is not None:
        return validate_url(cli_url)

    try:
        return validate_url(input("URL: "))
    except EOFError as error:
        raise FbmError(
            "URL is required. Provide it interactively or explicitly."
        ) from error


def add_bookmark(
    root: Folder,
    folder_path: str,
    title: str,
    url: str,
) -> Bookmark:
    folder = find_folder(root, folder_path)
    title = clean_text(title, "bookmark title")
    url = validate_url(url)

    if find_child_by_name(folder, title) is not None:
        raise FbmError(f"item already exists in '{folder.name}': {title}")

    bookmark = Bookmark(title=title, url=url)
    folder.children.append(bookmark)
    return bookmark


def resolve_add_target(
    root: Folder,
    path: str,
    legacy_title: str | None = None,
) -> tuple[Folder, str]:
    if legacy_title is not None:
        return find_folder(root, path), clean_text(legacy_title, "bookmark title")

    parts = _strip_root_prefix(root, path_parts(path))
    if not parts:
        raise FbmError("bookmark path must include a bookmark title")

    title = clean_text(parts[-1], "bookmark title")
    folder = root if len(parts) == 1 else find_folder(root, "/".join(parts[:-1]))
    return folder, title


def add_path(
    root: Folder,
    path: str,
    url: str,
    legacy_title: str | None = None,
) -> tuple[Bookmark, Folder]:
    folder, title = resolve_add_target(root, path, legacy_title)
    url = validate_url(url)

    if find_child_by_name(folder, title) is not None:
        raise FbmError(f"item already exists in '{folder.name}': {title}")

    bookmark = Bookmark(title=title, url=url)
    folder.children.append(bookmark)
    return bookmark, folder


def remove_child(parent: Folder, name: str) -> Folder | Bookmark:
    name = clean_text(name, "item name")
    wanted = name.casefold()

    for index, child in enumerate(parent.children):
        child_name = child.name if isinstance(child, Folder) else child.title
        if child_name.casefold() != wanted:
            continue

        if isinstance(child, Folder) and child.children:
            raise FbmError(f"refusing to remove non-empty folder: {child.name}")

        return parent.children.pop(index)

    raise FbmError(f"item not found in '{parent.name}': {name}")


def remove_item(root: Folder, folder_path: str, name: str) -> Folder | Bookmark:
    return remove_child(find_folder(root, folder_path), name)


def resolve_remove_target(
    root: Folder,
    path: str,
    legacy_name: str | None = None,
) -> tuple[Folder, str]:
    if legacy_name is not None:
        return find_folder(root, path), clean_text(legacy_name, "item name")

    parts = _strip_root_prefix(root, path_parts(path))
    if not parts:
        raise FbmError("refusing to remove the Bookmarks Toolbar root")

    name = parts[-1]
    parent = root if len(parts) == 1 else find_folder(root, "/".join(parts[:-1]))
    return parent, name


def remove_path(
    root: Folder,
    path: str,
    legacy_name: str | None = None,
) -> Folder | Bookmark:
    parent, name = resolve_remove_target(root, path, legacy_name)
    return remove_child(parent, name)


def serialize_folder(
    folder: Folder,
    indent: int = 0,
    toolbar: bool = False,
) -> list[str]:
    prefix = " " * indent
    name = html.escape(folder.name, quote=True)
    toolbar_attribute = ' PERSONAL_TOOLBAR_FOLDER="true"' if toolbar else ""

    lines = [
        f"{prefix}<DT><H3{toolbar_attribute}>{name}</H3></DT>",
        f"{prefix}<DL><p>",
    ]

    for child in folder.children:
        if isinstance(child, Folder):
            lines.extend(serialize_folder(child, indent + 4))
            continue

        title = html.escape(child.title, quote=True)
        url = html.escape(child.url, quote=True)
        lines.append(f'{prefix}    <DT><A HREF="{url}">{title}</A></DT>')

    lines.append(f"{prefix}</DL><p>")
    return lines


def serialize_bookmarks(root: Folder) -> str:
    lines = [
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
        f"<TITLE>{html.escape(DOCUMENT_TITLE, quote=True)}</TITLE>",
        f"<H1>{html.escape(DOCUMENT_TITLE, quote=True)}</H1>",
        "",
        "<DL><p>",
    ]
    lines.extend(serialize_folder(root, indent=4, toolbar=True))
    lines.extend(["</DL><p>", ""])
    return "\n".join(lines)


def find_program(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise FbmError(f"required command not found: {name}")
    return path


def decrypt_bookmarks() -> str:
    if not BOOKMARK_FILE.is_file():
        raise FbmError(f"encrypted bookmark source does not exist: {BOOKMARK_FILE}")

    command = [
        find_program("sudo"),
        "env",
        f"SOPS_AGE_KEY_FILE={SOPS_AGE_KEY_FILE}",
        find_program("sops"),
        "decrypt",
        "--input-type",
        "binary",
        "--output-type",
        "binary",
        str(BOOKMARK_FILE),
    ]

    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as error:
        raise FbmError(f"failed to execute SOPS: {error}") from error

    if result.returncode != 0:
        if result.returncode == 130:
            raise FbmError("decryption cancelled")
        raise FbmError(
            "SOPS decryption failed "
            f"(exit code {result.returncode}). "
            "Check sudo access and the configured age key."
        )

    try:
        return result.stdout.decode("utf-8")
    except UnicodeDecodeError as error:
        raise FbmError("decrypted bookmark source is not valid UTF-8") from error


def validate_ciphertext_candidate(data: bytes) -> None:
    if not data:
        raise FbmError("refusing to install empty encrypted output")

    plaintext_markers = (
        b"NETSCAPE-Bookmark-file-1",
    )
    if any(marker in data for marker in plaintext_markers):
        raise FbmError(
            "refusing to replace encrypted source with plaintext bookmark data"
        )


def encrypt_bookmarks(data: str) -> bytes:
    command = [
        find_program("sops"),
        "encrypt",
        "--filename-override",
        SOPS_FILENAME_OVERRIDE,
        "--input-type",
        "binary",
        "--output-type",
        "binary",
    ]

    try:
        result = subprocess.run(
            command,
            input=data.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=REPO_ROOT,
            check=False,
        )
    except OSError as error:
        raise FbmError(f"failed to execute SOPS encryption: {error}") from error

    if result.returncode != 0:
        raise FbmError(f"SOPS encryption failed (exit code {result.returncode})")

    validate_ciphertext_candidate(result.stdout)
    return result.stdout


def atomic_replace_encrypted(ciphertext: bytes) -> None:
    validate_ciphertext_candidate(ciphertext)

    target = BOOKMARK_FILE
    parent = target.parent
    if not parent.is_dir():
        raise FbmError(f"bookmark source directory does not exist: {parent}")

    mode = stat.S_IMODE(target.stat().st_mode) if target.exists() else 0o600

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.",
        suffix=".tmp",
        dir=parent,
    )
    temporary = Path(temporary_name)

    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(ciphertext)
            handle.flush()
            os.fsync(handle.fileno())

        os.chmod(temporary, mode)
        os.replace(temporary, target)

        try:
            directory_fd = os.open(
                parent,
                os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
            )
        except OSError:
            directory_fd = None

        if directory_fd is not None:
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)

    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def save_tree(root: Folder) -> None:
    plaintext = serialize_bookmarks(root)
    validate_bookmark_html(plaintext)
    ciphertext = encrypt_bookmarks(plaintext)
    atomic_replace_encrypted(ciphertext)


def load_tree() -> Folder:
    return parse_bookmark_html(decrypt_bookmarks())


def validate_import_source(path: str | Path) -> Path:
    requested = Path(path).expanduser()

    if requested.is_symlink():
        raise FbmError("refusing to import from a symlink")

    try:
        resolved = requested.resolve(strict=True)
    except FileNotFoundError as error:
        raise FbmError(f"import file does not exist: {requested}") from error

    if not resolved.is_file():
        raise FbmError(f"import source is not a regular file: {resolved}")

    repo = REPO_ROOT.resolve()
    if resolved == repo or resolved.is_relative_to(repo):
        raise FbmError(
            "refusing to read plaintext bookmarks from inside the Git repository"
        )

    metadata = resolved.stat()
    if metadata.st_uid != os.getuid():
        raise FbmError("import file is not owned by the current user")

    mode = stat.S_IMODE(metadata.st_mode)
    if mode & 0o077:
        raise FbmError(
            "plaintext bookmark export is readable by group or others; "
            "run: chmod 600 FILE"
        )

    if metadata.st_size == 0:
        raise FbmError("import file is empty")

    if metadata.st_size > MAX_IMPORT_BYTES:
        raise FbmError(
            "import file is unexpectedly large "
            f"({metadata.st_size} bytes; maximum {MAX_IMPORT_BYTES} bytes)"
        )

    return resolved


def load_import_candidate(path: str | Path) -> ImportCandidate:
    source = validate_import_source(path)

    try:
        raw = source.read_bytes()
    except OSError as error:
        raise FbmError(f"failed to read import file: {source}") from error

    if b"\x00" in raw:
        raise FbmError("import file contains unexpected NUL bytes")

    try:
        plaintext = raw.decode("utf-8-sig")
    except UnicodeDecodeError as error:
        raise FbmError("import file is not valid UTF-8") from error

    root = parse_bookmark_html(plaintext)

    # Canonicalize the special Gecko toolbar root name so the repository
    # representation stays stable even when Firefox exports a localized name.
    root.name = "Bookmarks Toolbar"
    root.personal_toolbar = True

    # Normalize to the exact canonical representation we persist.
    normalized = serialize_bookmarks(root)
    summary = validate_bookmark_html(normalized)

    return ImportCandidate(source, root, summary)


def confirm_import() -> bool:
    try:
        answer = input("Replace encrypted bookmark source? [y/N]: ")
    except EOFError:
        return False
    return answer.strip().casefold() in {"y", "yes"}


def command_check(_args) -> None:
    summary = validate_bookmark_html(decrypt_bookmarks())
    print("Browser bookmark source: OK")
    print(f"Source:    {BOOKMARK_FILE}")
    print(f"Folders:   {summary.folder_count}")
    print(f"Bookmarks: {summary.bookmark_count}")


def print_tree(
    folder: Folder,
    indent: int = 0,
    show_urls: bool = False,
) -> None:
    prefix = "  " * indent
    for child in folder.children:
        if isinstance(child, Folder):
            print(f"{prefix}[Folder] {child.name}")
            print_tree(child, indent + 1, show_urls)
        elif show_urls:
            print(f"{prefix}[Bookmark] {child.title} -> {child.url}")
        else:
            print(f"{prefix}[Bookmark] {child.title}")


def command_list(args) -> None:
    root = load_tree()
    print(f"[Folder] {root.name}")
    print_tree(root, indent=1, show_urls=args.urls)


def command_folder(args) -> None:
    root = load_tree()
    create_folder(root, args.path)

    if args.dry_run:
        print(f"Dry run: would create folder '{args.path}'")
        return

    save_tree(root)
    print(f"Created folder: {args.path}")
    print("Encrypted repository source updated.")
    print("Run nix-switch before expecting runtime browser bookmarks to change.")


def command_add(args) -> None:
    root = load_tree()

    if args.url_option is not None and args.url is not None:
        raise FbmError(
            "URL was provided twice; use either positional URL or --url, not both"
        )

    cli_url = args.url_option if args.url_option is not None else args.url
    bookmark, _folder = add_path(
        root,
        args.path,
        resolve_add_url(cli_url),
        args.title,
    )

    display_path = (
        f"{args.path}/{args.title}" if args.title is not None else args.path
    )

    if args.dry_run:
        print(f"Dry run: would add bookmark '{display_path}'")
        return

    save_tree(root)
    print(f"Added bookmark: {display_path}")
    print("Encrypted repository source updated.")
    print("Run nix-switch before expecting runtime browser bookmarks to change.")


def command_remove(args) -> None:
    root = load_tree()
    removed = remove_path(root, args.path, args.name)
    item_type = "folder" if isinstance(removed, Folder) else "bookmark"
    display_path = f"{args.path}/{args.name}" if args.name else args.path

    if args.dry_run:
        print(f"Dry run: would remove {item_type} '{display_path}'")
        return

    save_tree(root)
    print(f"Removed {item_type}: {display_path}")
    print("Encrypted repository source updated.")
    print("Run nix-switch before expecting runtime browser bookmarks to change.")


def command_import(args) -> None:
    candidate = load_import_candidate(args.file)

    print("Browser bookmark import candidate:")
    print(f"  Source:    {candidate.path}")
    print("  Scope:     Bookmarks Toolbar only")
    print(f"  Folders:   {candidate.summary.folder_count}")
    print(f"  Bookmarks: {candidate.summary.bookmark_count}")
    print()
    print("The encrypted repository bookmark source will be replaced.")

    if args.dry_run:
        print("Dry run: validation successful; nothing was written.")
        return

    if not args.yes and not confirm_import():
        print("Import cancelled; nothing was written.")
        return

    save_tree(candidate.root)
    print("Encrypted bookmark source replaced successfully.")

    if args.delete_source:
        try:
            candidate.path.unlink()
        except OSError as error:
            raise FbmError(
                "encrypted bookmark source was updated, but the plaintext "
                f"import file could not be deleted: {candidate.path}"
            ) from error
        print("Plaintext import file deleted.")
    else:
        print("WARNING: plaintext import file still exists:")
        print(f"  {candidate.path}")

    print("Run nix-switch to refresh the runtime secret.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=PROGRAM_NAME,
        description=(
            "Browser Bookmark Manager\n\n"
            "Manage the SOPS-encrypted Gecko bookmark source of truth."
        ),
        epilog=(
            "Security model:\n"
            "  * The encrypted repository file is the source of truth.\n"
            "  * Decryption uses the configured age key.\n"
            "  * Plaintext bookmark data is not written to repo-side temp files.\n"
            "  * Private URLs are hidden by default in `browser-bookmarks ls`.\n"
            "  * Prefer `browser-bookmarks add PATH` and enter the URL at the prompt.\n"
            "  * Mutations validate, encrypt, then atomically replace ciphertext.\n"
            "  * Empty/plaintext encrypted output is refused.\n"
            "  * Non-empty folders cannot be removed accidentally.\n"
            "  * Gecko/Netscape HTML imports must be outside the repo and mode 0600.\n"
            "\n"
            "Examples:\n"
            "  browser-bookmarks check\n"
            "  browser-bookmarks ls\n"
            "  browser-bookmarks ls --urls\n"
            "  browser-bookmarks folder 'Homelab/Monitoring'\n"
            "  browser-bookmarks add 'Homelab/Proxmox'\n"
            "  browser-bookmarks add 'Homelab/Monitoring/Grafana'\n"
            "  browser-bookmarks rm 'Homelab/Monitoring/Grafana'\n"
            "  browser-bookmarks import ~/Downloads/bookmarks.html --dry-run\n"
            "  browser-bookmarks import ~/Downloads/bookmarks.html --delete-source\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {VERSION}",
    )

    commands = parser.add_subparsers(
        dest="command",
        title="commands",
        metavar="COMMAND",
        required=True,
    )

    check_parser = commands.add_parser(
        "check",
        help="Decrypt and validate the bookmark source.",
    )
    check_parser.set_defaults(func=command_check)

    list_parser = commands.add_parser(
        "ls",
        help="Show the bookmark tree.",
    )
    list_parser.add_argument(
        "--urls",
        action="store_true",
        help="Also show bookmark URLs.",
    )
    list_parser.set_defaults(func=command_list)

    folder_parser = commands.add_parser(
        "folder",
        help="Create a folder.",
    )
    folder_parser.add_argument(
        "path",
        help="Folder path, e.g. 'Homelab/Monitoring'.",
    )
    folder_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate without writing.",
    )
    folder_parser.set_defaults(func=command_folder)

    add_parser = commands.add_parser(
        "add",
        help="Add a bookmark by path.",
        description=(
            "Preferred:\n"
            "  browser-bookmarks add 'Homelab/Proxmox'\n"
            "  browser-bookmarks add 'Homelab/Monitoring/Grafana'\n"
            "\n"
            "The URL is prompted when omitted, keeping private URLs "
            "out of shell history.\n"
            "\n"
            "Compatibility:\n"
            "  browser-bookmarks add FOLDER TITLE [URL]"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    add_parser.add_argument(
        "path",
        help="Full bookmark path, or parent folder in legacy mode.",
    )
    add_parser.add_argument(
        "title",
        nargs="?",
        help="Optional legacy bookmark title.",
    )
    add_parser.add_argument(
        "url",
        nargs="?",
        help="Optional legacy positional http(s) URL.",
    )
    add_parser.add_argument(
        "--url",
        dest="url_option",
        help="Explicit http(s) URL for scripting.",
    )
    add_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate without writing.",
    )
    add_parser.set_defaults(func=command_add)

    remove_parser = commands.add_parser(
        "rm",
        help="Remove a bookmark or empty folder by path.",
        description=(
            "Preferred:\n"
            "  browser-bookmarks rm Homelab\n"
            "  browser-bookmarks rm 'Homelab/Monitoring'\n"
            "  browser-bookmarks rm 'Homelab/Monitoring/Grafana'\n"
            "\n"
            "Compatibility:\n"
            "  browser-bookmarks rm PARENT NAME"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    remove_parser.add_argument(
        "path",
        help="Full item path, or parent folder in legacy mode.",
    )
    remove_parser.add_argument(
        "name",
        nargs="?",
        help="Optional legacy child name.",
    )
    remove_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate without writing.",
    )
    remove_parser.set_defaults(func=command_remove)

    import_parser = commands.add_parser(
        "import",
        help="Replace encrypted source from a Gecko/Netscape HTML export.",
        description=(
            "Import a Gecko/Netscape bookmark HTML export.\n\n"
            "Only the Bookmarks Toolbar subtree becomes canonical.\n"
            "The plaintext source must be outside the Git repository,\n"
            "owned by the current user and mode 0600.\n\n"
            "Recommended:\n"
            "  browser-bookmarks import ~/Downloads/bookmarks.html --dry-run\n"
            "  browser-bookmarks import ~/Downloads/bookmarks.html --delete-source"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    import_parser.add_argument(
        "file",
        help="Gecko/Netscape bookmark HTML export.",
    )
    import_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and summarize without writing.",
    )
    import_parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip replacement confirmation.",
    )
    import_parser.add_argument(
        "--delete-source",
        action="store_true",
        help="Delete plaintext HTML after successful encrypted replacement.",
    )
    import_parser.set_defaults(func=command_import)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    try:
        validate_configuration()
        args.func(args)
    except FbmError as error:
        print(f"{PROGRAM_NAME}: error: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print(f"\n{PROGRAM_NAME}: cancelled by user", file=sys.stderr)
        sys.exit(130)


if __name__ == "__main__":
    main()
