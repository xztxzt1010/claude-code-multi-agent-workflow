# Isolation tests for install.ps1 / uninstall.ps1
# NEVER touches real ~/.claude — every case uses a unique temp TargetRoot.
param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$install = Join-Path $repoRoot 'scripts/install.ps1'
$uninstall = Join-Path $repoRoot 'scripts/uninstall.ps1'
$failCount = 0
$passCount = 0

function Assert-True($cond, $msg) {
    if ($cond) { Write-Output "  PASS  $msg"; $script:passCount++ }
    else { Write-Output "  FAIL  $msg"; $script:failCount++ }
}

function New-TempRoot {
    $p = Join-Path ([IO.Path]::GetTempPath()) ("mimo-inst-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $p | Out-Null
    return $p
}

function Remove-TempRootSafe($dir) {
    $resolved = [IO.Path]::GetFullPath($dir)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to delete outside temp: $resolved"
    }
    if ($resolved -eq $tempRoot) { throw "refusing to delete temp root" }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}

function Invoke-Script($path, $target) {
    if ($null -eq $target) {
        # call without -TargetRoot (Mandatory should reject)
        try {
            & $path *> $null
            return $LASTEXITCODE
        } catch {
            return 1
        }
    }
    & $path -TargetRoot $target *> $null
    return $LASTEXITCODE
}

function Write-Manifest($root, [string[]]$lines) {
    $dir = Join-Path $root '.claude-multi-agent-workflow'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'manifest.tsv') -Value $lines -Encoding ascii
}

Write-Output "=== PowerShell isolation tests ==="

# Case 1: empty target first install
$root = New-TempRoot
try {
    $code = Invoke-Script $install $root
    Assert-True ($code -eq 0) "case1 install exit 0 (got $code)"
    $agents = @(Get-ChildItem (Join-Path $root 'agents') -Filter *.md -ErrorAction SilentlyContinue)
    $skills = @('three-review','six-role-drill' | ForEach-Object { Join-Path $root "skills/$_/SKILL.md" } | Where-Object { Test-Path $_ })
    Assert-True ($agents.Count -eq 6) "case1 6 agents (got $($agents.Count))"
    Assert-True ($skills.Count -eq 2) "case1 2 skills (got $($skills.Count))"
    Assert-True (Test-Path (Join-Path $root '.claude-multi-agent-workflow/manifest.tsv')) "case1 manifest exists"
} finally { Remove-TempRootSafe $root }

# Case 2: idempotent reinstall without modification
$root = New-TempRoot
try {
    Invoke-Script $install $root | Out-Null
    $code = Invoke-Script $install $root
    Assert-True ($code -eq 0) "case2 idempotent reinstall exit 0 (got $code)"
} finally { Remove-TempRootSafe $root }

# Case 3: pre-existing same-name conflict without ownership -> fail, zero writes
$root = New-TempRoot
try {
    $conflict = Join-Path $root 'agents/premise-overturner.md'
    New-Item -ItemType Directory -Force -Path (Split-Path $conflict) | Out-Null
    Set-Content -LiteralPath $conflict -Value 'USER FILE NOT OURS'
    $code = Invoke-Script $install $root
    Assert-True ($code -ne 0) "case3 conflict install fails (got $code)"
    Assert-True ((Get-Content $conflict -Raw).Trim() -eq 'USER FILE NOT OURS') "case3 conflict file untouched"
    Assert-True (-not (Test-Path (Join-Path $root 'agents/assumption-challenger.md'))) "case3 zero partial writes"
    Assert-True (-not (Test-Path (Join-Path $root '.claude-multi-agent-workflow/manifest.tsv'))) "case3 no manifest"
} finally { Remove-TempRootSafe $root }

# Case 4: unrelated files preserved across install and uninstall
$root = New-TempRoot
try {
    $keep = Join-Path $root 'agents/my-personal-agent.md'
    $keepSkill = Join-Path $root 'skills/my-skill/notes.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path $keep), (Split-Path $keepSkill) | Out-Null
    Set-Content $keep 'keep me'
    Set-Content $keepSkill 'keep skill note'
    Invoke-Script $install $root | Out-Null
    Assert-True (Test-Path $keep) "case4 unrelated agent kept after install"
    Invoke-Script $uninstall $root | Out-Null
    Assert-True (Test-Path $keep) "case4 unrelated agent kept after uninstall"
    Assert-True (Test-Path $keepSkill) "case4 unrelated skill file kept after uninstall"
} finally { Remove-TempRootSafe $root }

# Case 5: user-modified installed file -> uninstall fails, zero deletes
$root = New-TempRoot
try {
    Invoke-Script $install $root | Out-Null
    $mod = Join-Path $root 'agents/test-designer.md'
    Add-Content $mod "`nuser edit"
    $code = Invoke-Script $uninstall $root
    Assert-True ($code -ne 0) "case5 modified uninstall fails (got $code)"
    Assert-True (Test-Path (Join-Path $root 'agents/premise-overturner.md')) "case5 other project files not deleted"
    Assert-True (Test-Path (Join-Path $root '.claude-multi-agent-workflow/manifest.tsv')) "case5 manifest still present"
} finally { Remove-TempRootSafe $root }

