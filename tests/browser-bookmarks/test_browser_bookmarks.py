import contextlib
import importlib.util
import io
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "modules" / "home" / "apps" / "browsers" / "scripts" / "browser-bookmarks.py"
SPEC = importlib.util.spec_from_file_location("fbm_tested", SCRIPT)
fbm = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = fbm
SPEC.loader.exec_module(fbm)


VALID = """<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
<DT><H3>Bookmarks Menu</H3></DT>
<DL><p><DT><A HREF="https://example.invalid/menu">Menu</A></DT></DL><p>
<DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3></DT>
<DL><p>
<DT><H3>Homelab</H3></DT>
<DL><p>
<DT><H3>Monitoring</H3></DT>
<DL><p></DL><p>
<DT><A HREF="https://example.invalid/proxmox">Proxmox</A></DT>
</DL><p>
<DT><H3>Private</H3></DT><DL><p></DL><p>
</DL><p>
<DT><H3>Other Bookmarks</H3></DT><DL><p></DL><p>
</DL><p>
"""


def tree():
    return fbm.parse_bookmark_html(VALID)


class ParserTests(unittest.TestCase):
    def test_valid(self):
        s = fbm.validate_bookmark_html(VALID)
        self.assertEqual((s.folder_count, s.bookmark_count), (4, 1))

    def test_empty(self):
        with self.assertRaises(fbm.FbmError):
            fbm.parse_bookmark_html("")

    def test_missing_header(self):
        with self.assertRaises(fbm.FbmError):
            fbm.parse_bookmark_html("<html></html>")

    def test_missing_toolbar(self):
        data = "<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><p></DL><p>"
        with self.assertRaises(fbm.FbmError):
            fbm.parse_bookmark_html(data)

    def test_menu_excluded(self):
        root = tree()
        self.assertNotIn("Menu", fbm.serialize_bookmarks(root))

    def test_localized_toolbar_flag_is_supported(self):
        data = """<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
<DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Lesezeichen-Symbolleiste</H3></DT>
<DL><p>
<DT><H3>Homelab</H3></DT><DL><p></DL><p>
</DL><p>
</DL><p>
"""
        root = fbm.parse_bookmark_html(data)
        self.assertEqual(root.name, "Lesezeichen-Symbolleiste")

    def test_roundtrip(self):
        root = tree()
        out = fbm.serialize_bookmarks(root)
        again = fbm.parse_bookmark_html(out)
        self.assertEqual(fbm.summarize_tree(root), fbm.summarize_tree(again))

    def test_html_escaping(self):
        root = tree()
        fbm.add_path(root, "Private/R&D <X>", "https://example.invalid/?a=1&b=2")
        out = fbm.serialize_bookmarks(root)
        self.assertIn("R&amp;D &lt;X&gt;", out)
        self.assertIn("a=1&amp;b=2", out)


class PathTests(unittest.TestCase):
    def test_parts(self):
        self.assertEqual(fbm.path_parts("Homelab/Proxmox"), ["Homelab", "Proxmox"])

    def test_empty_path(self):
        with self.assertRaises(fbm.FbmError):
            fbm.path_parts("")

    def test_double_slash(self):
        with self.assertRaises(fbm.FbmError):
            fbm.path_parts("Homelab//X")

    def test_find_nested(self):
        self.assertEqual(fbm.find_folder(tree(), "Homelab/Monitoring").name, "Monitoring")

    def test_find_root_prefixed(self):
        self.assertEqual(
            fbm.find_folder(tree(), "Bookmarks Toolbar/Homelab").name,
            "Homelab",
        )

    def test_create(self):
        root = tree()
        fbm.create_folder(root, "Homelab/New")
        self.assertEqual(fbm.find_folder(root, "Homelab/New").name, "New")

    def test_create_missing_parent(self):
        with self.assertRaises(fbm.FbmError):
            fbm.create_folder(tree(), "Missing/New")

    def test_create_duplicate(self):
        with self.assertRaises(fbm.FbmError):
            fbm.create_folder(tree(), "Homelab")


