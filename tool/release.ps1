# Builds a prod store artifact, but only from a tree that passes every
# release check (Ruling P9-R2). It never signs with a key it creates, and
# never uploads anything.
#
#   powershell -File tool/release.ps1 -Platform android|ios [-DryRun] [-Root <dir>]
#
# 1. Pre-checks (app/tool/release_check.dart). On refusal nothing is built.
# 2. -DryRun stops here.
# 3. iOS store builds need a Mac.
# 4. Deletes the previous artifact, builds, then runs the post-checks.
param(
    [string]$Platform,
    [switch]$DryRun,
    [string]$Root
)
$ErrorActionPreference = 'Stop'

$usage = 'Usage: tool/release.ps1 -Platform android|ios [-DryRun] [-Root <dir>]'
if ($Platform) { $Platform = $Platform.ToLowerInvariant() }
if ($Platform -ne 'android' -and $Platform -ne 'ios') {
    [Console]::Error.WriteLine($usage)
    exit 64
}
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    [Console]::Error.WriteLine("No such directory: $Root")
    [Console]::Error.WriteLine($usage)
    exit 64
}
$Root = (Resolve-Path -LiteralPath $Root).Path
$checker = Join-Path $PSScriptRoot '..\app\tool\release_check.dart'

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    Write-Output 'dart is not on the PATH, so the release checks could not run. No build was made.'
    exit 1
}

# 1. Pre-checks.
& dart $checker --platform $Platform --stage pre --root $Root
$code = $LASTEXITCODE
if ($code -eq 64) { exit 64 }
if ($code -ne 0) {
    Write-Output 'No build was made.'
    exit 1
}

# 2. Dry run.
if ($DryRun) {
    Write-Output 'Dry run: every pre-build check passed. No build was made.'
    exit 0
}

# 3. iOS needs a Mac. Windows PowerShell 5.1 has no $IsMacOS; PowerShell 7 does.
$onMac = [bool](Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue)
if ($Platform -eq 'ios' -and -not $onMac) {
    Write-Output 'iOS store builds need a Mac (flutter build ipa).'
    exit 1
}

# 4. Delete the previous artifact so the post-check can't pass on a stale file.
$appDir = Join-Path $Root 'app'
$aab = Join-Path $appDir 'build\app\outputs\bundle\prodRelease\app-prod-release.aab'
$ipaDir = Join-Path $appDir 'build\ios\ipa'
if ($Platform -eq 'android') {
    if (Test-Path -LiteralPath $aab) { Remove-Item -LiteralPath $aab -Force }
} elseif (Test-Path -LiteralPath $ipaDir) {
    Get-ChildItem -LiteralPath $ipaDir -Filter '*.ipa' | Remove-Item -Force
}

# 5. Build, then post-check.
$kind = 'appbundle'
if ($Platform -eq 'ios') {
    $kind = 'ipa'
    # Ruling P9-C4: under Swift Package Manager, firebase_analytics links
    # Analytics without the advertising id only when this is set while
    # packages resolve (the Podfile switch covers CocoaPods only).
    $env:FIREBASE_ANALYTICS_WITHOUT_ADID = 'true'
}
Push-Location $appDir
try {
    # A build can package stale Dart while reporting success (learnings), and
    # nothing later would notice: the artifact has to come from a clean tree.
    & flutter clean
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        & flutter build $kind --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json
        $code = $LASTEXITCODE
    }
} finally {
    Pop-Location
}
if ($code -ne 0) {
    Write-Output "flutter build $kind failed (exit $code). No upload artifact was made."
    exit 1
}

$artifact = $aab
if ($Platform -eq 'ios') {
    $newest = Get-ChildItem -LiteralPath $ipaDir -Filter '*.ipa' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $artifact = Join-Path $ipaDir '*.ipa'
    if ($newest) { $artifact = $newest.FullName }
}

& dart $checker --platform $Platform --stage post --root $Root
if ($LASTEXITCODE -ne 0) {
    Write-Output "Do not upload $artifact."
    exit 1
}

# 6. Report.
$file = Get-Item -LiteralPath $artifact
$hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
$version = '?'
$line = Select-String -LiteralPath (Join-Path $appDir 'pubspec.yaml') -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if ($line) { $version = $line.Matches[0].Groups[1].Value }
Write-Output "Built $artifact"
Write-Output ('Size: {0:N1} MB ({1} bytes)' -f ($file.Length / 1MB), $file.Length)
Write-Output "SHA-256: $hash"
Write-Output "Version: $version"
Write-Output 'Next: upload it to the internal test track (docs/release/runbook.md).'
exit 0
