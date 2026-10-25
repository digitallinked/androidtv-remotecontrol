# Regenerates packages/atv_remote/lib/src/proto from packages/atv_remote/proto/*.proto.
# Needs protoc (tool/bin/bin/protoc.exe or on PATH) and protoc-gen-dart on PATH:
#   dart pub global activate protoc_plugin 25.1.0
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..'
Push-Location $root
try {
    $protoc = 'protoc'
    $local = Join-Path $root 'tool/bin/bin/protoc.exe'
    if (Test-Path $local) { $protoc = $local }

    # Make sure the pub-global executables (protoc-gen-dart) are reachable.
    $env:PATH = "$env:PATH;$env:LOCALAPPDATA\Pub\Cache\bin;$env:USERPROFILE\.pub-cache\bin"

    $out = 'packages/atv_remote/lib/src/proto'
    New-Item -ItemType Directory -Force $out | Out-Null
    $protos = Get-ChildItem 'packages/atv_remote/proto' -Filter '*.proto' | ForEach-Object { "packages/atv_remote/proto/$($_.Name)" }
    & $protoc "--dart_out=$out" -Ipackages/atv_remote/proto @protos
    if ($LASTEXITCODE -ne 0) { throw 'protoc failed' }
    dart format $out
    if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
    Write-Host "Generated protobuf code in $out"
} finally {
    Pop-Location
}
