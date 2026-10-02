# Portable VibeWise

VibeWise's learning workflow is shared Markdown. The root `SKILL.md` routes an
explicit Learn or Reset request to the canonical guides under `skills/`. The
Claude Code plugin remains available with its own commands and session hook.
Other agents can use the same guides and project learning notes.

## Install in a project

From a checkout of this repository, run:

```sh
python3 scripts/install.py --project /absolute/path/to/your-project --dry-run
python3 scripts/install.py --project /absolute/path/to/your-project
```

The project must already exist and the path must be absolute. Use `python` instead
of `python3` if that command runs Python 3 on your system, as is common on Windows;
use a Windows absolute path such as `C:/projects/my-app` there. Quote paths that
contain spaces. The preview reads files and reports what would be installed without
creating directories or writing files. The installation exports a self-contained skill to
`/absolute/path/to/your-project/.agents/skills/vibe-wise/`.

The exported bundle includes:

- `SKILL.md` and `LICENSE`.
- The Learn and Reset guides and their referenced Markdown files.
- `skills/reset/reset.py` and the shared `vibe_wise/state.py` helper.

It does not include Claude plugin metadata, hooks, or `.vibe-wise/` learning notes.
The agent follows references relative to the installed skill; it does not need the
original checkout after installation. Python 3 is needed for the installer and
confirmed Reset helper. No additional Python packages are required. Learn's
Markdown instructions can be followed with normal file tools without an
interpreter.

If the agent discovers skills in another project directory, pass an existing,
absolute skills-parent directory within that project:

```sh
python3 scripts/install.py --project /absolute/path/to/your-project \
  --skills-dir /absolute/path/to/your-project/.devin/skills --dry-run
```

Create that skills-parent directory first, review the preview, then repeat without
`--dry-run`. The installer appends `vibe-wise/` to it. It does not change global
agent configuration or install outside the named project.

An existing target is an error, including when reinstalling. There is no force
flag or automatic update. To update, inspect and back up any changes you made to
the installed bundle, remove only that exported `vibe-wise/` skill directory, and
run the installer from the updated source checkout. Your project's learning notes
remain in their separate `.vibe-wise/` directory.

## Start, resume, pause, and reset

Installation makes the guides available; it does not start onboarding or activate
learning. Explicitly ask to start VibeWise Learn and name the project you want to
work on. For example:

```text
Use VibeWise Learn in this project. Help me plan a small notes application.
```

On an agent with native skill invocation, use the command shown below and specify
Learn in the request. On a host without skill discovery, point it to the original
or exported `SKILL.md` directly:

```text
Read /absolute/path/to/vibe-wise/SKILL.md and start VibeWise Learn for
/absolute/path/to/my-project. Follow its referenced guides with your file tools.
```

An agent needs to read local Markdown, inspect your project, ask questions, edit
files for approved work, and run relevant checks. These guides do not turn a
chat-only model into a coding agent with those capabilities.

Say “Pause learning” to pause. Say “Resume VibeWise Learn” to resume deliberately.
Existing state is read before continuing. Completed onboarding should not repeat;
unanswered questions and pending Design or Implementation checkpoints stay
pending until you answer. An ordinary build request must not silently reactivate
a paused profile.

For Reset, explicitly say “Reset VibeWise learning for this project.” The Reset
guide first runs a read-only preview with the bundled Python helper and shows the
absolute project and learning-note paths. It waits for **Cancel / Reset learning**.
Only an explicit **Reset learning** answer authorizes backup and reset. If the
notes change before confirmation is applied, it previews again and asks again.
After a successful reset it starts fresh onboarding. It does not reset your
application or Git history.

## Agent compatibility

These entries describe documented file discovery and invocation. They do not
represent successful live sessions in every product or identical behavior across
models. Automated checks verify VibeWise's files, helpers, and installation;
conversation behavior needs a smoke test in the agent you use.

