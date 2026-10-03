# Shared Windows PowerShell 5.1 helpers for machines without Python. Dot-sourced.
# They mirror session_start.py so each fallback behaves like the Python helper.

# Return a working Python 3.8+ command as an array (e.g. py -3), or $null.
# VIBE_WISE_PYTHON picks one interpreter; "none" forces the PowerShell fallback.
function Find-Python {
    if ($env:VIBE_WISE_PYTHON -eq 'none') { return $null }
    if ($env:VIBE_WISE_PYTHON) { $candidates = @(, @($env:VIBE_WISE_PYTHON)) }
    else { $candidates = @(@('python3'), @('python'), @('py', '-3')) }
    foreach ($candidate in $candidates) {
        if (-not (Get-Command $candidate[0] -CommandType Application -ErrorAction SilentlyContinue)) {
            continue
        }
        # Running it, not just finding it: the Microsoft Store alias is only a stub.
        $rest = @($candidate | Select-Object -Skip 1)
        try {
            & $candidate[0] @rest -c 'import sys; sys.exit(sys.version_info[:2] < (3, 8))' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return , $candidate }
        } catch { }
    }
    return $null
}

# Like Python's Path.is_absolute() on Windows: a drive letter and root, or UNC.
function Test-AbsolutePath([string]$Path) {
    return $Path -match '^([A-Za-z]:[\\/]|[\\/]{2}[^\\/])'
}

# Attributes of the entry itself without following links, or $null if missing.
function Get-EntryAttributes([string]$Path) {
    try { return [IO.File]::GetAttributes($Path) } catch { return $null }
}

# A symlink or junction: never read through one, as in session_start.py.
function Test-Link($Attributes) {
    return [bool]($Attributes -band [IO.FileAttributes]::ReparsePoint)
}

# Find the nearest notes directory without crossing a Git project boundary.
# Same rules as state_directory() in session_start.py.
function Get-StateDirectory([string]$Cwd) {
    $directory = $Cwd
    while ($directory) {
        foreach ($name in '.vibe-wise', '.sensible-vibes') {
            $state = Join-Path $directory $name
            $attributes = Get-EntryAttributes $state
            if ($null -ne $attributes) {
                # Stop even if invalid: a parent could hold another project's notes.
                if (($attributes -band [IO.FileAttributes]::Directory) -and -not (Test-Link $attributes)) {
                    return $state
                }
                return $null
            }
        }
        if (Test-Path -LiteralPath (Join-Path $directory '.git')) { return $null }
        $directory = [IO.Path]::GetDirectoryName($directory)
    }
    return $null
}

# A JSON string literal escaped exactly like Python's json.dumps.
function ConvertTo-JsonString([string]$Text) {
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    foreach ($c in $Text.ToCharArray()) {
        switch ([int]$c) {
            0x22 { [void]$builder.Append('\"'); continue }
            0x5C { [void]$builder.Append('\\'); continue }
            0x08 { [void]$builder.Append('\b'); continue }
            0x0C { [void]$builder.Append('\f'); continue }
            0x0A { [void]$builder.Append('\n'); continue }
            0x0D { [void]$builder.Append('\r'); continue }
            0x09 { [void]$builder.Append('\t'); continue }
            default {
                if ([int]$c -lt 0x20 -or [int]$c -gt 0x7E) {
                    [void]$builder.Append(('\u{0:x4}' -f [int]$c))
                } else { [void]$builder.Append($c) }
            }
        }
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

# Write one line of protocol output: ASCII JSON, like the Python helpers' print().
function Write-Line([string]$Line) {
    [Console]::Out.Write($Line + [Environment]::NewLine)
    [Console]::Out.Flush()
}
