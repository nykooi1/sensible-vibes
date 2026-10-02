<img src=".claude-plugin/icon.svg" alt="VibeWise brain with code brackets" width="96" height="96">

# VibeWise

**You build. AI writes.**

A learning-first workflow for AI coding agents. Your agent **asks for your approach first**, helps you examine tradeoffs, and explains unfamiliar concepts. You shape the design and decide when it's ready to implement. The agent writes the agreed code, then explains what it changed and why.

For anyone who wants to learn as they build—whether you're an aspiring engineer, a junior developer, or an experienced engineer exploring an unfamiliar stack. Practice planning how the pieces fit together, anticipating failures, and checking the result while keeping ownership of the decisions.

The core is plain Markdown in an [Agent Skill](https://agentskills.io/specification), with a self-contained export for agents that discover `.agents/skills/`. The existing Claude Code plugin adds its native commands and session hook. Learning notes use the same project-local format across agents.

## Get started

### Portable skill

Clone this repository, then export the skill to an **existing project**:

```sh
git clone https://github.com/nykooi1/vibe-wise.git
cd vibe-wise
python3 scripts/install.py --project /absolute/path/to/your-project
```

Use `python` instead of `python3` if it runs Python 3 on your system. On Windows,
use an absolute project path such as `C:/projects/my-app`; quote paths with spaces.

The installer writes `.agents/skills/vibe-wise/` in that project. It includes the guides and reset helper, without plugin metadata, hooks, or your learning notes. Add `--dry-run` to preview the files without writing. Installation and the reset helper require [Python 3](https://www.python.org/downloads/); no extra Python packages are needed. To use Learn manually, an agent can read the guides directly without Python.

Explicitly ask your agent to start VibeWise Learn in the project. For Codex, invoke `$vibe-wise` and ask to start Learn. Antigravity supports `/vibe-wise`; Devin Cloud uses `@skills:vibe-wise`, while Devin CLI supports `/vibe-wise`. These discovery paths and commands follow their documentation; they have not all been tested in live agent sessions. Installing the files does not itself start learning.

See [portable setup and compatibility](docs/portable.md) for other skill directories, direct guide use, optional `AGENTS.md` instructions, and limitations.

### Claude Code plugin

You need [Claude Code](https://code.claude.com/docs/en/setup) and Python 3. The plugin uses Python to restore learning context and reset learning notes.

Run these commands **one at a time** in Claude Code. First, add the marketplace:

```text
/plugin marketplace add nykooi1/vibe-wise
```

After it finishes, install the plugin:

```text
/plugin install vibe-wise@vibe-wise
```

**Enable automatic updates:** open `/plugin` → **Marketplaces** → **vibe-wise** →
**Enable auto-update**. This is off by default for third-party marketplaces.

Restart Claude Code in the project you want to work on, then run:

```text
/vibe-wise:learn
```

Setup asks one question at a time. Use the arrow keys and Enter for choices; pick **Use defaults** to skip preference setup. Then ask Claude to build something. Starting fresh or joining an unfamiliar repository both work. For an existing repository, Claude first inspects the code and sketches a small system map.

## What it feels like

You're building a Notion-style notes app: users sign in, create and edit private
notes, and organize them into folders. Here, you're working through how notes and
folders relate—and what should happen when someone deletes a folder.

This condensed Claude Code example is adapted from a real learning session. Later implementation
steps are illustrative; intervening design discussions are omitted.

**You:**

```text
A note can be in several folders. Deleting a folder should delete its notes.
```

**Claude:**

```text
✦ Build checkpoint: Deleting a shared note

"Trip ideas" is in both Travel and Summer. Deleting it removes it from both.

When someone deletes Travel, what should happen to that note in Summer?
```

**You:**

```text
Keep it in Summer. If it has no folders left, keep the note outside any folder.
```

**Claude:**

```text
That separates deleting a folder from deleting a note.

✦ Build checkpoint: Connecting notes and folders

How would you represent which folders a note belongs to, without copying the note?
```

**You:**

```text
A links table with note_id and folder_id. Deleting a folder removes its links,
not the notes.
```

**Claude:**

```text
Each link records one membership. Several links can point to the same note;
a note with no links is unfiled.

notes ← folder links → folders

✦ Design checkpoint: Folder membership

Proposed: store notes once and track folder membership in a links table.
Deleting a folder removes its links and keeps the notes. This supports multiple
folders per note; loading a folder's notes needs a lookup through those links.

Confirming records this design. We still need to work through access rules
and technology choices before writing code.

❯ 1. Confirm and continue
     This approach makes sense to me; move to the next piece.
  2. Discuss
     Ask questions or clarify anything that doesn't make sense before deciding.
```

**You:**

```text
Confirm and continue.
```

*Later, after the remaining choices for this step are worked through...*

**Claude:**

```text
✦ Implementation checkpoint: Folder membership

I'll add the agreed tables and folder-deletion operation, then test that deleting
a folder preserves its notes and their membership in other folders.
This step builds storage behavior; the UI comes later.

❯ 1. Implement this step
     This approach makes sense to me; write the code for this step.
  2. Discuss
     Ask questions or clarify anything that doesn't make sense before deciding.
```

**You:**

```text
Implement this step.
```

*Claude writes the code and runs the tests.*

**Claude:**

```text
✦ Implementation report: Folder membership

- Added the schema migration: each membership references one note and one folder.
- Added folder deletion: removes the folder and its links, preserving note content.
- Added and ran tests for shared notes and notes left without a folder; both passed.
```

You don't need to know the answer already. Your agent can explain unfamiliar concepts, sketch the relevant pieces, and help you tackle a smaller question. You stay involved in forming the plan. Answer in plain English; ask for more help or say “skip” whenever you want.

Describing what you want sets the requirements. Build Checkpoints ask you to work
out how it should function; a feature preference doesn't approve an architecture.

| Checkpoint | What happens |
| --- | --- |
| **Build** | You reason through how to approach the problem with your agent. |
| **Design** | Review the design. **Confirm and continue** records it and continues planning; no code yet. |
| **Implementation** | Review the specific code changes. **Implement this step** authorizes your agent to make them. |

These aren't three mandatory stops. When ready to code, the Implementation
checkpoint also confirms the design, skipping a separate Design checkpoint.
Both confirmations offer **Discuss** to ask questions, clarify anything confusing,
or explore alternatives before deciding.

When your agent proposes additional implementation details, it separates them from your
decisions in a short list or table explaining each addition and why it matters.
You can question or change any item before proceeding.

After implementation, your agent briefly explains what changed, how the key code works,
why it fits your decision, any tests it added or updated and what they cover, and
which checks ran with their results. Ask to dig deeper anywhere it's unclear.

Small diagrams help you trace data, understand relationships, and see how the system fits together.

## Make it yours

Experience changes the support you get, not your ownership of decisions:

| Level | Teaching approach |
| --- | --- |
| Beginner | Explain unfamiliar pieces, use diagrams, ask smaller reasoning questions. |
| Intermediate | Less introductory context; explore interactions and tradeoffs. |
| Advanced | Probe difficult constraints, failure modes, and design assumptions. |

Everyone reasons first. Your agent adapts to what you demonstrate and how familiar you
are with the stack. Checkpoint frequency—Light, Normal, or Frequent—is separate.

- “Use fewer checkpoints.”
- “Focus on backend architecture.”
- “Use multiple-choice questions.”
- “Just implement this one.”
- “Pause learning.” Explicitly ask to resume Learn; in Claude Code, use `/vibe-wise:learn`.

Preferences, learning notes, and a project map live in `.vibe-wise/` in your project. The Claude hook restores active learning in future sessions and after compaction. Other agents can restore the same notes through explicit Learn or the optional bootstrap described in [portable setup](docs/portable.md). Paused learning stays paused until you explicitly resume; a pending checkpoint still needs your answer. Add `.vibe-wise/` to your `.gitignore` to keep your notes out of Git; VibeWise won't change it silently.

No extra account, backend, or telemetry. Saved notes are read into your agent's context, so that agent's normal data settings apply.

To start learning this project from scratch, explicitly ask for VibeWise Reset
(or run `/vibe-wise:reset` in Claude Code). It shows the project and asks
**Cancel / Reset learning**. After confirmation, it backs up your profile, progress,
and project map inside the notes directory's `backups/` folder, then restarts
onboarding. Source code and other projects stay untouched. To change your
experience level or preferences, just tell your agent; no reset is needed.

## Updating

For a portable export, update your source checkout and rerun the installer for the
same project. If the target already exists, the installer refuses to overwrite it;
review and remove only the old exported skill directory before reinstalling.
Project learning notes live separately in `.vibe-wise/` and are not part of the
export. Preview an installation with `--dry-run`.

For automatic Claude Code plugin updates, open `/plugin` → **Marketplaces** → **vibe-wise** →
**Enable auto-update**. Auto-update is off by default for third-party marketplaces.
Claude Code notifies you after an update; restart Claude Code to load the new version.

To update manually, run these in your terminal:

```sh
claude plugin marketplace update vibe-wise
claude plugin update vibe-wise@vibe-wise
```

Then restart Claude Code. Your project learning notes stay intact; no reset is needed.
Run `claude plugin list` to check the installed version.
[More about plugin updates](https://code.claude.com/docs/en/discover-plugins#keep-plugins-updated).

## License

[MIT](LICENSE). You can use, modify, and share this software, including commercially. Keep the license notice with copies. The software comes without a warranty.
