# Print Tapestry pipeline status (PowerShell twin of scripts/tapestry-status.sh).
#   .\scripts\tapestry-status.ps1            all features
#   .\scripts\tapestry-status.ps1 <id>       one feature: task board, last events, blocked section
# Works on Windows PowerShell 5.1 and PowerShell 7+. Keep this file ASCII-only.
param([string]$Feature = '')

$root = Split-Path -Parent $PSScriptRoot
$features = Join-Path (Join-Path $root '.tapestry') 'features'

function Get-Field([string]$path, [string]$name) {
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    $line = Select-String -LiteralPath $path -Pattern ("^" + [regex]::Escape($name) + ":") | Select-Object -First 1
    if (-not $line) { return '' }
    return (($line.Line -replace ("^" + [regex]::Escape($name) + ":\s*"), '') -replace '\s+#.*$', '').Trim()
}

if (-not $Feature) {
    '{0,-40} {1,-12} {2}' -f 'feature', 'stage', 'tasks (merged/total)'
    $dirs = @(Get-ChildItem -LiteralPath $features -Directory -ErrorAction SilentlyContinue)
    if ($dirs.Count -eq 0) { '(no features yet - run /tapestry-new <idea> inside claude)'; exit 0 }
    foreach ($d in $dirs) {
        $tasks = @(Get-ChildItem -LiteralPath (Join-Path $d.FullName 'tasks') -Filter '*.md' -ErrorAction SilentlyContinue)
        $merged = @($tasks | Where-Object { (Get-Field $_.FullName 'status') -eq 'merged' })
        '{0,-40} {1,-12} {2}/{3}' -f $d.Name, (Get-Field (Join-Path $d.FullName 'progress.md') 'stage'), $merged.Count, $tasks.Count
    }
    exit 0
}

$dir = Join-Path $features $Feature
if (-not (Test-Path -LiteralPath $dir)) { Write-Error "no such feature: $Feature"; exit 1 }
$ledger = Join-Path $dir 'progress.md'

"== $Feature =="
'stage: {0}   wave: {1}   spec: {2}   plan: {3}' -f (Get-Field $ledger 'stage'), (Get-Field $ledger 'current_wave'), (Get-Field (Join-Path $dir 'spec.md') 'status'), (Get-Field (Join-Path $dir 'plan.md') 'status')
''
'{0,-4} {1,-5} {2,-12} {3,-6} {4}' -f 'task', 'wave', 'status', 'pr', 'title'
foreach ($t in @(Get-ChildItem -LiteralPath (Join-Path $dir 'tasks') -Filter '*.md' -ErrorAction SilentlyContinue)) {
    $title = Get-Field $t.FullName 'title'
    if ($title.Length -gt 40) { $title = $title.Substring(0, 40) }
    '{0,-4} {1,-5} {2,-12} {3,-6} {4}' -f (Get-Field $t.FullName 'task'), (Get-Field $t.FullName 'wave'), (Get-Field $t.FullName 'status'), (Get-Field $t.FullName 'pr'), $title
}

$lines = @(Get-Content -LiteralPath $ledger)
''
'last events:'
$inFence = $false; $events = @()
foreach ($l in $lines) {
    if ($l -match '^```') { $inFence = -not $inFence; continue }
    if ($inFence) { $events += $l }
}
$events | Select-Object -Last 10 | ForEach-Object { '  ' + $_ }
''
'blocked / needs human:'
$inBlocked = $false; $blocked = @()
foreach ($l in $lines) {
    if ($l -match '^## Blocked') { $inBlocked = $true; continue }
    if ($l -match '^## ') { $inBlocked = $false }
    if ($inBlocked -and $l.Trim() -and ($l -notmatch '^<!--')) { $blocked += $l }
}
if ($blocked.Count -eq 0) { '  (none)' } else { $blocked | ForEach-Object { '  ' + $_ } }