| Agent | Project integration | Explicit invocation |
| --- | --- | --- |
| Codex | `.agents/skills/vibe-wise/SKILL.md`; optional `AGENTS.md` | `$vibe-wise`, with a request to start or resume Learn, or to Reset |
| Antigravity IDE, 2.0, and CLI | `.agents/skills/vibe-wise/SKILL.md`; optional `AGENTS.md` | `/vibe-wise`, with the requested action |
| Devin Cloud | `.agents/skills/vibe-wise/SKILL.md`; optional `AGENTS.md` | `@skills:vibe-wise`, with the requested action |
| Devin CLI | `.agents/skills/vibe-wise/SKILL.md`; optional `AGENTS.md` | `/vibe-wise`, with the requested action |
| Claude Code plugin | Install through the existing marketplace instructions | `/vibe-wise:learn` or `/vibe-wise:reset` |
| Other coding agents | Configure discovery for the exported skill or explicitly read its `SKILL.md` | Ask for VibeWise Learn or Reset in ordinary text |

The [Agent Skills specification](https://agentskills.io/specification) defines the
bundle and standard metadata. Installation paths, invocation syntax, permission
settings, hooks, and available tools are agent-specific. The portable entry uses
standard `name` and `description` metadata and avoids depending on a vendor's tool
names, permission extensions, or model selection.

For example, Devin Cloud currently permits only one active skill at a time.
VibeWise Learn and Reset are routes within the same portable skill, and ordinary
Markdown references can be read without activating a second skill. Antigravity's
new integrations should use skills: its legacy workflows are scheduled to retire
on 1 November 2026.

Official references:

- [Codex skills](https://developers.openai.com/codex/skills).
- [AGENTS.md format](https://agents.md/).
- [Antigravity skills](https://antigravity.google/docs/skills) and
  [rules](https://antigravity.google/docs/rules).
- [Antigravity workflow migration](https://antigravity.google/docs/migration/workflows-to-skills).
- [Devin Cloud skills](https://docs.devin.ai/product-guides/skills) and
  [AGENTS.md](https://docs.devin.ai/onboard-devin/agents-md).
- [Devin CLI skills](https://docs.devin.ai/cli/extensibility/skills/overview) and
  [rules](https://docs.devin.ai/cli/extensibility/rules).

## Optional AGENTS.md bootstrap

If you want an agent that reads `AGENTS.md` to discover VibeWise and restore active
learning on later tasks, merge a short instruction into your project's existing
`AGENTS.md`. Review it with your project conventions first; installation does not
create or replace this file. [AGENTS.md](https://agents.md/) is ordinary Markdown,
and support and automatic inclusion limits differ by agent.

```markdown
## VibeWise

VibeWise is available at `.agents/skills/vibe-wise/SKILL.md`.
For an explicit request to start or resume VibeWise Learn, or to Reset learning,
read that entry and follow its referenced guides. Merely having the skill installed
does not authorize onboarding, note creation, or Reset.

Before restoring saved learning on a later task, follow the Learn guide's state
lookup: start from the current working directory, stay inside the nearest Git
repository or worktree, prefer `.vibe-wise/` over `.sensible-vibes/` at the same
level, and reject symlinked notes. A missing profile is normal: continue the task
without onboarding unless the user explicitly requests Learn. Read an existing
profile before deciding whether to restore. If its learning mode is paused, leave
it paused unless the user explicitly requests resume. If active, restore the Learn
behavior and relevant notes without repeating completed onboarding. Read complete
pending checkpoint sections and wait for the learner's answer before proceeding.
```

Adjust the installed entry path if you used another skills-parent directory.
This bootstrap supplies instructions; it is not a lifecycle hook or a guarantee
that the host follows every instruction.

## State and native hooks

All integrations use the same `.vibe-wise/` Markdown state: `profile.md`,
`progress.md`, and `project-map.md`. State lookup stays within the current Git
repository or worktree and preserves legacy `.sensible-vibes/` notes in place.
Profiles record active or paused learning; progress can preserve pending
checkpoints. The shared Python lookup helper and guides apply the same boundaries
and reject symlinked notes.

Add `.vibe-wise/` to your project's `.gitignore` if you want private learning notes
to stay out of commits. VibeWise does not silently change that file. Notes enter
the agent's context when it reads them, so your agent's usual data settings apply.

Claude Code's native SessionStart hook restores context when an existing active
profile is found. The portable export installs no hooks. Other agents can restore
through explicit Learn or the optional bootstrap; host-specific hooks can be added
as separate integrations. Their events, payloads, and context injection contracts
are not interchangeable. Portable instructions and shared state do not guarantee
identical restoration after restart or compaction on every host.
