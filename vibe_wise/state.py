"""Locate local learning notes and check activation independently of the host."""

from pathlib import Path
import re


def profile_is_active(path):
    """Check activation without copying learner notes into context output."""
    # A linked profile could point outside the selected project's learning notes.
    if path.is_symlink() or not path.is_file():
        return False
    has_content = False
    try:
        with path.open(encoding="utf-8") as stream:
            # Scan the whole file: a paused marker can appear after a long profile.
            # Reading line by line avoids loading all its contents into memory.
            for line in stream:
                has_content = has_content or bool(line.strip())
                if re.fullmatch(r"Learning mode:\s*paused\s*", line, re.IGNORECASE):
                    return False
    except (OSError, UnicodeError):
        # Missing, unreadable, or invalid text isn't evidence of active learning.
        return False
    # Older profiles may lack an explicit mode. Preserve their restoration behavior.
    return has_content


def state_directory(cwd):
    """Find the nearest notes directory without crossing a Git project boundary."""
    # Starting in a source subdirectory should still find the project's notes.
    for directory in (cwd, *cwd.parents):
        # Prefer the new name at the nearest location; keep legacy notes in place.
        for name in (".vibe-wise", ".sensible-vibes"):
            state = directory / name
            if state.exists() or state.is_symlink():
                # Stop even if this candidate is invalid. Falling back to a parent
                # could silently load a different project's learner profile.
                return state if state.is_dir() and not state.is_symlink() else None
        # A .git file is a worktree boundary too. Never borrow another repo's state.
        if (directory / ".git").exists():
            break
    return None
