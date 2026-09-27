param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRoot
)

$ErrorActionPreference = 'Stop'

# Fail before any filesystem write if TargetRoot is missing/empty.
if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
    [Console]::Error.WriteLine('Install refused: TargetRoot is required (no default). Pass -TargetRoot explicitly.')
    exit 1
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectId = 'claude-code-multi-agent-workflow'
$manifestDirName = '.claude-multi-agent-workflow'
$manifestDir = Join-Path $TargetRoot $manifestDirName
$manifestPath = Join-Path $manifestDir 'manifest.tsv'

# Fixed allow-list of exactly 8 project-relative paths
$allowedRels = @(
    'agents/premise-overturner.md',
    'agents/assumption-challenger.md',
    'agents/test-designer.md',
    'agents/metric-gate.md',
    'agents/rollback-planner.md',
    'agents/range-creep-guardian.md',
    'skills/three-review/SKILL.md',
    'skills/six-role-drill/SKILL.md'
)
$allowedSet = @{}
foreach ($r in $allowedRels) { $allowedSet[$r] = $true }

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-SafeRelPath([string]$Rel) {
    if ([string]::IsNullOrWhiteSpace($Rel)) { return $false }
    if ($Rel -match '^[A-Za-z]:') { return $false }          # drive letter
    if ($Rel.StartsWith('/') -or $Rel.StartsWith('\')) { return $false }  # absolute
    if ($Rel.Contains('\')) { return $false }                 # backslash
    if ($Rel.Contains('//')) { return $false }
    $segments = $Rel.Split('/')
    foreach ($seg in $segments) {
        if ($seg -eq '' -or $seg -eq '.' -or $seg -eq '..') { return $false }
    }
    return $true
}

function Resolve-UnderRoot([string]$Root, [string]$Rel) {
    $rootFull = [IO.Path]::GetFullPath($Root)
    $combined = [IO.Path]::GetFullPath((Join-Path $rootFull ($Rel -replace '/', [IO.Path]::DirectorySeparatorChar)))
    $prefix = $rootFull.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $combined.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $combined
}

# Parse and fully validate manifest (if present). Returns hashtable or $null on missing; throws on invalid.
function Read-ValidatedManifest {
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
    $map = @{}
    $seen = @{}
    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        $lineNo++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith('#')) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -ne 3) { throw "manifest line ${lineNo}: malformed (need 3 tab-separated fields)" }
        $proj = $parts[0]
        $rel = $parts[1]
        $hash = $parts[2].ToLowerInvariant()
        if ($proj -ne $projectId) { throw "manifest line ${lineNo}: unexpected project id '$proj'" }
        if (-not (Test-SafeRelPath $rel)) { throw "manifest line ${lineNo}: unsafe or malformed path '$rel'" }
        if (-not $allowedSet.ContainsKey($rel)) { throw "manifest line ${lineNo}: path not in allow-list '$rel'" }
        if ($seen.ContainsKey($rel)) { throw "manifest line ${lineNo}: duplicate path '$rel'" }
        if ($hash -notmatch '^[0-9a-f]{64}$') { throw "manifest line ${lineNo}: invalid sha256" }
        if ($null -eq (Resolve-UnderRoot $TargetRoot $rel)) { throw "manifest line ${lineNo}: path escapes TargetRoot '$rel'" }
        $seen[$rel] = $true
        $map[$rel] = $hash
    }
    foreach ($rel in $allowedRels) {
        if (-not $map.ContainsKey($rel)) { throw "manifest missing required path '$rel'" }
    }
    foreach ($rel in $map.Keys) {
        if (-not $allowedSet.ContainsKey($rel)) { throw "manifest has extra path '$rel'" }
    }
    return $map
}

# ---- Validate existing manifest before any write ----
$owned = $null
try {
    $owned = Read-ValidatedManifest
} catch {
    [Console]::Error.WriteLine("Install aborted before any write: invalid manifest — $($_.Exception.Message)")
    exit 1
}

# ---- Preflight all 8 targets ----
$plan = @()
$failures = @()
foreach ($rel in $allowedRels) {
    $src = Join-Path $repoRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    $dest = Resolve-UnderRoot $TargetRoot $rel
    if ($null -eq $dest) {
        $failures += "path escapes TargetRoot: $rel"
        continue
    }
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        $failures += "missing source: $rel"
        continue
    }
    if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
        $plan += @{ Rel = $rel; Src = $src; Dest = $dest; Mode = 'install' }
        continue
    }
    if ($null -eq $owned) {
        $failures += "conflict without ownership proof: $rel"
        continue
    }
    $cur = Get-Sha256 $dest
    if ($cur -ne $owned[$rel]) {
        $failures += "installed file modified by user: $rel"
        continue
    }
    $plan += @{ Rel = $rel; Src = $src; Dest = $dest; Mode = 'upgrade' }
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
foreach ($rel in $allowedRels) {
    $dest = Resolve-UnderRoot $TargetRoot $rel
    $hash = Get-Sha256 $dest
    $lines += "$projectId`t$rel`t$hash"
}
$tmp = "$manifestPath.tmp"
Set-Content -LiteralPath $tmp -Value $lines -Encoding ascii
Move-Item -LiteralPath $tmp -Destination $manifestPath -Force

Write-Output "Installed $($allowedRels.Count) files into $TargetRoot (manifest published)"
exit 0
