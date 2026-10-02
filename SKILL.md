---
name: vibe-wise
description: Start, resume, or reset VibeWise learning only when explicitly requested by the user. Guide software design and implementation using the shared Learn and Reset workflows.
---

# VibeWise

Use this entry point in the main conversation. Installing, discovering, or reading
these instructions does not activate learning. An ordinary coding request does not
start VibeWise; the user must explicitly ask to start or resume learning.

Resolve all linked guides relative to this file's directory, independently of the
project working directory. Keep the bundle together so its guides and helpers can
be found without host-specific environment variables.

## Learn

When the user explicitly asks to start or resume VibeWise learning, read
[the Learn skill](skills/learn/SKILL.md) and its referenced behavior guide. Follow
its state lookup, onboarding, and learning loop throughout development until the
user pauses or explicitly skips learning for a step.

A host may restore an existing active profile at session start or after context
compaction. In that case, follow the Learn guide to restore the saved stage and
continue incomplete onboarding. Automatic restoration must not create a first-time
profile, reactivate paused learning, or bypass a pending Design or Implementation
checkpoint. A restart, agent switch, or context compaction is not implementation
approval.

## Reset

Only when the user explicitly requests resetting VibeWise learning, read
[the Reset skill](skills/reset/SKILL.md) and follow its preview, confirmation, and
backup procedure. Asking to reset selects the workflow; it does not confirm the
reset. Do not replace the helper with manual deletion or reset application code.

If the requested action is unclear, ask which workflow the user wants and wait.

## Host capabilities

Use the host's supported file-reading, file-search, and editing tools, plus an
available Python 3 interpreter for the reset helper. Native question pickers,
plugin commands, and lifecycle hooks are optional. Follow the host's tool limits
and permission rules; ask in plain text when a suitable picker is unavailable.

The selected project's learning notes belong in its `.vibe-wise/` directory or
existing legacy `.sensible-vibes/`, as the Learn guide specifies. Keep notes out of
the installed bundle and preserve the same state when switching assistants.
