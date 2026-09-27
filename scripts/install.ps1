param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$projectId = 'claude-code-multi-agent-workflow'
$manifestDir = Join-Path $TargetRoot '.claude-multi-agent-workflow'
$manifestPath = Join-Path $manifestDir 'manifest.tsv'

# 8 install targets: 6 agents + 2 skill project files
$targets = @(
    @{ Src = 'agents/premise-overturner.md';        Rel = 'agents/premise-overturner.md' },
    @{ Src = 'agents/assumption-challenger.md';     Rel = 'agents/assumption-challenger.md' },
    @{ Src = 'agents/test-designer.md';             Rel = 'agents/test-designer.md' },
    @{ Src = 'agents/metric-gate.md';               Rel = 'agents/metric-gate.md' },
    @{ Src = 'agents/rollback-planner.md';          Rel = 'agents/rollback-planner.md' },
    @{ Src = 'agents/range-creep-guardian.md';      Rel = 'agents/range-creep-guardian.md' },
    @{ Src = 'skills/three-review/SKILL.md';        Rel = 'skills/three-review/SKILL.md' },
    @{ Src = 'skills/six-role-drill/SKILL.md';      Rel = 'skills/six-role-drill/SKILL.md' }
)

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-Manifest {
    $map = @{}
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith('#')) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 3) { continue }
        if ($parts[0] -ne $projectId) { continue }
        $map[$parts[1]] = $parts[2].ToLowerInvariant()
    }
    return $map
}

# ---- Preflight all 8 targets before any write ----
$owned = Read-Manifest
$plan = @()
$failures = @()

foreach ($t in $targets) {
    $dest = Join-Path $TargetRoot ($t.Rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    $src = Join-Path $repoRoot ($t.Src -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        $failures += "missing source: $($t.Src)"
        continue
    }
    if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
        $plan += @{ Rel = $t.Rel; Src = $src; Dest = $dest; Mode = 'install' }
        continue
    }
    if ($null -eq $owned -or -not $owned.ContainsKey($t.Rel)) {
        $failures += "conflict without ownership proof: $($t.Rel)"
        continue
    }
    $cur = Get-Sha256 $dest
    if ($cur -ne $owned[$t.Rel]) {
        $failures += "installed file modified by user: $($t.Rel)"
        continue
    }
    $plan += @{ Rel = $t.Rel; Src = $src; Dest = $dest; Mode = 'upgrade' }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine('Install aborted before any write:')
    foreach ($f in $failures) { [Console]::Error.WriteLine("- $f") }
    exit 1
}

# ---- Write only after full preflight pass ----
foreach ($p in $plan) {
    $dir = Split-Path -Parent $p.Dest
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item -LiteralPath $p.Src -Destination $p.Dest -Force
}

# Publish manifest only after all files are in place (atomic replace)
New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
$lines = @('# claude-code-multi-agent-workflow manifest v1', "# project`trelpath`tsha256")
foreach ($t in $targets) {
    $dest = Join-Path $TargetRoot ($t.Rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    $hash = Get-Sha256 $dest
    $lines += "$projectId`t$($t.Rel)`t$hash"
}
$tmp = "$manifestPath.tmp"
Set-Content -LiteralPath $tmp -Value $lines -Encoding ascii
Move-Item -LiteralPath $tmp -Destination $manifestPath -Force

Write-Output "Installed $($targets.Count) files into $TargetRoot (manifest published)"
exit 0
