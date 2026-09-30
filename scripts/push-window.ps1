# Is GitHub activity (push, PR, comment, merge) allowed right now?
#   exit 0  allowed
#   exit 1  held; the reason is written to the output
#
# PowerShell twin of scripts/push-window.sh (the git pre-push hook uses the .sh one).
# Reads git.pushWindow from .tapestry\config.local.json (personal, gitignored) layered
# over .tapestry\config.json, both from the MAIN checkout.
#
# Bypass once:   $env:TAPESTRY_PUSH_NOW = '1'; git push; Remove-Item Env:TAPESTRY_PUSH_NOW
# Test a time:   $env:TAPESTRY_CLOCK = '3 10:30'; .\scripts\push-window.ps1   (ISO weekday, HH:MM)
# Works on Windows PowerShell 5.1 and PowerShell 7+. Keep this file ASCII-only.

if ($env:TAPESTRY_PUSH_NOW -eq '1') { exit 0 }

$here = Split-Path -Parent $PSScriptRoot
$main = $here
$common = & git -C $here rev-parse --path-format=absolute --git-common-dir 2>$null
if ($LASTEXITCODE -eq 0 -and $common -and ((Split-Path -Leaf $common) -eq '.git')) {
    $main = Split-Path -Parent $common
}

$window = @{}
foreach ($name in @('config.json', 'config.local.json')) {
    $path = Join-Path (Join-Path $main '.tapestry') $name
    if (-not (Test-Path -LiteralPath $path)) { continue }
    try {
        $json = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    } catch {
        Write-Output "cannot read $path; holding to be safe (override once with TAPESTRY_PUSH_NOW=1)."
        exit 1
    }
    if ($json.git -and $json.git.pushWindow) {
        foreach ($p in $json.git.pushWindow.PSObject.Properties) { $window[$p.Name] = $p.Value }
    }
}

if (-not $window['enabled']) { exit 0 }

$names = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
$days = @($names[0..4])
if ($window['days']) { $days = @($window['days']) }
$holdFrom = '08:00'
if ($window['holdFrom']) { $holdFrom = [string]$window['holdFrom'] }
$holdUntil = '16:00'
if ($window['holdUntil']) { $holdUntil = [string]$window['holdUntil'] }

if ($env:TAPESTRY_CLOCK) {
    $parts = $env:TAPESTRY_CLOCK.Split(' ')
    $dow = [int]$parts[0]
    $hm = $parts[1]
} else {
    $now = Get-Date
    $dow = [int]$now.DayOfWeek
    if ($dow -eq 0) { $dow = 7 }
    $hm = $now.ToString('HH:mm')
}

function ConvertTo-Minutes([string]$text) {
    $bits = $text.Trim().Split(':')
    return ([int]$bits[0]) * 60 + [int]$bits[1]
}

if ($days -notcontains $names[$dow - 1]) { exit 0 }

$n = ConvertTo-Minutes $hm
$a = ConvertTo-Minutes $holdFrom
$b = ConvertTo-Minutes $holdUntil
if ($a -le $b) { $held = ($n -ge $a) -and ($n -lt $b) } else { $held = ($n -ge $a) -or ($n -lt $b) }

if ($held) {
    Write-Output ("GitHub activity is held {0}-{1} on {2} (git.pushWindow in .tapestry\config.local.json). Keep committing locally; push after {1}." -f $holdFrom, $holdUntil, ($days -join '/'))
    exit 1
}
exit 0
