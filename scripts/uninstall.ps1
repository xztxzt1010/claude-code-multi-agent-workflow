param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRoot
)

$ErrorActionPreference = 'Stop'
$projectId = 'claude-code-multi-agent-workflow'
$manifestDir = Join-Path $TargetRoot '.claude-multi-agent-workflow'
$manifestPath = Join-Path $manifestDir 'manifest.tsv'

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    [Console]::Error.WriteLine("Uninstall refused: ownership manifest not found at $manifestPath (will not guess ownership by filename)")
    exit 1
}

$entries = @()
foreach ($line in Get-Content -LiteralPath $manifestPath) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $parts = $line -split "`t"
    if ($parts.Count -lt 3) { continue }
    if ($parts[0] -ne $projectId) { continue }
    $entries += @{ Rel = $parts[1]; Hash = $parts[2].ToLowerInvariant() }
}

if ($entries.Count -eq 0) {
    [Console]::Error.WriteLine('Uninstall refused: manifest contains no project entries')
    exit 1
}

# ---- Verify ALL paths and hashes before deleting anything ----
$failures = @()
foreach ($e in $entries) {
    $dest = Join-Path $TargetRoot ($e.Rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
        $failures += "missing installed file: $($e.Rel)"
        continue
    }
    $cur = Get-Sha256 $dest
    if ($cur -ne $e.Hash) {
        $failures += "installed file modified by user: $($e.Rel)"
        continue
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine('Uninstall aborted with zero deletes:')
    foreach ($f in $failures) { [Console]::Error.WriteLine("- $f") }
    exit 1
}

# ---- Delete only manifest-proven, unmodified project files ----
foreach ($e in $entries) {
    $dest = Join-Path $TargetRoot ($e.Rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    Remove-Item -LiteralPath $dest -Force
}

# Remove directories only when empty (no recursive delete of user content)
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