class UrlTests(unittest.TestCase):
    def test_https(self):
        self.assertEqual(fbm.validate_url("https://example.invalid"), "https://example.invalid")

    def test_http(self):
        self.assertEqual(fbm.validate_url("http://example.invalid"), "http://example.invalid")

    def test_missing_scheme(self):
        with self.assertRaises(fbm.FbmError):
            fbm.validate_url("example.invalid")

    def test_javascript(self):
        with self.assertRaises(fbm.FbmError):
            fbm.validate_url("javascript:alert(1)")

    def test_relative(self):
        with self.assertRaises(fbm.FbmError):
            fbm.validate_url("/x")

    def test_prompt(self):
        with patch("builtins.input", return_value="https://example.invalid"):
            self.assertEqual(fbm.resolve_add_url(None), "https://example.invalid")

    def test_prompt_eof(self):
        with patch("builtins.input", side_effect=EOFError):
            with self.assertRaises(fbm.FbmError):
                fbm.resolve_add_url(None)


class AddRemoveTests(unittest.TestCase):
    def test_add_path(self):
        root = tree()
        b, folder = fbm.add_path(root, "Homelab/Grafana", "https://example.invalid/g")
        self.assertEqual((b.title, folder.name), ("Grafana", "Homelab"))

    def test_add_deep(self):
        root = tree()
        b, folder = fbm.add_path(
            root, "Homelab/Monitoring/Grafana", "https://example.invalid/g"
        )
        self.assertEqual((b.title, folder.name), ("Grafana", "Monitoring"))

    def test_add_duplicate_casefold(self):
        root = tree()
        with self.assertRaises(fbm.FbmError):
            fbm.add_path(root, "Homelab/PROXMOX", "https://example.invalid/x")

    def test_add_missing_parent(self):
        with self.assertRaises(fbm.FbmError):
            fbm.add_path(tree(), "Missing/X", "https://example.invalid")

    def test_legacy_add(self):
        root = tree()
        b, folder = fbm.add_path(root, "Homelab", "https://example.invalid/x", "X")
        self.assertEqual((b.title, folder.name), ("X", "Homelab"))

    def test_remove_bookmark_path(self):
        root = tree()
        removed = fbm.remove_path(root, "Homelab/Proxmox")
        self.assertIsInstance(removed, fbm.Bookmark)

    def test_remove_empty_folder_path(self):
        root = tree()
        removed = fbm.remove_path(root, "Private")
        self.assertIsInstance(removed, fbm.Folder)

    def test_remove_nonempty_folder(self):
        with self.assertRaises(fbm.FbmError):
            fbm.remove_path(tree(), "Homelab")

    def test_remove_root(self):
        with self.assertRaises(fbm.FbmError):
            fbm.remove_path(tree(), "Bookmarks Toolbar")

    def test_legacy_remove(self):
        root = tree()
        removed = fbm.remove_path(root, "Homelab", "Proxmox")
        self.assertIsInstance(removed, fbm.Bookmark)


