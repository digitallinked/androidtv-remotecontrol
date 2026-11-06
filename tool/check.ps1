# Format check, static analysis and tests for the whole workspace.
$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param([string]$Dir, [string]$Exe, [string[]]$StepArgs)
    Push-Location (Join-Path (Join-Path $PSScriptRoot '..') $Dir)
    try {
        & $Exe @StepArgs
        if ($LASTEXITCODE -ne 0) { throw "$Exe $($StepArgs -join ' ') failed in $Dir" }
    } finally {
        Pop-Location
    }
}

Invoke-Step . flutter @('pub', 'get')

Write-Host '== format =='
Invoke-Step . dart @('format', '--output=none', '--set-exit-if-changed', 'app/lib', 'app/test', 'app/integration_test', 'app/tool', 'packages/atv_remote/lib', 'packages/atv_remote/test', 'packages/atv_remote/bin')

Write-Host '== analyze =='
Invoke-Step app flutter @('analyze')
Invoke-Step packages/atv_remote dart @('analyze', '--fatal-infos')

Write-Host '== test =='
Invoke-Step app flutter @('test', '--exclude-tags', 'gradle')
# Gradle dry runs, on their own so no Gradle process overlaps the other tests.
Invoke-Step app flutter @('test', '--tags', 'gradle')
# 'dart test' cannot resolve the workspace (app needs the Flutter SDK), so use flutter test.
Invoke-Step packages/atv_remote flutter @('test')

Write-Host 'All checks passed.'
