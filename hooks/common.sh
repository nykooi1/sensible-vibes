# Shared POSIX sh helpers for machines without Python. Sourced, not executed.
# They mirror session_start.py so each fallback behaves like the Python helper.

# Print a working Python 3.8+ command, or nothing. VIBE_WISE_PYTHON picks one
# interpreter; "none" forces the shell fallback (the tests use this).
find_python() {
    case "${VIBE_WISE_PYTHON-}" in
        none) return 1 ;;
        "") candidates="python3 python" ;;
        *) candidates=$VIBE_WISE_PYTHON ;;
    esac
    for candidate in $candidates; do
        # Running it, not just finding it: "python" may be Python 2 or a stub.
        if "$candidate" -c 'import sys; sys.exit(sys.version_info[:2] < (3, 8))' \
            >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# Like Path.resolve() for an existing directory: absolute, symlinks resolved.
resolve_dir() {
    (cd -P -- "$1" 2>/dev/null && pwd -P)
}

parent_dir() {
    case "$1" in
        /) printf '/\n' ;;
        */*) parent=${1%/*}; printf '%s\n' "${parent:-/}" ;;
    esac
}

# Find the nearest notes directory without crossing a Git project boundary.
# Same rules as state_directory() in session_start.py.
state_directory() {
    directory=$1
    while :; do
        for name in .vibe-wise .sensible-vibes; do
            state=${directory%/}/$name
            if [ -e "$state" ] || [ -L "$state" ]; then
                # Stop even if invalid: a parent could hold another project's notes.
                if [ -d "$state" ] && [ ! -L "$state" ]; then
                    printf '%s\n' "$state"
                    return 0
                fi
                return 1
            fi
        done
        [ -e "${directory%/}/.git" ] && return 1
        [ "$directory" = / ] && return 1
        directory=$(parent_dir "$directory")
    done
}

# Print the string value of a top-level key in the JSON object on stdin, followed
# by "x" so callers can keep trailing newlines. Fails if the JSON is invalid or
# truncated, the key is missing, or its value isn't a string (as json.loads would).
json_get() {
    LC_ALL=C awk -v want="$1" '
        function fail() { if (!err) err = 1; return "" }
        function ch() { return substr(s, pos, 1) }
        function ws() { while (pos <= n && index(" \t\r\n", ch())) pos++ }
        function hexnum(h,   i, v, d) {
            v = 0
            for (i = 1; i <= 4; i++) {
                d = index("0123456789abcdef", tolower(substr(h, i, 1)))
                if (!d) return fail()
                v = v * 16 + d - 1
            }
            return v
        }
        function utf8(c) {
            if (c < 128) return sprintf("%c", c)
            if (c < 2048) return sprintf("%c%c", 192 + int(c / 64), 128 + c % 64)
            if (c < 65536) return sprintf("%c%c%c", 224 + int(c / 4096),
                128 + int(c / 64) % 64, 128 + c % 64)
            return sprintf("%c%c%c%c", 240 + int(c / 262144), 128 + int(c / 4096) % 64,
                128 + int(c / 64) % 64, 128 + c % 64)
        }
        function str(   out, c, e, code, low) {
            pos++
            out = ""
            while (!err) {
                if (pos > n) return fail()
                c = ch()
                if (c == "\"") { pos++; return out }
                if (index(controls, c)) return fail()
                if (c != "\\") { out = out c; pos++; continue }
                e = substr(s, pos + 1, 1)
                pos += 2
                if (e == "u") {
                    code = hexnum(substr(s, pos, 4))
                    pos += 4
                    if (code >= 55296 && code < 56320 && substr(s, pos, 2) == "\\u") {
                        low = hexnum(substr(s, pos + 2, 4))
                        if (low >= 56320 && low < 57344) {
                            code = 65536 + (code - 55296) * 1024 + low - 56320
                            pos += 6
                        }
                    }
                    # The shell cannot hold NUL; Python would reject it as a path.
                    if (code == 0) return fail()
                    out = out utf8(code)
                } else if (index("\"\\/", e)) out = out e
                else if (e == "b") out = out "\b"
                else if (e == "f") out = out "\f"
                else if (e == "n") out = out "\n"
                else if (e == "r") out = out "\r"
                else if (e == "t") out = out "\t"
                else return fail()
            }
            return ""
        }
        function value(depth,   c, key, start) {
            if (depth > 500) return fail()
            ws()
            c = ch()
            if (c == "\"") return str()
            if (c == "{" || c == "[") {
                pos++
                ws()
                if (ch() == (c == "{" ? "}" : "]")) { pos++; return "" }
                while (!err) {
                    ws()
                    if (c == "{") {
                        if (ch() != "\"") return fail()
                        key = str()
                        ws()
                        if (ch() != ":") return fail()
                        pos++
                        ws()
                        # Like json.loads, a repeated key keeps its last value.
                        if (depth == 0 && key == want) {
                            found = (ch() == "\"")
                            result = found ? str() : value(depth + 1)
                        } else value(depth + 1)
                    } else value(depth + 1)
                    ws()
                    if (ch() == ",") { pos++; continue }
                    if (ch() == (c == "{" ? "}" : "]")) { pos++; return "" }
                    return fail()
                }
                return ""
            }
            start = pos
            while (pos <= n && index("+-.0123456789Eaeflnrstu", ch())) pos++
            if (pos == start) return fail()
            return ""
        }
        BEGIN {
            for (i = 1; i < 32; i++) controls = controls sprintf("%c", i)
            while ((getline line) > 0) s = s line "\n"
            n = length(s)
            pos = 1
            ws()
            if (ch() != "{") exit 1
            value(0)
            ws()
            if (err || pos <= n || !found) exit 1
            printf "%sx", result
        }
    '
}

# Print stdin as a JSON string literal, escaped like Python's json.dumps
# except that non-ASCII text stays as UTF-8, which JSON permits.
json_string() {
    LC_ALL=C awk '
        BEGIN { for (i = 1; i < 32; i++) ctrl[sprintf("%c", i)] = sprintf("\\u%04x", i)
                ctrl["\b"] = "\\b"; ctrl["\f"] = "\\f"; ctrl["\r"] = "\\r"; ctrl["\t"] = "\\t" }
        { line = $0; out = ""
          for (i = 1; i <= length(line); i++) {
              c = substr(line, i, 1)
              if (c == "\\") c = "\\\\"; else if (c == "\"") c = "\\\""
              else if (c in ctrl) c = ctrl[c]
              out = out c
          }
          text = (NR > 1) ? text "\\n" out : out }
        END { printf "\"%s\"", text }
    '
}
