"""Structural checks for the portable Codex plugin package."""

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodexPluginTests(unittest.TestCase):
    def test_portable_manifest_declares_the_existing_hook(self):
        manifest = json.loads((ROOT / "plugin.json").read_text(encoding="utf-8"))
        claude_manifest = json.loads(
            (ROOT / ".claude-plugin/plugin.json").read_text(encoding="utf-8")
        )

        self.assertEqual(manifest["name"], "vibe-wise")
        self.assertEqual(manifest["version"], claude_manifest["version"])
        self.assertTrue((ROOT / "skills").is_dir())
        hook = manifest["extensions"]["com.openai"]["hooks"]
        self.assertTrue(hook.startswith("./"))
        self.assertTrue((ROOT / hook[2:]).is_file())

    def test_repo_marketplace_exposes_the_plugin_root(self):
        marketplace = json.loads(
            (ROOT / ".agents/plugins/marketplace.json").read_text(encoding="utf-8")
        )

        self.assertEqual(marketplace["name"], "vibe-wise")
        plugin = marketplace["plugins"][0]
        self.assertEqual(plugin["name"], "vibe-wise")
        self.assertEqual(plugin["source"], {"source": "local", "path": "./"})
        self.assertEqual(plugin["policy"]["installation"], "AVAILABLE")
        self.assertEqual(plugin["policy"]["authentication"], "ON_INSTALL")
        self.assertEqual(plugin["category"], "Productivity")


if __name__ == "__main__":
    unittest.main()
