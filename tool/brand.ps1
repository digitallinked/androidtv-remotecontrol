# Branding pipeline (Ruling P7-R6): renders the masters from our own painter,
# then regenerates the launcher icons and the native splash. Run from anywhere;
# stops at the first failing step. Commit the generated native files.
$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param([string]$Exe, [string[]]$StepArgs)
    & $Exe @StepArgs
    if ($LASTEXITCODE -ne 0) { throw "$Exe $($StepArgs -join ' ') failed" }
}

Push-Location (Join-Path (Join-Path $PSScriptRoot '..') 'app')
try {
    Write-Host '== masters =='
    # No tag filter: the untagged brand_mark_test.dart writes brand_icon.svg.
    Invoke-Step flutter @('test', '--update-goldens', 'test/branding')

    Write-Host '== launcher icons =='
    Invoke-Step flutter @('pub', 'run', 'flutter_launcher_icons', '-f', 'flutter_launcher_icons.yaml')
    # flutter_launcher_icons 0.14.4 sets every build setting whose name contains
    # ASSETCATALOG to the icon name, including this boolean; put it back.
    $pbx = (Resolve-Path 'ios/Runner.xcodeproj/project.pbxproj').Path
    $orig = [IO.File]::ReadAllText($pbx)
    $text = $orig.Replace('ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;', 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;')
    if ($text -cne $orig) { [IO.File]::WriteAllText($pbx, $text) }

    Write-Host '== native splash =='
    Invoke-Step flutter @('pub', 'run', 'flutter_native_splash:create', '--path=flutter_native_splash.yaml')
} finally {
    Pop-Location
}

Write-Host 'Branding generated.'
