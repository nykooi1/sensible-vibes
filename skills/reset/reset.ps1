# Preview by default; reset only a confirmed snapshot of local learning notes.
#
# Runs reset.py when a Python 3.8+ interpreter works. Otherwise it follows the
# same steps in Windows PowerShell 5.1, with the same arguments (--cwd,
# --confirm), JSON output, and fingerprint.

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\hooks\common.ps1')

$python = Find-Python
if ($python) {
    # Python's own stderr (e.g. usage errors) is not a PowerShell failure.
    $ErrorActionPreference = 'Continue'
    $rest = @($python | Select-Object -Skip 1)
    & $python[0] @rest (Join-Path $PSScriptRoot 'reset.py') @args
    exit $LASTEXITCODE
}

$Notes = 'profile.md', 'progress.md', 'project-map.md'
$Fresh = @{
    'profile.md' = "# Learner Profile`n`nLearning mode: active`nOnboarding: incomplete`n" +
        "Onboarding reset: pending`n`n" +
        "Remaining onboarding: Project situation, experience, stack familiarity, " +
        "goals, and preferences.`n"
    'progress.md' = "# Learning Progress`n`nNo learning events recorded yet.`n"
    'project-map.md' = "# Project Map`n`nNot mapped yet. Inspect the current project.`n"
}

function Write-Usage {
    [Console]::Error.WriteLine('usage: reset.ps1 --cwd CWD [--confirm CONFIRM]')
    exit 2
}

