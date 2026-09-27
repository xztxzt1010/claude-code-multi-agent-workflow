param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
    [Console]::Error.WriteLine('Uninstall refused: TargetRoot is required (no default). Pass -TargetRoot explicitly.')
    exit 1
}

$projectId = 'claude-code-multi-agent-workflow'
$manifestDirName = '.claude-multi-agent-workflow'
$manifestDir = Join-Path $TargetRoot $manifestDirName
$manifestPath = Join-Path $manifestDir 'manifest.tsv'

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
    if ($Rel -match '^[A-Za-z]:') { return $false }
    if ($Rel.StartsWith('/') -or $Rel.StartsWith('\')) { return $false }
    if ($Rel.Contains('\')) { return $false }
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

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    [Console]::Error.WriteLine("Uninstall refused: ownership manifest not found at $manifestPath (will not guess ownership by filename)")
    exit 1
}

# ---- Full manifest validation before any delete ----
$entries = @{}
$seen = @{}
$lineNo = 0
try {
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        $lineNo++
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -ne 3) { throw "line ${lineNo}: malformed (need 3 tab-separated fields)" }
        $proj = $parts[0]
        $rel = $parts[1]
        $hash = $parts[2].ToLowerInvariant()
        if ($proj -ne $projectId) { throw "line ${lineNo}: unexpected project id '$proj'" }
        if (-not (Test-SafeRelPath $rel)) { throw "line ${lineNo}: unsafe or malformed path '$rel'" }
        if (-not $allowedSet.ContainsKey($rel)) { throw "line ${lineNo}: path not in allow-list '$rel'" }
        if ($seen.ContainsKey($rel)) { throw "line ${lineNo}: duplicate path '$rel'" }
        if ($hash -notmatch '^[0-9a-f]{64}$') { throw "line ${lineNo}: invalid sha256" }
        if ($null -eq (Resolve-UnderRoot $TargetRoot $rel)) { throw "line ${lineNo}: path escapes TargetRoot '$rel'" }
        $seen[$rel] = $true
        $entries[$rel] = $hash
    }
    foreach ($rel in $allowedRels) {
        if (-not $entries.ContainsKey($rel)) { throw "manifest missing required path '$rel'" }
    }
    foreach ($rel in $entries.Keys) {
        if (-not $allowedSet.ContainsKey($rel)) { throw "manifest has extra path '$rel'" }
    }
} catch {
    [Console]::Error.WriteLine("Uninstall aborted with zero deletes: invalid manifest — $($_.Exception.Message)")
    exit 1
}

# ---- Verify ALL paths and hashes before deleting anything ----
$failures = @()
foreach ($rel in $allowedRels) {
    $dest = Resolve-UnderRoot $TargetRoot $rel
    if ($null -eq $dest) {
        $failures += "path escapes TargetRoot: $rel"
        continue
    }
    if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
        $failures += "missing installed file: $rel"
        continue
    }
    $cur = Get-Sha256 $dest
    if ($cur -ne $entries[$rel]) {
        $failures += "installed file modified by user: $rel"
        continue
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine('Uninstall aborted with zero deletes:')
    foreach ($f in $failures) { [Console]::Error.WriteLine("- $f") }
    exit 1
}

# ---- Delete only after full validation and hash verification ----
foreach ($rel in $allowedRels) {
    $dest = Resolve-UnderRoot $TargetRoot $rel
    Remove-Item -LiteralPath $dest -Force
}

foreach ($relDir in @('skills/three-review', 'skills/six-role-drill', 'skills', 'agents')) {
    $dir = Join-Path $TargetRoot ($relDir -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $dir -PathType Container) {
        $left = @(Get-ChildItem -LiteralPath $dir -Force)
        if ($left.Count -eq 0) {
            Remove-Item -LiteralPath $dir -Force
        }
    }
}

Remove-Item -LiteralPath $manifestPath -Force
$leftInManifestDir = @(Get-ChildItem -LiteralPath $manifestDir -Force)
if ($leftInManifestDir.Count -eq 0) {
    Remove-Item -LiteralPath $manifestDir -Force
}

Write-Output "Uninstalled $($entries.Count) owned files from $TargetRoot (manifest removed)"
exit 0
