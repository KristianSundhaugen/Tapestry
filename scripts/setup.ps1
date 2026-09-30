# Tapestry setup for Windows Terminal / PowerShell.
#
#   A. This repo IS your project:            .\scripts\setup.ps1
#   B. Add Tapestry to an existing repo:     .\scripts\setup.ps1 -Into C:\path\to\your\repo
#
# Both: set git core.hooksPath (pre-push honours your optional push window), check the
# environment, and print the next steps. Then run `claude` and type /tapestry-setup.
#
# If PowerShell refuses to run scripts, allow local scripts once for your user:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# or run this one file without changing policy:
#   powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
#
# Works on Windows PowerShell 5.1 and PowerShell 7+. Keep this file ASCII-only.

[CmdletBinding()]
param(
    [string]$Into = '',
    [switch]$KeepExamples
)

# Native commands (git) are checked via $LASTEXITCODE; only cmdlets stop on error.
$ErrorActionPreference = 'Continue'
$src = Split-Path -Parent $PSScriptRoot
$target = $src

function Join-Many([string[]]$parts) {
    $p = $parts[0]
    for ($i = 1; $i -lt $parts.Count; $i++) { $p = Join-Path $p $parts[$i] }
    return $p
}

# CLAUDE.md up to the Project notes marker; the notes belong to the source project.
function Get-TapestryClaudeMd([string]$from) {
    $keep = @()
    foreach ($line in (Get-Content -LiteralPath (Join-Path $from 'CLAUDE.md'))) {
        $keep += $line
        if ($line -like '<!-- /tapestry-setup writes*') { break }
    }
    return ($keep -join "`n")
}

if ($Into) {
    $target = (Resolve-Path -LiteralPath $Into -ErrorAction Stop).Path
    Write-Host "Installing Tapestry into $target"
    if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
        throw "$target is not a git repository (run 'git init' there first)"
    }

    # Directories are merged file by file without overwriting anything that exists.
    foreach ($item in @('.claude', '.tapestry', '.github', '.githooks', 'scripts', 'bin')) {
        $from = Join-Path $src $item
        if (-not (Test-Path -LiteralPath $from)) { continue }
        Get-ChildItem -LiteralPath $from -Recurse -File -Force | ForEach-Object {
            $rel = $_.FullName.Substring($from.Length).TrimStart('\', '/')
            # never copy feature folders or anything personal / machine-local
            # Nothing personal, per-feature or learned about THIS project; the target starts blank.
            $r = ($rel -replace '\\', '/')
            if ($item -eq '.tapestry' -and ($r -like 'features/*' -or $r -like 'logs/*' -or $r -like 'test-runs/*' -or $r -like 'knowledge/*' -or $r -eq 'config.json' -or $r -eq 'config.local.json')) { return }
            if ($item -eq '.claude' -and ($r -like 'worktrees/*' -or $r -like 'agent-memory/*' -or $r -like 'agent-memory-local/*' -or $r -eq 'settings.local.json')) { return }
            if ($item -eq '.claude' -and $r -like 'rules/project/*' -and $r -ne 'rules/project/README.md') { return }
            $dest = Join-Path (Join-Path $target $item) $rel
            if (Test-Path -LiteralPath $dest) {
                Write-Host "  skip $item\$rel (exists)"
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $dest -ErrorAction Stop
            }
        }
        Write-Host "  merged $item\"
    }

    # Blank project profile and empty knowledge base for the new project.
    $tcfg = Join-Many @($target, '.tapestry', 'config.json')
    if (-not (Test-Path -LiteralPath $tcfg)) {
        Copy-Item -LiteralPath (Join-Many @($src, '.tapestry', 'templates', 'config.json')) -Destination $tcfg
        Write-Host '  created blank .tapestry\config.json'
    }
    $kdir = Join-Many @($target, '.tapestry', 'knowledge')
    New-Item -ItemType Directory -Force -Path $kdir | Out-Null
    $kreadme = Join-Path $kdir 'README.md'
    if (-not (Test-Path -LiteralPath $kreadme)) { Copy-Item -LiteralPath (Join-Many @($src, '.tapestry', 'knowledge', 'README.md')) -Destination $kreadme }
    foreach ($k in @('Architecture', 'Decisions', 'Conventions', 'Gotchas', 'Glossary')) {
        $kf = Join-Path $kdir ($k.ToLower() + '.md')
        if (-not (Test-Path -LiteralPath $kf)) { Set-Content -LiteralPath $kf -Value ("# $k`n`n_Empty. The librarian fills this after the first feature is merged (``/tapestry-learn``). You can also write here by hand._") }
    }

    foreach ($file in @('REVIEW.md', '.gitattributes')) {
        $dest = Join-Path $target $file
        if (Test-Path -LiteralPath $dest) { Write-Host "  skip $file (exists)" }
        else { Copy-Item -LiteralPath (Join-Path $src $file) -Destination $dest; Write-Host "  copied $file" }
    }

    $claudeMd = Join-Path $target 'CLAUDE.md'
    if ((Test-Path -LiteralPath $claudeMd) -and (Select-String -LiteralPath $claudeMd -SimpleMatch '<!-- Tapestry -->' -Quiet)) {
        Write-Host '  skip CLAUDE.md (Tapestry section present)'
    } elseif (Test-Path -LiteralPath $claudeMd) {
        Add-Content -LiteralPath $claudeMd -Value ("`n<!-- Tapestry -->`n" + (Get-TapestryClaudeMd $src))
        Write-Host '  CLAUDE.md exists; appended Tapestry section'
    } else {
        Set-Content -LiteralPath $claudeMd -Value (Get-TapestryClaudeMd $src)
        Write-Host '  copied CLAUDE.md'
    }

    $gitignore = Join-Path $target '.gitignore'
    $hasEntry = (Test-Path -LiteralPath $gitignore) -and (Select-String -LiteralPath $gitignore -Pattern '^\.claude/worktrees' -Quiet)
    if (-not $hasEntry) {
        Add-Content -LiteralPath $gitignore -Value "`n# Tapestry`n.claude/worktrees/`n.claude/settings.local.json`n.claude/agent-memory-local/`nCLAUDE.local.md`n.tapestry/config.local.json`n.tapestry/logs/`n.tapestry/test-runs/"
        Write-Host '  updated .gitignore'
    }
}

