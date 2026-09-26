param(
    [string]$TargetRoot = (Join-Path $HOME '.claude')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$agentTarget = Join-Path $TargetRoot 'agents'
$skillTarget = Join-Path $TargetRoot 'skills'
$agentNames = @(
    'premise-overturner.md',
    'assumption-challenger.md',
    'test-designer.md',
    'metric-gate.md',
    'rollback-planner.md',
    'range-creep-guardian.md'
)
$skillNames = @('three-review', 'six-role-drill')

New-Item -ItemType Directory -Force -Path $agentTarget, $skillTarget | Out-Null

foreach ($name in $agentNames) {
    Copy-Item -LiteralPath (Join-Path $repoRoot "agents/$name") -Destination (Join-Path $agentTarget $name) -Force
}

foreach ($name in $skillNames) {
    $destination = Join-Path $skillTarget $name
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/$name/SKILL.md") -Destination (Join-Path $destination 'SKILL.md') -Force
}

Write-Output "Installed 6 agents and 2 skills into $TargetRoot"