# Same digest as reset.py: the state path, then [name, hex contents or null] for
# each note, so confirmation cannot drift to another project or newer notes.
function Get-Fingerprint([string]$State, [hashtable]$Contents) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $parts = New-Object Collections.Generic.List[byte[]]
        $parts.Add([Text.Encoding]::UTF8.GetBytes($State))
        foreach ($name in $Notes) {
            if ($Contents.ContainsKey($name)) {
                $hex = [BitConverter]::ToString($Contents[$name]).Replace('-', '').ToLowerInvariant()
                $parts.Add([Text.Encoding]::ASCII.GetBytes("[`"$name`", `"$hex`"]"))
            } else {
                $parts.Add([Text.Encoding]::ASCII.GetBytes("[`"$name`", null]"))
            }
        }
        foreach ($part in $parts) { [void]$sha.TransformBlock($part, 0, $part.Length, $null, 0) }
        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
        return [BitConverter]::ToString($sha.Hash).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

# The state directory, its notes' bytes, and their fingerprint, like snapshot().
function Get-Snapshot([string]$Cwd) {
    $state = Get-StateDirectory $Cwd
    $contents = @{}
    if ($null -eq $state) { return @{ State = $null; Contents = $contents; Fingerprint = $null } }
    foreach ($name in $Notes) {
        $path = Join-Path $state $name
        $attributes = Get-EntryAttributes $path
        if ($null -eq $attributes) { continue }
        if ((Test-Link $attributes) -or ($attributes -band [IO.FileAttributes]::Directory)) {
            throw ("Refusing to reset non-regular note: $path")
        }
        $contents[$name] = [IO.File]::ReadAllBytes($path)
    }
    return @{ State = $state; Contents = $contents; Fingerprint = (Get-Fingerprint $state $contents) }
}

function ConvertTo-JsonObject([Collections.Specialized.OrderedDictionary]$Values) {
    $fields = foreach ($key in $Values.Keys) {
        $value = $Values[$key]
        if ($value -is [array]) {
            $items = @($value | ForEach-Object { ConvertTo-JsonString $_ }) -join ', '
            $value = "[$items]"
        } else { $value = ConvertTo-JsonString $value }
        "$(ConvertTo-JsonString $key): $value"
    }
    return '{' + ($fields -join ', ') + '}'
}

function Invoke-Reset([string]$Cwd, $Confirmation) {
    if (-not (Test-AbsolutePath $Cwd) -or -not (Test-Path -LiteralPath $Cwd -PathType Container)) {
        throw ('Use an existing absolute project working directory.')
    }
    $Cwd = [IO.Path]::GetFullPath($Cwd)
    $snapshot = Get-Snapshot $Cwd
    $state = $snapshot.State
    $contents = $snapshot.Contents
    $fingerprint = $snapshot.Fingerprint
    if ($null -ne $Confirmation -and ($contents.Count -eq 0 -or $Confirmation -cne $fingerprint)) {
        throw ('Target or notes changed. Preview and confirm again; nothing reset.')
    }
    if ($contents.Count -eq 0) {
        return [ordered]@{ status = 'no_notes'; cwd = $Cwd }
    }
    $project = [IO.Path]::GetDirectoryName($state)
    $backupParent = Join-Path $state 'backups'
    if ($null -eq $Confirmation) {
        return [ordered]@{
            status = 'preview'; project = $project; state = $state
            files = @($Notes | Where-Object { $contents.ContainsKey($_) })
            backup_parent = $backupParent; confirmation = $fingerprint
        }
    }

    $attributes = Get-EntryAttributes $backupParent
    if ($null -ne $attributes -and ((Test-Link $attributes) -or
            -not ($attributes -band [IO.FileAttributes]::Directory))) {
        throw ('Backup path must be a real directory; nothing reset.')
    }
    [void][IO.Directory]::CreateDirectory($backupParent)
    $prefix = [DateTime]::UtcNow.ToString("'reset-'yyyyMMdd'T'HHmmss'Z-'")
    $random = New-Object Random
    do {
        $suffix = -join (1..8 | ForEach-Object { 'abcdefghijklmnopqrstuvwxyz0123456789_'[$random.Next(37)] })
        $backup = Join-Path $backupParent ($prefix + $suffix)
    } while ($null -ne (Get-EntryAttributes $backup))
    [void][IO.Directory]::CreateDirectory($backup)
    try {
        # Finish all backups and prepare replacements before touching active notes.
        foreach ($name in $Notes) {
            if ($contents.ContainsKey($name)) {
                [IO.File]::WriteAllBytes((Join-Path $backup $name), $contents[$name])
            }
        }
        $utf8 = New-Object Text.UTF8Encoding($false)
        foreach ($name in $Notes) {
            # Python's write_text uses the platform's line endings; match it.
            $text = $Fresh[$name].Replace("`n", [Environment]::NewLine)
            [IO.File]::WriteAllText((Join-Path $backup ".new-$name"), $text, $utf8)
        }
        if ((Get-Snapshot $Cwd).Fingerprint -cne $fingerprint) {
            throw ('Notes changed during backup; active notes were not reset.')
        }
        foreach ($name in $Notes) {
            $source = Join-Path $backup ".new-$name"
            $target = Join-Path $state $name
            if ($null -ne (Get-EntryAttributes $target)) { [IO.File]::Replace($source, $target, [NullString]::Value) }
            else { [IO.File]::Move($source, $target) }
        }
    } catch {
        throw (("Reset did not complete. Backup location: $backup. " +
            "Check active notes before continuing. $($_.Exception.Message)"))
    }
    return [ordered]@{ status = 'reset'; project = $project; state = $state; backup = $backup }
}

$cwd = $null
$confirm = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -ceq '--cwd' -or $arg -ceq '--confirm') {
        if ($i + 1 -ge $args.Count) { Write-Usage }
        $i++
        if ($arg -ceq '--cwd') { $cwd = [string]$args[$i] } else { $confirm = [string]$args[$i] }
    } elseif ($arg.StartsWith('--cwd=')) { $cwd = $arg.Substring(6) }
    elseif ($arg.StartsWith('--confirm=')) { $confirm = $arg.Substring(10) }
    else { Write-Usage }
}
if ($null -eq $cwd) { Write-Usage }

try {
    $result = Invoke-Reset $cwd $confirm
} catch {
    Write-Line (ConvertTo-JsonObject ([ordered]@{ status = 'error'; message = $_.Exception.Message }))
    exit 1
}
Write-Line (ConvertTo-JsonObject $result)
exit 0
