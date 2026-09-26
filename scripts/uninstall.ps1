param(
    [string]$TargetRoot = (Join-Path $HOME '.claude')
)

$ErrorActionPreference = 'Stop'
$agentNames = @(
    'premise-overturner.md',
    'assumption-challenger.md',
    'test-designer.md',
    'metric-gate.md',
    'rollback-planner.md',
    'range-creep-guardian.md'
)
$skillNames = @('three-review', 'six-role-drill')

foreach ($name in $agentNames) {
    $target = Join-Path (Join-Path $TargetRoot 'agents') $name
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        Remove-Item -LiteralPath $target -Force
    }
}

foreach ($name in $skillNames) {
    $target = Join-Path (Join-Path $TargetRoot 'skills') $name
    if (Test-Path -LiteralPath $target -PathType Container) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

Write-Output "Removed only this project's 6 agents and 2 skills from $TargetRoot"
