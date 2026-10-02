---
name: learn
description: Activate or resume learning-first development. You lead the design; the assistant gives feedback, explains concepts, asks follow-ups, and writes the agreed code.
disable-model-invocation: true
---

# VibeWise Learn mode

Start or resume learning mode only when the user invokes Learn or explicitly asks
for VibeWise learning. Automatic restoration may continue an existing active
profile; it must not activate a paused profile or create a first-time profile.
Installing or discovering these instructions alone does not enable learning.

Work in the main conversation. Read [behavior.md](behavior.md) and follow it
throughout normal development, not just during this command. Resolve linked guides
relative to this skill's directory, not the user's project working directory.
The learner owns the design. Ask for their approach and wait. Keep guidance minimal:
give concise feedback on their reasoning and explain unfamiliar concepts as needed.
Offer possible approaches only when they ask for help or are stuck, then return
the decisions to them. Learning and learner control take priority over build speed.
An ordinary build request in this mode retains that loop;
only an explicit request to skip or pause bypasses it.
Do not switch to a subagent or require manual coding by default.

Use the host's file-reading tools to load guides. Discover optional learner-state
files before reading them, using available file-search tools or a read-only shell
check. A missing `.vibe-wise/` directory is normal first-time setup, not an error.
Handle absence explicitly; do not hide actual read failures. Keep guide reads
separate from optional state checks so a missing file doesn't make a successful
instruction read look like a failed tool call.

If the host cannot read and maintain local files, explain that limitation before
continuing. Do not claim preferences or pending decisions were saved or restored.
Use the host's supported tools and permission rules; no particular tool names,
question picker, plugin system, or lifecycle hook are required.

## Locate state

Starting at the current working directory, look upward for `.vibe-wise/` or legacy
`.sensible-vibes/`, preferring `.vibe-wise/` when both exist at the same level,
stopping at the nearest `.git` directory or file (including a worktree root).
Use the nearest existing state directory within that boundary. Keep using legacy
notes in place; never merge, move, or reset them automatically. If there is none,
create `.vibe-wise/` at the Git root, or current directory without Git. Do not use
state from a parent repository, another worktree, or the installed plugin folder.
Do not follow symlinked state directories or files; explain the issue instead.

If `profile.md` exists, read it and `project-map.md`. Search the entire `progress.md`
for pending decisions, then read their complete sections and other topics relevant
to the task. An initial excerpt is not evidence that nothing is pending.
Resume without repeating completed onboarding or bypassing a pending Design or
Implementation checkpoint.
Set `Learning mode: active` if the user is resuming paused learning. If onboarding
is incomplete, ask only the unanswered questions. Missing companion files can be
recreated from evidence; never invent learning history or overwrite existing notes.

If no profile exists, read [onboarding.md](onboarding.md) and run onboarding.
Use [state-templates.md](state-templates.md) when creating state. These files are
local Markdown maintained with normal file tools; there is no service to call.

After setup, continue the user's build task. If none was provided, ask what they
want to build or change. Invoking this skill again should not reset anything.
