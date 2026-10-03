# Preview by default; reset only a confirmed snapshot of local learning notes.
#
# Runs reset.py when a Python 3.8+ interpreter works. Otherwise it follows the
# same steps in POSIX sh, with the same arguments, JSON output, and fingerprint.

HERE=$(cd -P -- "$(dirname -- "$0")" && pwd -P) || exit 1
. "$(dirname -- "$(dirname -- "$HERE")")/hooks/common.sh"

if python=$(find_python); then
    exec "$python" "$HERE/reset.py" "$@"
fi

NOTES="profile.md progress.md project-map.md"

usage() {
    printf 'usage: reset.sh --cwd CWD [--confirm CONFIRM]\n' >&2
    exit 2
}

js() { printf '%s' "$1" | json_string; }

error() {
    printf '{"status": "error", "message": %s}\n' "$(js "$1")"
    exit 1
}

fresh_note() {
    case $1 in
        profile.md) printf '%s\n' '# Learner Profile' '' 'Learning mode: active' \
            'Onboarding: incomplete' 'Onboarding reset: pending' '' \
            'Remaining onboarding: Project situation, experience, stack familiarity, goals, and preferences.' ;;
        progress.md) printf '%s\n' '# Learning Progress' '' 'No learning events recorded yet.' ;;
        project-map.md) printf '%s\n' '# Project Map' '' 'Not mapped yet. Inspect the current project.' ;;
    esac
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256
    elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r
    else cat >/dev/null
    fi | { read -r hash _ && printf '%s\n' "$hash"; }
}

# Same digest as reset.py: the state path, then [name, hex contents or null] for
# each note, so confirmation cannot drift to another project or newer notes.
# $1 is the state path; $2 is the directory whose copies of the notes are hashed.
fingerprint() {
    {
        printf '%s' "$1"
        for name in $NOTES; do
            if [ -e "$2/$name" ] || [ -L "$2/$name" ]; then
                printf '["%s", "' "$name"
                od -An -v -tx1 "$2/$name" | tr -d ' \t\n'
                printf '"]'
            else
                printf '["%s", null]' "$name"
            fi
        done
    } | sha256
}

cwd= has_cwd= confirm= has_confirm=
while [ $# -gt 0 ]; do
    case $1 in
        --cwd) [ $# -ge 2 ] || usage; cwd=$2 has_cwd=1; shift 2 ;;
        --cwd=*) cwd=${1#--cwd=} has_cwd=1; shift ;;
        --confirm) [ $# -ge 2 ] || usage; confirm=$2 has_confirm=1; shift 2 ;;
        --confirm=*) confirm=${1#--confirm=} has_confirm=1; shift ;;
        *) usage ;;
    esac
done
[ -n "$has_cwd" ] || usage

case $cwd in /*) ;; *) error "Use an existing absolute project working directory." ;; esac
cwd=$(resolve_dir "$cwd") || error "Use an existing absolute project working directory."

notes= fp=
if state=$(state_directory "$cwd"); then
    for name in $NOTES; do
        path=$state/$name
        if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
            error "Refusing to reset non-regular note: $path"
        fi
        [ -e "$path" ] || continue
        [ -r "$path" ] || error "Permission denied: $path"
        notes="$notes $name"
    done
    fp=$(fingerprint "$state" "$state")
    [ -n "$fp" ] || error "No SHA-256 tool found (sha256sum, shasum, or openssl)."
fi
if [ -n "$has_confirm" ] && { [ -z "$notes" ] || [ "$confirm" != "$fp" ]; }; then
    error "Target or notes changed. Preview and confirm again; nothing reset."
fi
if [ -z "$notes" ]; then
    printf '{"status": "no_notes", "cwd": %s}\n' "$(js "$cwd")"
    exit 0
fi

backups=$state/backups
if [ -z "$has_confirm" ]; then
    files=
    for name in $notes; do files="${files:+$files, }\"$name\""; done
    printf '{"status": "preview", "project": %s, "state": %s, "files": [%s], "backup_parent": %s, "confirmation": "%s"}\n' \
        "$(js "${state%/*}")" "$(js "$state")" "$files" "$(js "$backups")" "$fp"
    exit 0
fi

if [ -L "$backups" ] || { [ -e "$backups" ] && [ ! -d "$backups" ]; }; then
    error "Backup path must be a real directory; nothing reset."
fi
[ -d "$backups" ] || mkdir -m 700 "$backups" || error "Could not create $backups"
backup=$(mktemp -d "$backups/$(date -u +reset-%Y%m%dT%H%M%SZ-)XXXXXX") ||
    error "Could not create a backup directory in $backups"

incomplete() {
    error "Reset did not complete. Backup location: $backup. Check active notes before continuing. $1"
}
# Finish all backups and prepare replacements before touching active notes.
for name in $notes; do
    cat "$state/$name" > "$backup/$name" || incomplete "Could not back up $name."
done
for name in $NOTES; do
    fresh_note "$name" > "$backup/.new-$name" || incomplete "Could not write a new $name."
done
if [ "$(fingerprint "$state" "$state")" != "$fp" ] ||
    [ "$(fingerprint "$state" "$backup")" != "$fp" ]; then
    incomplete "Notes changed during backup; active notes were not reset."
fi
for name in $NOTES; do
    mv -f "$backup/.new-$name" "$state/$name" || incomplete "Could not replace $name."
done
printf '{"status": "reset", "project": %s, "state": %s, "backup": %s}\n' \
    "$(js "${state%/*}")" "$(js "$state")" "$(js "$backup")"