# Case 6: unmodified full uninstall removes project files and manifest, keeps unrelated
$root = New-TempRoot
try {
    $keep = Join-Path $root 'settings.local.json'
    Set-Content $keep '{}'
    Invoke-Script $install $root | Out-Null
    $code = Invoke-Script $uninstall $root
    Assert-True ($code -eq 0) "case6 clean uninstall exit 0 (got $code)"
    Assert-True (-not (Test-Path (Join-Path $root 'agents/premise-overturner.md'))) "case6 agent removed"
    Assert-True (-not (Test-Path (Join-Path $root 'skills/three-review/SKILL.md'))) "case6 skill removed"
    Assert-True (-not (Test-Path (Join-Path $root '.claude-multi-agent-workflow/manifest.tsv'))) "case6 manifest removed"
    Assert-True (Test-Path $keep) "case6 unrelated file kept"
} finally { Remove-TempRootSafe $root }

# Extra: uninstall without manifest refuses
$root = New-TempRoot
try {
    $code = Invoke-Script $uninstall $root
    Assert-True ($code -ne 0) "no-manifest uninstall refuses (got $code)"
} finally { Remove-TempRootSafe $root }

# Case 7: missing TargetRoot -> refuse, zero writes
$root = New-TempRoot
try {
    $code = Invoke-Script $install $null
    Assert-True ($code -ne 0) "case7 install without TargetRoot fails (got $code)"
    Assert-True (-not (Test-Path (Join-Path $root 'agents'))) "case7 zero writes without TargetRoot"
    $code = Invoke-Script $uninstall $null
    Assert-True ($code -ne 0) "case7 uninstall without TargetRoot fails (got $code)"
} finally { Remove-TempRootSafe $root }

# Case 8: manifest with ../ escape -> uninstall refuses, sentinel unchanged
$root = New-TempRoot
try {
    Invoke-Script $install $root | Out-Null
    $sentinel = Join-Path ([IO.Path]::GetTempPath()) ("mimo-sentinel-" + [Guid]::NewGuid().ToString('N') + ".txt")
    Set-Content $sentinel 'SENTINEL-KEEP'
    # craft evil manifest
    $evilRel = '../' + (Split-Path $sentinel -Leaf)
    $lines = @('# claude-code-multi-agent-workflow manifest v1', "# project`trelpath`tsha256")
    foreach ($r in @('agents/premise-overturner.md','agents/assumption-challenger.md','agents/test-designer.md','agents/metric-gate.md','agents/rollback-planner.md','agents/range-creep-guardian.md','skills/three-review/SKILL.md')) {
        $lines += "claude-code-multi-agent-workflow`t$r`t$('a'*64)"
    }
    $lines += "claude-code-multi-agent-workflow`t$evilRel`t$('b'*64)"
    Write-Manifest $root $lines
    $code = Invoke-Script $uninstall $root
    Assert-True ($code -ne 0) "case8 ../ manifest uninstall fails (got $code)"
    Assert-True ((Get-Content $sentinel -Raw).Trim() -eq 'SENTINEL-KEEP') "case8 sentinel outside root unchanged"
    Assert-True (Test-Path (Join-Path $root 'agents/premise-overturner.md')) "case8 project files not deleted"
    Remove-Item $sentinel -Force
} finally { Remove-TempRootSafe $root }

# Case 9: absolute path in manifest -> refuse
$root = New-TempRoot
try {
    Invoke-Script $install $root | Out-Null
    $lines = @('# claude-code-multi-agent-workflow manifest v1', "# project`trelpath`tsha256")
    foreach ($r in @('agents/premise-overturner.md','agents/assumption-challenger.md','agents/test-designer.md','agents/metric-gate.md','agents/rollback-planner.md','agents/range-creep-guardian.md','skills/three-review/SKILL.md','skills/six-role-drill/SKILL.md')) {
        $rel = if ($r -eq 'skills/six-role-drill/SKILL.md') { '/etc/passwd' } else { $r }
        $lines += "claude-code-multi-agent-workflow`t$rel`t$('c'*64)"
    }
    Write-Manifest $root $lines
    $code = Invoke-Script $uninstall $root
    Assert-True ($code -ne 0) "case9 absolute-path manifest fails (got $code)"
    Assert-True (Test-Path (Join-Path $root 'agents/premise-overturner.md')) "case9 zero deletes"
} finally { Remove-TempRootSafe $root }

# Case 10: extra / missing / duplicate / malformed manifests all refuse
foreach ($kind in @('extra','missing','duplicate','malformed')) {
    $root = New-TempRoot
    try {
        Invoke-Script $install $root | Out-Null
        $base = @('agents/premise-overturner.md','agents/assumption-challenger.md','agents/test-designer.md','agents/metric-gate.md','agents/rollback-planner.md','agents/range-creep-guardian.md','skills/three-review/SKILL.md','skills/six-role-drill/SKILL.md')
        $rels = switch ($kind) {
            'extra' { $base + @('agents/evil.md') }
            'missing' { $base | Select-Object -First 7 }
            'duplicate' { $base + @('agents/premise-overturner.md') }
            'malformed' { $base }
        }
        $lines = @('# claude-code-multi-agent-workflow manifest v1', "# project`trelpath`tsha256")
        foreach ($r in $rels) {
            if ($kind -eq 'malformed') { $lines += "claude-code-multi-agent-workflow`t$r" }
            else { $lines += "claude-code-multi-agent-workflow`t$r`t$('d'*64)" }
        }
        Write-Manifest $root $lines
        $code = Invoke-Script $uninstall $root
        Assert-True ($code -ne 0) "case10 $kind manifest fails (got $code)"
        Assert-True (Test-Path (Join-Path $root 'agents/premise-overturner.md')) "case10 $kind zero deletes"
    } finally { Remove-TempRootSafe $root }
}

Write-Output "=== result: $passCount passed, $failCount failed ==="
if ($failCount -gt 0) { exit 1 }
exit 0
