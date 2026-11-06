# Store screenshot generator (Ruling P9-R14): renders every shot of
# app/test/store_assets/store_frame.dart in English and Malay, framed at the
# store sizes, into build/store-screenshots/<set>/<locale>/<id>.png.
# build/ is git-ignored: the PNGs are never committed. Run from anywhere.
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path (Join-Path $root 'build') 'store-screenshots'
# A fresh folder, so the generator's count of 40 sees no stale files.
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
$env:STORE_SCREENSHOTS_OUT = $out

Push-Location (Join-Path $root 'app')
try {
    $started = Get-Date
    & flutter @('test', 'test/store_assets/store_screenshots_test.dart')
    if ($LASTEXITCODE -ne 0) { throw 'The store screenshot generator failed.' }
    $seconds = [int]((Get-Date) - $started).TotalSeconds
} finally {
    Pop-Location
    Remove-Item Env:\STORE_SCREENSHOTS_OUT -ErrorAction SilentlyContinue
}

$count = @(Get-ChildItem -Path $out -Recurse -Filter '*.png').Count
Write-Host "Wrote $count store screenshots to $out in $seconds s."
