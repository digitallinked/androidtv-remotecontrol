# Website screens: renders the real app (app/test/store_assets/web_screens_test.dart)
# into build/web-screens/*.png, then web/scripts/screens.mjs writes the WebP
# files the site shows to web/public/screens/. Commit only the WebP files.
# Run from anywhere; web/node_modules must be installed.
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path (Join-Path $root 'build') 'web-screens'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
$env:WEB_SCREENS_OUT = $out

Push-Location (Join-Path $root 'app')
try {
    & flutter @('test', 'test/store_assets/web_screens_test.dart')
    if ($LASTEXITCODE -ne 0) { throw 'The web screen generator failed.' }
} finally {
    Pop-Location
    Remove-Item Env:\WEB_SCREENS_OUT -ErrorAction SilentlyContinue
}

Push-Location (Join-Path $root 'web')
try {
    & node scripts/screens.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Converting the screens failed.' }
} finally {
    Pop-Location
}
