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
            if ($rel -like 'features*' -or $rel -like 'worktrees*' -or $rel -like 'agent-memory-local*' -or $rel -eq 'config.local.json' -or $rel -eq 'settings.local.json') { return }
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

    foreach ($file in @('REVIEW.md', '.gitattributes')) {
        $dest = Join-Path $target $file
        if (Test-Path -LiteralPath $dest) { Write-Host "  skip $file (exists)" }
        else { Copy-Item -LiteralPath (Join-Path $src $file) -Destination $dest; Write-Host "  copied $file" }
    }

    $claudeMd = Join-Path $target 'CLAUDE.md'
    if ((Test-Path -LiteralPath $claudeMd) -and (Select-String -LiteralPath $claudeMd -SimpleMatch '<!-- Tapestry -->' -Quiet)) {
        Write-Host '  skip CLAUDE.md (Tapestry section present)'
    } elseif (Test-Path -LiteralPath $claudeMd) {
        Add-Content -LiteralPath $claudeMd -Value ("`n<!-- Tapestry -->`n" + (Get-Content -Raw -LiteralPath (Join-Path $src 'CLAUDE.md')))
        Write-Host '  CLAUDE.md exists; appended Tapestry section'
    } else {
        Copy-Item -LiteralPath (Join-Path $src 'CLAUDE.md') -Destination $claudeMd
        Write-Host '  copied CLAUDE.md'
    }

    $gitignore = Join-Path $target '.gitignore'
    $hasEntry = (Test-Path -LiteralPath $gitignore) -and (Select-String -LiteralPath $gitignore -Pattern '^\.claude/worktrees' -Quiet)
    if (-not $hasEntry) {
        Add-Content -LiteralPath $gitignore -Value "`n# Tapestry`n.claude/worktrees/`n.claude/settings.local.json`n.claude/agent-memory-local/`nCLAUDE.local.md`n.tapestry/config.local.json"
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
