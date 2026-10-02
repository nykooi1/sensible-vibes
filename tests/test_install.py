"""The portable bundle works independently and leaves project notes untouched."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/install.py"
spec = importlib.util.spec_from_file_location("vibe_wise_install", SCRIPT)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="vibe-wise-bundle-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.project = self.root / "project with spaces"
        self.project.mkdir()
        (self.project / ".git").mkdir()
        self.source = self.root / "source"
        self.source.mkdir()
        for relative in installer.BUNDLE_FILES:
            target = self.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(str(ROOT / relative), str(target))
        # Packaging is an allowlist, even when unrelated files exist at the source.
        for relative in ("hooks/session_start.py", ".claude-plugin/plugin.json",
                         "vibe_wise/__pycache__/state.pyc", ".vibe-wise/profile.md"):
            target = self.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("not part of the portable skill", encoding="utf-8")
        self.destination = self.project / ".agents/skills/vibe-wise"

    def install(self, **kwargs):
        return installer.install(self.project, source_root=self.source, **kwargs)

    def snapshot(self, root=None):
        root = root or self.project
        return {
            path.relative_to(root).as_posix(): path.read_bytes()
            for path in root.rglob("*") if path.is_file() and not path.is_symlink()
        }

    def symlink(self, link, target, directory=False):
        try:
            link.symlink_to(target, target_is_directory=directory)
        except (OSError, NotImplementedError) as error:
            self.skipTest("Symbolic links are unavailable on this host: {}".format(error))

    def notes(self):
        state = self.project / ".vibe-wise"
        state.mkdir()
        originals = {
            "profile.md": b"Learning mode: paused\nOnboarding: complete\n",
            "progress.md": b"## Pending decision\nAwaiting implementation approval\n",
            "project-map.md": b"# Project Map\nCLI -> service\n",
        }
        for name, data in originals.items():
            (state / name).write_bytes(data)
        return state, originals

    def test_installs_only_allowlisted_files_and_preserves_project_files(self):
        self.notes()
        (self.project / "AGENTS.md").write_text("Existing project instructions\n", encoding="utf-8")
        (self.project / ".gitignore").write_text("Existing ignore rules\n", encoding="utf-8")
        (self.project / "app.py").write_text("Existing source\n", encoding="utf-8")
        originals = self.snapshot()
        result = self.install()
        self.assertEqual(result["status"], "installed")
        self.assertEqual(result["destination"], str(self.destination))
        bundled = self.snapshot(self.destination)
        self.assertEqual(set(bundled), set(installer.BUNDLE_FILES))
        for relative, data in bundled.items():
            self.assertEqual(data, (self.source / relative).read_bytes())
        for relative, data in originals.items():
            self.assertEqual((self.project / relative).read_bytes(), data)

    def test_dry_run_creates_no_files_or_directories(self):
        self.notes()
        originals = self.snapshot()
        entries = {path.relative_to(self.project) for path in self.project.rglob("*")}
        result = self.install(dry_run=True)
        self.assertEqual(result["status"], "dry_run")
        self.assertEqual(self.snapshot(), originals)
        self.assertEqual({path.relative_to(self.project) for path in self.project.rglob("*")}, entries)
        self.assertFalse((self.project / ".agents").exists())

    def test_existing_target_is_never_overwritten(self):
        self.destination.mkdir(parents=True)
        marker = self.destination / "keep.txt"
        marker.write_text("keep", encoding="utf-8")
        for dry_run in (False, True):
            with self.subTest(dry_run=dry_run):
                with self.assertRaisesRegex(ValueError, "already exists"):
                    self.install(dry_run=dry_run)
        self.assertEqual(list(self.destination.iterdir()), [marker])
        self.assertEqual(marker.read_text(encoding="utf-8"), "keep")

    def test_target_created_during_staging_is_not_overwritten(self):
        copy = installer.shutil.copyfile
        marker = self.destination / "concurrent.txt"

        def concurrent_install(source, target):
            if not self.destination.exists():
                self.destination.mkdir(parents=True)
                marker.write_text("another installer", encoding="utf-8")
            return copy(source, target)

        with patch.object(installer.shutil, "copyfile", side_effect=concurrent_install):
            with self.assertRaises(FileExistsError):
                self.install()
        self.assertEqual(list(self.destination.iterdir()), [marker])
        self.assertEqual(marker.read_text(encoding="utf-8"), "another installer")

    def test_dangling_destination_symlink_is_rejected(self):
        self.destination.parent.mkdir(parents=True)
        self.symlink(self.destination, self.root / "missing", directory=True)
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.install()
        self.assertTrue(self.destination.is_symlink())
        self.assertFalse((self.root / "missing").exists())

    def test_linked_parent_cannot_write_outside_project(self):
        outside = self.root / "outside"
        outside.mkdir()
        self.symlink(self.project / ".agents", outside, directory=True)
        with self.assertRaisesRegex(ValueError, "symlinked"):
            self.install()
        self.assertEqual(list(outside.iterdir()), [])

    def test_custom_skills_directory_must_exist_inside_project(self):
        custom = self.project / "other skills"
        custom.mkdir()
        result = self.install(skills_dir=custom)
        self.assertEqual(result["destination"], str(custom / "vibe-wise"))
        self.assertFalse((self.project / ".agents").exists())
        outside = self.root / "outside"
        outside.mkdir()
        with self.assertRaisesRegex(ValueError, "inside"):
            self.install(skills_dir=outside)
        with self.assertRaisesRegex(ValueError, "already exist"):
            self.install(skills_dir=self.project / "missing")
        self.assertEqual(list(outside.iterdir()), [])
        self.assertFalse((self.project / "missing").exists())

    def test_project_must_be_existing_and_absolute(self):
        for project in (Path("relative"), self.root / "missing"):
            with self.subTest(project=project):
                with self.assertRaisesRegex(ValueError, "existing absolute"):
                    installer.install(project, source_root=self.source)
        self.assertFalse((self.root / "missing").exists())

    def test_source_file_and_source_directory_symlinks_are_rejected(self):
        source_file = self.source / "LICENSE"
        outside = self.root / "license"
        source_file.rename(outside)
        self.symlink(source_file, outside)
        with self.assertRaisesRegex(ValueError, "symlinked bundle source"):
            self.install()
        self.assertFalse((self.project / ".agents").exists())
        source_file.unlink()
        outside.rename(source_file)
        directory = self.source / "skills/learn"
        external_directory = self.root / "external learn"
        directory.rename(external_directory)
        self.symlink(directory, external_directory, directory=True)
        with self.assertRaisesRegex(ValueError, "symlinked bundle source"):
            self.install()
        self.assertFalse((self.project / ".agents").exists())

    def test_missing_source_and_failed_staging_do_not_modify_project(self):
        with patch.object(installer.shutil, "copyfile", side_effect=OSError("simulated read failure")):
            with self.assertRaisesRegex(OSError, "simulated read failure"):
                self.install()
        self.assertFalse((self.project / ".agents").exists())
        (self.source / "vibe_wise/state.py").unlink()
        with self.assertRaisesRegex(ValueError, "Required bundle file"):
            self.install()
        self.assertFalse((self.project / ".agents").exists())

    def test_relocated_reset_runs_from_unrelated_cwd_without_plugin_environment(self):
        state, originals = self.notes()
        self.install()
        shutil.rmtree(str(self.source))
        unrelated = self.root / "unrelated directory"
        unrelated.mkdir()
        environment = os.environ.copy()
        environment.pop("CLAUDE_PLUGIN_ROOT", None)
        environment.pop("PYTHONPATH", None)
        helper = self.destination / "skills/reset/reset.py"
        command = [sys.executable, "-B", str(helper), "--cwd", str(self.project)]
        preview_process = subprocess.run(
            command, cwd=str(unrelated), env=environment,
            text=True, capture_output=True, check=True,
        )
        preview = json.loads(preview_process.stdout)
        self.assertEqual(preview["status"], "preview")
        self.assertEqual(preview["state"], str(state))
        self.assertEqual(originals, {name: (state / name).read_bytes() for name in originals})
        confirmed_process = subprocess.run(
            command + ["--confirm", preview["confirmation"]],
            cwd=str(unrelated), env=environment, text=True, capture_output=True, check=True,
        )
        result = json.loads(confirmed_process.stdout)
        self.assertEqual(result["status"], "reset")
        backup = Path(result["backup"])
        self.assertEqual(originals, {name: (backup / name).read_bytes() for name in originals})
        self.assertIn("Onboarding: incomplete", (state / "profile.md").read_text(encoding="utf-8"))
        self.assertFalse((self.destination / "hooks").exists())
        self.assertFalse((self.destination / "vibe_wise/__pycache__").exists())

    def test_cli_dry_run_emits_readable_destination_without_writes(self):
        result = subprocess.run(
            [sys.executable, "-B", str(SCRIPT), "--project", str(self.project), "--dry-run"],
            cwd=str(self.root), text=True, capture_output=True, check=True,
        )
        output = json.loads(result.stdout)
        self.assertEqual(output["status"], "dry_run")
        self.assertEqual(output["destination"], str(self.destination))
        self.assertFalse((self.project / ".agents").exists())


if __name__ == "__main__":
    unittest.main()
