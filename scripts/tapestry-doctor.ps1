# Tapestry doctor for Windows Terminal / PowerShell.
# Checks what Tapestry needs. Never fails hard; prints OK / WARN / MISSING per item.
# Usage:  .\scripts\tapestry-doctor.ps1
# Works on Windows PowerShell 5.1 and PowerShell 7+. Keep this file ASCII-only.

$root = Split-Path -Parent $PSScriptRoot

function Write-Ok([string]$m)   { Write-Host ('  OK       ' + $m) -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host ('  WARN     ' + $m) -ForegroundColor Yellow }
function Write-Miss([string]$m) { Write-Host ('  MISSING  ' + $m) -ForegroundColor Red }
function Write-Info([string]$m) { Write-Host ('           ' + $m) }
function Test-Command([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Find-Python {
    # "python3"/"python" can be the Microsoft Store stub: on PATH, but it only prints an install hint.
    foreach ($c in @('python3', 'python', 'py')) {
        if (Test-Command $c) {
            & $c -c 'import json, sys' *> $null
            if ($LASTEXITCODE -eq 0) { return $c }
        }
    }
    return $null
}

function Find-GitBash {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { return $null }
    # ...\Git\cmd\git.exe  ->  ...\Git\bin\bash.exe
    $gitRoot = Split-Path -Parent (Split-Path -Parent $git.Source)
    $bash = Join-Path (Join-Path $gitRoot 'bin') 'bash.exe'
    if (Test-Path -LiteralPath $bash) { return $bash }
    return $null
}

Write-Host 'Tapestry doctor'
Write-Host 'required:'

if (Test-Command git) { Write-Ok ((& git --version) -replace '^git version ', 'git ') } else { Write-Miss 'git: winget install Git.Git' }

$isWindowsHost = ($env:OS -eq 'Windows_NT')
if ($isWindowsHost) {
    $gitBash = Find-GitBash
    if ($gitBash) {
        Write-Ok "Git Bash (Claude Code runs hooks with it; you never need to open it): $gitBash"
    } else {
        Write-Miss 'Git Bash from Git for Windows (Claude Code runs the Tapestry hooks with it): winget install Git.Git'
    }
}

$py = Find-Python
if ($py) {
    $ver = & $py -c 'import platform; print(platform.python_version())'
    Write-Ok "python ($py $ver)"
} else {
    Write-Miss 'a working Python 3 (hooks and scripts need it; without it the git guard only blocks force-pushes)'
    if ((Test-Command python3) -or (Test-Command python)) {
        Write-Info "'python'/'python3' on PATH is the Microsoft Store stub. Fix: winget install Python.Python.3.12,"
        Write-Info 'then Settings > Apps > Advanced app settings > App execution aliases: turn off python.exe and python3.exe.'
        Write-Info 'Open a new Windows Terminal tab afterwards.'
    }
}

if (Test-Command claude) {
    $cv = (& claude --version 2>$null | Select-Object -First 1)
    Write-Ok "claude $cv"
} else {
    Write-Miss 'claude (Claude Code): winget install Anthropic.ClaudeCode   or   irm https://claude.ai/install.ps1 | iex'
}

if (Test-Command gh) {
    & gh auth status *> $null
    if ($LASTEXITCODE -eq 0) { Write-Ok 'gh authenticated' } else { Write-Warn "gh installed but not authenticated: gh auth login" }
} else {
    Write-Miss 'gh (GitHub CLI; agents open and merge PRs with it): winget install GitHub.cli, then gh auth login'
}

Write-Host 'repository:'
& git -C $root rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Ok 'git repository'
    $remote = & git -C $root remote get-url origin 2>$null
    if ($remote) { Write-Ok "origin: $remote" } else { Write-Warn "no 'origin' remote; PRs need one" }
    $default = & git -C $root symbolic-ref --short refs/remotes/origin/HEAD 2>$null
    if ($default) { Write-Ok ('default branch: ' + ($default -replace '^origin/', '')) } else { Write-Warn 'default branch unknown (run: git remote set-head origin -a)' }
    if (-not (Test-Path -LiteralPath (Join-Path $root '.gitattributes'))) { Write-Warn '.gitattributes missing; shell scripts may get CRLF line endings' }
} else {
    Write-Miss 'not a git repository'
}

Write-Host 'config:'
$cfgPath = Join-Path (Join-Path $root '.tapestry') 'config.json'
if (Test-Path -LiteralPath $cfgPath) {
    try {
        $cfg = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json
        if ($cfg.project.name) { Write-Ok ("project '" + $cfg.project.name + "'") } else { Write-Warn '.tapestry\config.json not filled in: run /tapestry-setup inside claude' }
        if ($cfg.commands.test) { Write-Ok ('test command: ' + $cfg.commands.test) } else { Write-Warn 'no test command configured; agents cannot prove work until there is one' }
    } catch {
        Write-Miss ".tapestry\config.json is not valid JSON: $($_.Exception.Message)"
    }
} else {
    Write-Miss '.tapestry\config.json'
}

Write-Host 'push window:'
$hp = & git -C $root config --get core.hooksPath 2>$null
if ($hp -eq '.githooks') { Write-Ok 'git pre-push hook active (core.hooksPath=.githooks)' } else { Write-Warn 'git pre-push hook not active: git config core.hooksPath .githooks' }
$localCfg = Join-Path (Join-Path $root '.tapestry') 'config.local.json'
if (Test-Path -LiteralPath $localCfg) {
    $msg = & (Join-Path $PSScriptRoot 'push-window.ps1')
    if ($LASTEXITCODE -eq 0) { Write-Ok 'configured; GitHub activity allowed right now' } else { Write-Ok "configured; HELD right now: $msg" }
} else {
    Write-Ok 'not configured (optional: Copy-Item .tapestry\config.local.example.json .tapestry\config.local.json)'
}

Write-Host 'optional (reviewer scanners):'
if (Test-Command semgrep)  { Write-Ok 'semgrep' }  else { Write-Warn 'semgrep not installed  (pip install semgrep)' }
if (Test-Command gitleaks) { Write-Ok 'gitleaks' } else { Write-Warn 'gitleaks not installed (winget install Gitleaks.Gitleaks)' }
if (Test-Command trivy)    { Write-Ok 'trivy' }    else { Write-Warn 'trivy not installed    (only needed for container/IaC projects)' }

Write-Host 'hooks:'
foreach ($h in @('guard-bash.sh', 'post-edit-format.sh', 'session-start.sh')) {
    $hookPath = Join-Path (Join-Path (Join-Path $root '.claude') 'hooks') $h
    if (Test-Path -LiteralPath $hookPath) {
        $content = [System.IO.File]::ReadAllText($hookPath)
        if ($content.Contains("`r`n")) { Write-Warn "$h has CRLF line endings; run: git rm --cached -r . ; git reset --hard" } else { Write-Ok "$h present (LF)" }
    } else {
        Write-Miss ".claude\hooks\$h"
    }
}
exit 0
