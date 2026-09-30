# Launch Claude Code with the right Tapestry command, from Windows Terminal / PowerShell.
#
#   .\bin\tapestry.ps1 install                    first-time install: git hooks, checks (scripts\setup.ps1)
#   .\bin\tapestry.ps1 setup                      interactive project onboarding (/tapestry-setup)
#   .\bin\tapestry.ps1 new "idea"                 create a feature folder
#   .\bin\tapestry.ps1 interview <id>             stage 1 (interactive)
#   .\bin\tapestry.ps1 plan <id>                  stage 2
#   .\bin\tapestry.ps1 run <id> [--wave N]        stages 3+4
#   .\bin\tapestry.ps1 review <pr>                review one PR
#   .\bin\tapestry.ps1 learn <id>                 stage 5
#   .\bin\tapestry.ps1 status [id]                print status (no Claude session)
#   .\bin\tapestry.ps1 doctor                     environment check (no Claude session)
#   .\bin\tapestry.ps1 window                     is GitHub activity held right now?
#   .\bin\tapestry.ps1 trace on|off|status|clear  record agent/tool events for a test run (via Git Bash)
#   .\bin\tapestry.ps1 report <id>                PASS/FAIL test-run report for a feature (via Git Bash)
#
# Add -Headless (or --headless) to run non-interactively (claude -p) for plan, run, review, learn.
# From cmd.exe, or if PowerShell refuses to run scripts, use bin\tapestry.cmd with the same arguments.
# Works on Windows PowerShell 5.1 and PowerShell 7+. Keep this file ASCII-only.
param(
    [Parameter(Position = 0)][string]$Command = 'help',
    [switch]$Headless,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest
)

$root = Split-Path -Parent $PSScriptRoot
$scripts = Join-Path $root 'scripts'
$argList = @()
foreach ($a in @($Rest)) { if ($a -eq '--headless') { $Headless = $true } elseif ($a) { $argList += $a } }
$argText = ($argList -join ' ')

function Invoke-GitBash([string]$script, [string[]]$scriptArgs) {
    # Runs one of the scripts/*.sh helpers with Git for Windows' bash (never WSL's System32\bash.exe).
    $bash = $null
    if ($env:CLAUDE_CODE_GIT_BASH_PATH -and (Test-Path -LiteralPath $env:CLAUDE_CODE_GIT_BASH_PATH)) { $bash = $env:CLAUDE_CODE_GIT_BASH_PATH }
    if (-not $bash) {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if ($git) {
            $candidate = Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $git.Source)) 'bin') 'bash.exe'
            if (Test-Path -LiteralPath $candidate) { $bash = $candidate }
        }
    }
    if (-not $bash) { $bash = 'bash' }   # macOS/Linux, or Git Bash already on PATH
    & $bash (Join-Path $scripts $script) @scriptArgs
}

function Start-Claude([string]$line, [bool]$allowHeadless) {
    Push-Location $root
    try {
        if ($Headless -and $allowHeadless) { & claude -p $line --permission-mode acceptEdits --output-format text }
        else { & claude $line }
    } finally { Pop-Location }
}

switch ($Command) {
    'install'   { & (Join-Path $scripts 'setup.ps1') @argList }
    'setup'     { Start-Claude '/tapestry-setup' $false }
    'new'       { Start-Claude "/tapestry-new $argText" $false }
    'interview' { Start-Claude "/tapestry-interview $argText" $false }
    'plan'      { Start-Claude "/tapestry-plan $argText" $true }
    'run'       { Start-Claude "/tapestry-run $argText" $true }
    'review'    { Start-Claude "/tapestry-review $argText" $true }
    'learn'     { Start-Claude "/tapestry-learn $argText" $true }
    'status'    { if ($argList.Count -gt 0) { & (Join-Path $scripts 'tapestry-status.ps1') $argList[0] } else { & (Join-Path $scripts 'tapestry-status.ps1') } }
    'doctor'    { & (Join-Path $scripts 'tapestry-doctor.ps1') }
    'trace'     { Invoke-GitBash 'tapestry-trace.sh' $argList }
    'report'    { Invoke-GitBash 'tapestry-report.sh' $argList }
    'window'    { $m = & (Join-Path $scripts 'push-window.ps1'); if ($LASTEXITCODE -eq 0) { 'GitHub activity allowed now' } else { $m } }
    default     { Get-Content -LiteralPath $PSCommandPath | Select-Object -Skip 1 -First 18 | ForEach-Object { $_ -replace '^# ?', '' } }
}