# Git hooks: pre-push enforces the optional personal push window (a no-op without one).
# Git for Windows runs hooks with its own bundled shell, whichever terminal you push from.
$currentHooks = & git -C $target config --get core.hooksPath 2>$null
if (-not $currentHooks) {
    & git -C $target config core.hooksPath .githooks
    Write-Host 'set git core.hooksPath=.githooks (pre-push honours your push window, if you configure one)'
} elseif ($currentHooks -ne '.githooks') {
    Write-Host "note: core.hooksPath is already '$currentHooks'; copy .githooks\pre-push there to enable the push window for your own pushes"
}

# Line endings: shell scripts must stay LF for Git Bash, which Claude Code uses to run hooks.
$hook = Join-Many @($target, '.claude', 'hooks', 'guard-bash.sh')
if ((Test-Path -LiteralPath $hook) -and ([System.IO.File]::ReadAllText($hook).Contains("`r`n"))) {
    Write-Host 'warning: hook scripts have CRLF line endings. Fix once with:  git rm --cached -r . ; git reset --hard' -ForegroundColor Yellow
}

if ((-not $KeepExamples) -and ($target -eq $src) -and (Test-Path -LiteralPath (Join-Path $target 'examples'))) {
    Write-Host 'note: examples\ contains the walkthrough artifacts; delete it once you no longer need it'
}
New-Item -ItemType Directory -Force -Path (Join-Many @($target, '.tapestry', 'features')) | Out-Null

Write-Host ''
& (Join-Many @($target, 'scripts', 'tapestry-doctor.ps1'))
Write-Host ''
Write-Host 'Next:'
Write-Host "  cd `"$target`""
Write-Host '  claude                  # start Claude Code'
Write-Host '  /tapestry-setup         # fill in the project profile (stack, commands, base branch)'
Write-Host '  /tapestry-new <idea>    # start your first feature'
