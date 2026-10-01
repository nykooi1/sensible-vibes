"""Check that the Codex hook restores the Codex guide without changing notes."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[1] / "codex/hooks/session_start.py"


class CodexSessionStartTests(unittest.TestCase):
    def test_active_project_loads_codex_skill(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / ".git").mkdir()
            notes = project / ".vibe-wise"
            notes.mkdir()
            profile = notes / "profile.md"
            profile.write_text("Learning mode: active\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(HOOK)],
                input=json.dumps({"hook_event_name": "SessionStart", "cwd": str(project)}),
                text=True,
                capture_output=True,
                check=True,
            )
            context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
            self.assertIn("codex/skills/learn/SKILL.md", context)
            self.assertEqual(profile.read_text(encoding="utf-8"), "Learning mode: active\n")


if __name__ == "__main__":
    unittest.main()