class OutputTests(unittest.TestCase):
    def test_ls_hides_urls(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            fbm.print_tree(tree())
        self.assertNotIn("https://", out.getvalue())
        self.assertIn("Proxmox", out.getvalue())

    def test_ls_can_show_urls(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            fbm.print_tree(tree(), show_urls=True)
        self.assertIn("https://example.invalid/proxmox", out.getvalue())


class CipherSafetyTests(unittest.TestCase):
    def test_reject_empty_ciphertext(self):
        with self.assertRaises(fbm.FbmError):
            fbm.validate_ciphertext_candidate(b"")

    def test_reject_plaintext_ciphertext(self):
        with self.assertRaises(fbm.FbmError):
            fbm.validate_ciphertext_candidate(VALID.encode())

    def test_atomic_replace(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "browser-bookmarks"
            target.write_bytes(b"old")
            os.chmod(target, 0o640)
            with patch.object(fbm, "BOOKMARK_FILE", target):
                fbm.atomic_replace_encrypted(b"ciphertext")
            self.assertEqual(target.read_bytes(), b"ciphertext")
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o640)

    def test_atomic_failure_cleans_temp(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "browser-bookmarks"
            target.write_bytes(b"old")
            with patch.object(fbm, "BOOKMARK_FILE", target):
                with patch.object(fbm.os, "replace", side_effect=OSError("boom")):
                    with self.assertRaises(OSError):
                        fbm.atomic_replace_encrypted(b"ciphertext")
            self.assertEqual(target.read_bytes(), b"old")
            self.assertEqual(list(Path(tmp).glob(".browser-bookmarks.*.tmp")), [])

    def test_encrypt_error_does_not_expose_stderr(self):
        with patch.object(fbm, "find_program", return_value="/fake/sops"):
            with patch.object(
                fbm.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(
                    [], 1, stdout=b"", stderr=b"https://secret.invalid"
                ),
            ):
                with self.assertRaises(fbm.FbmError) as err:
                    fbm.encrypt_bookmarks("x")
        self.assertNotIn("secret.invalid", str(err.exception))

    def test_decrypt_error_does_not_expose_stderr(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "encrypted"
            target.write_bytes(b"x")
            with patch.object(fbm, "BOOKMARK_FILE", target):
                with patch.object(fbm, "find_program", side_effect=lambda n: f"/fake/{n}"):
                    with patch.object(
                        fbm.subprocess,
                        "run",
                        return_value=subprocess.CompletedProcess(
                            [], 1, stdout=b"", stderr=b"https://secret.invalid"
                        ),
                    ):
                        with self.assertRaises(fbm.FbmError) as err:
                            fbm.decrypt_bookmarks()
        self.assertNotIn("secret.invalid", str(err.exception))


class ImportTests(unittest.TestCase):
    def make(self, directory, content=VALID, mode=0o600, name="bookmarks.html"):
        p = Path(directory) / name
        p.write_bytes(content.encode("utf-8"))
        os.chmod(p, mode)
        return p

    def test_valid_import(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            c = fbm.load_import_candidate(p)
            self.assertEqual((c.summary.folder_count, c.summary.bookmark_count), (4, 1))

    def test_import_toolbar_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = fbm.load_import_candidate(self.make(tmp))
            out = fbm.serialize_bookmarks(c.root)
            self.assertNotIn("Bookmarks Menu", out)
            self.assertNotIn(">Menu<", out)

    def test_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(fbm.FbmError):
                fbm.load_import_candidate(Path(tmp) / "nope")

    def test_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            link = Path(tmp) / "link"
            link.symlink_to(p)
            with self.assertRaises(fbm.FbmError):
                fbm.load_import_candidate(link)

    def test_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(fbm.FbmError, "chmod 600"):
                fbm.load_import_candidate(self.make(tmp, mode=0o644))

    def test_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "bookmarks.html"
            p.write_bytes(b"")
            os.chmod(p, 0o600)
            with self.assertRaises(fbm.FbmError):
                fbm.load_import_candidate(p)

    def test_nul(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "bookmarks.html"
            p.write_bytes(VALID.encode() + b"\x00")
            os.chmod(p, 0o600)
            with self.assertRaises(fbm.FbmError):
                fbm.load_import_candidate(p)

    def test_invalid_utf8(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "bookmarks.html"
            p.write_bytes(b"\xff\xfe\xff")
            os.chmod(p, 0o600)
            with self.assertRaises(fbm.FbmError):
                fbm.load_import_candidate(p)

    def test_repo_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            p = self.make(repo)
            with patch.object(fbm, "REPO_ROOT", repo):
                with self.assertRaisesRegex(fbm.FbmError, "repository"):
                    fbm.load_import_candidate(p)

    def test_too_large_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            with patch.object(fbm, "MAX_IMPORT_BYTES", 1):
                with self.assertRaises(fbm.FbmError):
                    fbm.load_import_candidate(p)

    def test_confirmation_default_no(self):
        with patch("builtins.input", return_value=""):
            self.assertFalse(fbm.confirm_import())

    def test_confirmation_yes(self):
        with patch("builtins.input", return_value="yes"):
            self.assertTrue(fbm.confirm_import())

    def test_command_dry_run_does_not_save(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            args = type("A", (), {"file": str(p), "dry_run": True, "yes": False, "delete_source": False})
            with patch.object(fbm, "save_tree") as save:
                fbm.command_import(args)
            save.assert_not_called()
            self.assertTrue(p.exists())

    def test_command_cancel_does_not_save(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            args = type("A", (), {"file": str(p), "dry_run": False, "yes": False, "delete_source": False})
            with patch.object(fbm, "confirm_import", return_value=False):
                with patch.object(fbm, "save_tree") as save:
                    fbm.command_import(args)
            save.assert_not_called()

    def test_delete_source_only_after_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            args = type("A", (), {"file": str(p), "dry_run": False, "yes": True, "delete_source": True})
            with patch.object(fbm, "save_tree", side_effect=fbm.FbmError("fail")):
                with self.assertRaises(fbm.FbmError):
                    fbm.command_import(args)
            self.assertTrue(p.exists())

    def test_delete_source_after_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.make(tmp)
            args = type("A", (), {"file": str(p), "dry_run": False, "yes": True, "delete_source": True})
            with patch.object(fbm, "save_tree"):
                fbm.command_import(args)
            self.assertFalse(p.exists())



class ConfigurationTests(unittest.TestCase):
    def test_valid_configuration(self):
        with (
            patch.object(fbm, "REPO_ROOT", Path("/tmp/nix-config")),
            patch.object(
                fbm,
                "BOOKMARK_SOURCE",
                "secrets/browser-bookmarks",
            ),
            patch.object(
                fbm,
                "DOCUMENT_TITLE",
                "Browser Bookmarks",
            ),
        ):
            fbm.validate_configuration()

    def test_relative_repository_root_rejected(self):
        with patch.object(
            fbm,
            "REPO_ROOT",
            Path("relative/repo"),
        ):
            with self.assertRaisesRegex(
                fbm.FbmError,
                "repository root must be an absolute path",
            ):
                fbm.validate_configuration()

    def test_absolute_bookmark_source_rejected(self):
        with (
            patch.object(
                fbm,
                "REPO_ROOT",
                Path("/tmp/nix-config"),
            ),
            patch.object(
                fbm,
                "BOOKMARK_SOURCE",
                "/tmp/bookmarks",
            ),
        ):
            with self.assertRaisesRegex(
                fbm.FbmError,
                "bookmark source must be relative",
            ):
                fbm.validate_configuration()

    def test_parent_traversal_rejected(self):
        with (
            patch.object(
                fbm,
                "REPO_ROOT",
                Path("/tmp/nix-config"),
            ),
            patch.object(
                fbm,
                "BOOKMARK_SOURCE",
                "../bookmarks",
            ),
        ):
            with self.assertRaisesRegex(
                fbm.FbmError,
                "must not contain",
            ):
                fbm.validate_configuration()

    def test_empty_bookmark_source_rejected(self):
        with (
            patch.object(
                fbm,
                "REPO_ROOT",
                Path("/tmp/nix-config"),
            ),
            patch.object(
                fbm,
                "BOOKMARK_SOURCE",
                "",
            ),
        ):
            with self.assertRaisesRegex(
                fbm.FbmError,
                "must not be empty",
            ):
                fbm.validate_configuration()

    def test_empty_document_title_rejected(self):
        with (
            patch.object(
                fbm,
                "REPO_ROOT",
                Path("/tmp/nix-config"),
            ),
            patch.object(
                fbm,
                "BOOKMARK_SOURCE",
                "secrets/browser-bookmarks",
            ),
            patch.object(
                fbm,
                "DOCUMENT_TITLE",
                "",
            ),
        ):
            with self.assertRaisesRegex(
                fbm.FbmError,
                "document title must not be empty",
            ):
                fbm.validate_configuration()

    def test_configurable_document_title_is_escaped(self):
        with patch.object(
            fbm,
            "DOCUMENT_TITLE",
            "Private & Work",
        ):
            output = fbm.serialize_bookmarks(tree())

        self.assertIn(
            "<TITLE>Private &amp; Work</TITLE>",
            output,
        )
        self.assertIn(
            "<H1>Private &amp; Work</H1>",
            output,
        )


class CliTests(unittest.TestCase):
    def test_version(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as err:
                fbm.build_parser().parse_args(["--version"])
        self.assertEqual(err.exception.code, 0)
        self.assertIn("browser-bookmarks 0.4.0", out.getvalue())

    def test_add_path_parse(self):
        args = fbm.build_parser().parse_args(["add", "Homelab/Proxmox"])
        self.assertEqual(args.path, "Homelab/Proxmox")
        self.assertIsNone(args.title)

    def test_legacy_add_parse(self):
        args = fbm.build_parser().parse_args(["add", "Homelab", "Proxmox"])
        self.assertEqual((args.path, args.title), ("Homelab", "Proxmox"))

    def test_rm_path_parse(self):
        args = fbm.build_parser().parse_args(["rm", "Homelab/Proxmox"])
        self.assertEqual(args.path, "Homelab/Proxmox")
        self.assertIsNone(args.name)

    def test_import_parse(self):
        args = fbm.build_parser().parse_args(
            ["import", "/tmp/x.html", "--dry-run", "--delete-source"]
        )
        self.assertTrue(args.dry_run)
        self.assertTrue(args.delete_source)


if __name__ == "__main__":
    unittest.main()
