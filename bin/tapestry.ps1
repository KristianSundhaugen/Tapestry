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
    'window'    { $m = & (Join-Path $scripts 'push-window.ps1'); if ($LASTEXITCODE -eq 0) { 'GitHub activity allowed now' } else { $m } }
    default     { Get-Content -LiteralPath $PSCommandPath | Select-Object -Skip 1 -First 16 | ForEach-Object { $_ -replace '^# ?', '' } }
}
