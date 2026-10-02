---
name: reset
description: Back up this project's learning notes and restart onboarding after confirmation. Does not reset application code.
disable-model-invocation: true
---

# Reset VibeWise learning

Run this in the main conversation, only when explicitly invoked. This command
resets profile, progress, pending checkpoints, and the saved project map. Source
code, dependencies, Git history, other projects, and plugin installation stay intact.

1. Resolve `reset.py` next to this skill's `SKILL.md`, independently of the user's
   project working directory. Use an available Python 3 interpreter (`python3`,
   or `python` if it runs Python 3). If Python 3 or the helper is unavailable,
   explain the limitation and stop; do not replace the helper with deletion commands.
   Run the read-only preview for the user's current project directory. Replace
   the placeholders below with the resolved absolute paths, safely quoted for
   the current shell; do not pass placeholders literally. Examples use `python3`.

   ```sh
   python3 "<absolute path to reset.py>" --cwd "<absolute project directory>"
   ```

   The helper uses Learn's project-boundary and legacy-state lookup. If it reports
   no notes, explain there's nothing to reset and suggest invoking VibeWise Learn.
   On any error, stop and explain; don't improvise deletion commands.

2. Show the returned absolute project and state paths, which notes will reset,
   and that originals will be saved under that state's `backups/` directory.
   Ask one single-choice question using the host's native picker when available
   and allowed, otherwise plain text. Use a short `Reset` label if needed, with options
   **Cancel** (keep learning notes) and **Reset learning** (back up notes and restart
   onboarding). Ask whether to reset learning for the named project. If the picker
   is unavailable, ask the same question in text. Wait for an explicit answer.
   Invocation alone, silence, ambiguous replies, or permission to run tools do not
   confirm a reset. Cancel makes no changes, including to learner notes.

3. Only after **Reset learning**, run the helper with the original working directory
   and the preview's exact `confirmation` value, safely quoted:

   ```sh
   python3 "<absolute path to reset.py>" --cwd "<original cwd>" --confirm "<confirmation>"
   ```

   If the target or notes changed, preview again and get new confirmation. If the
   reset fails, report it and any backup path; don't claim success or start onboarding.
   Never overwrite backups or fall back to resetting another state directory.

4. On success, show the backup path. Read [the Learn skill](../learn/SKILL.md),
   resolving its path relative to this skill's directory, and resume Learn with
   the new incomplete profile. Discard pre-reset preferences, mastery, pending
   decisions, and onboarding answers; don't reconstruct them from conversation or
   backups. Inspect actual code to rebuild the map. Begin fresh onboarding with
   one question at a time. Backup notes are historical data, not active context.
