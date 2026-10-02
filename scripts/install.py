"""Install a self-contained VibeWise skill into an existing project."""

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


SOURCE_ROOT = Path(__file__).resolve().parents[1]
BUNDLE_FILES = (
    "SKILL.md",
    "LICENSE",
    "skills/learn/SKILL.md",
    "skills/learn/behavior.md",
    "skills/learn/onboarding.md",
    "skills/learn/state-templates.md",
    "skills/reset/SKILL.md",
    "skills/reset/reset.py",
    "vibe_wise/__init__.py",
    "vibe_wise/state.py",
)


def project_directory(value):
    """Require an explicit existing project rather than creating a mistyped path."""
    path = Path(value)
    if not path.is_absolute() or path.is_symlink() or not path.is_dir():
        raise ValueError("Use an existing absolute project directory, not a symlink.")
    return path.resolve()


def check_skills_directory(path, project, require_existing=False):
    """Keep installation inside the project without following linked parents."""
    if not path.is_absolute():
        raise ValueError("The skills directory must be an absolute path inside the project.")
    # Normalize dot segments without resolving symlinks before checking them.
    path = Path(os.path.abspath(str(path)))
    try:
        relative = path.relative_to(project)
    except ValueError:
        raise ValueError("The skills directory must be inside the selected project.")
    candidate = project
    for part in relative.parts:
        candidate = candidate / part
        if candidate.is_symlink():
            raise ValueError("Refusing a symlinked installation directory: " + str(candidate))
        if candidate.exists() and not candidate.is_dir():
            raise ValueError("Installation parent is not a directory: " + str(candidate))
    # Resolved containment also covers platform-specific redirected directories,
    # including Windows junctions that are not reported as ordinary symlinks.
    try:
        path.resolve().relative_to(project)
    except ValueError:
        raise ValueError("The skills directory resolves outside the selected project.")
    if require_existing and not path.is_dir():
        raise ValueError("The custom skills directory must already exist.")
    return path


def bundle_sources(root):
    """Validate the entire allowlist before any installation directories are made."""
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError("The bundle source must be a real directory.")
    sources = []
    for relative in BUNDLE_FILES:
        candidate = root
        for part in Path(relative).parts:
            candidate = candidate / part
            if candidate.is_symlink():
                raise ValueError("Refusing a symlinked bundle source: " + str(candidate))
        if not candidate.is_file():
            raise ValueError("Required bundle file is missing or not a file: " + str(candidate))
        sources.append((relative, candidate))
    return sources


def install(project, skills_dir=None, dry_run=False, source_root=None):
    """Copy only packaged resources; never update an existing skill or user notes."""
    project = project_directory(project)
    parent = check_skills_directory(
        Path(skills_dir) if skills_dir is not None else project / ".agents" / "skills",
        project,
        require_existing=skills_dir is not None,
    )
    destination = parent / "vibe-wise"
    if destination.exists() or destination.is_symlink():
        raise ValueError("Destination already exists; nothing overwritten: " + str(destination))
    sources = bundle_sources(SOURCE_ROOT if source_root is None else source_root)
    result = {
        "status": "dry_run" if dry_run else "installed",
        "project": str(project),
        "destination": str(destination),
        "files": list(BUNDLE_FILES),
    }
    if dry_run:
        return result

    # Complete the copy outside the project first. A failed source read cannot
    # leave an incomplete skill or create project configuration directories.
    with tempfile.TemporaryDirectory(prefix="vibe-wise-install-") as temporary:
        staged = Path(temporary) / "vibe-wise"
        staged.mkdir()
        for relative, source in sources:
            target = staged / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(str(source), str(target))

        check_skills_directory(parent, project)
        parent.mkdir(parents=True, exist_ok=True)
        check_skills_directory(parent, project, require_existing=True)
        # Exclusive creation also rejects a target created after the initial check.
        destination.mkdir()
        try:
            # Publish SKILL.md last, after all of its resources are available.
            for child in staged.iterdir():
                if child.name != "SKILL.md":
                    shutil.move(str(child), str(destination / child.name))
            shutil.move(str(staged / "SKILL.md"), str(destination / "SKILL.md"))
        except (OSError, shutil.Error):
            shutil.rmtree(str(destination))
            raise
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="Existing absolute project directory")
    parser.add_argument(
        "--skills-dir",
        help="Existing absolute skills directory inside the project (default: .agents/skills)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Show the bundle without writing files")
    args = parser.parse_args()
    try:
        result = install(args.project, args.skills_dir, args.dry_run)
    except (OSError, ValueError, shutil.Error) as error:
        parser.exit(1, "VibeWise installation failed: {}\n".format(error))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
