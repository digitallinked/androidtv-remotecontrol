# Cold start, startup trace and battery measurements on an Android device
# (Ruling P8-R5). Raw output goes to build/measurements/<yyyyMMdd-HHmmss>-<mode>/
# and a summary is printed. Results belong in docs/knowledge/device-matrix.md;
# write down only what a run measured.
#
#   powershell -File tool/measure_android.ps1 -Mode startup [-Runs 10] [-Package com.digitallinked.atvremote.dev]
#   powershell -File tool/measure_android.ps1 -Mode trace
#   powershell -File tool/measure_android.ps1 -Mode battery [-Minutes 30]
#
# startup  Needs an installed profile build, from app/:
#            flutter build apk --profile --flavor dev -t lib/main_dev.dart
#            adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk
#          Each run force-stops the app, waits 2 s and starts it with
#          `am start -W`; prints every TotalTime and the median.
# trace    Runs `flutter run --profile --trace-startup` (it builds and installs
#          the profile build) and prints the time to the first frame.
# battery  Resets batterystats, waits -Minutes and saves the app's stats. Run
#          it twice: once with the remote open and connected (keep-awake on),
#          once as the baseline with the app force-stopped, screen on in both.
#
# With more than one device attached, set ANDROID_SERIAL to pick one.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('startup', 'trace', 'battery')]
    [string]$Mode,
    [ValidateRange(1, 1000)]
    [int]$Runs = 10,
    [ValidateRange(1, 1440)]
    [int]$Minutes = 30,
    [string]$Package = 'com.digitallinked.atvremote.dev'
)
$ErrorActionPreference = 'Stop'

$Activity = 'com.digitallinked.atvremote.MainActivity'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Fail([string]$Message) {
    [Console]::Error.WriteLine("measure_android: $Message")
    exit 1
}

function Find-Adb {
    $onPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $onPath) { return $onPath.Source }
    $roots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
    foreach ($root in $roots) {
        if (-not $root) { continue }
        $candidate = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    Fail 'adb not found. Put platform-tools on PATH or set ANDROID_HOME.'
}

# The serial of the one device to measure on; fails when there is none.
function Select-Device([string]$Adb) {
    $lines = & $Adb devices
    if ($LASTEXITCODE -ne 0) { Fail 'adb devices failed.' }
    $ready = @()
    $other = @()
    foreach ($line in $lines) {
        # "List of devices attached" has more than two words, so it never matches.
        if ($line -match '^(\S+)\s+(\S+)$') {
            if ($Matches[2] -eq 'device') { $ready += $Matches[1] } else { $other += "$($Matches[1]) ($($Matches[2]))" }
        }
    }
    if ($env:ANDROID_SERIAL) {
        if ($ready -contains $env:ANDROID_SERIAL) { return $env:ANDROID_SERIAL }
        Fail "No device attached: ANDROID_SERIAL=$($env:ANDROID_SERIAL) is not among the ready devices ($($ready -join ', '))."
    }
    if ($ready.Count -eq 0) {
        $detail = ''
        if ($other.Count -gt 0) { $detail = " Not ready: $($other -join ', ')." }
        Fail "No device attached. Connect a phone with USB debugging on (or start an emulator) and check 'adb devices'.$detail"
    }
    if ($ready.Count -gt 1) {
        Fail "More than one device attached ($($ready -join ', ')). Set ANDROID_SERIAL to the one to measure."
    }
    return $ready[0]
}

function New-OutputDir([string]$Name) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir = Join-Path $RepoRoot (Join-Path 'build\measurements' "$stamp-$Name")
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

function Get-Median([int[]]$Values) {
    $sorted = @($Values | Sort-Object)
    $n = $sorted.Count
    $mid = [int][math]::Floor($n / 2)
    if ($n % 2 -eq 1) { return [double]$sorted[$mid] }
    return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2
}

$adb = Find-Adb
$serial = Select-Device $adb
$model = (& $adb -s $serial shell getprop ro.product.model | Out-String).Trim()
$release = (& $adb -s $serial shell getprop ro.build.version.release | Out-String).Trim()
Write-Host "Device: $serial ($model, Android $release)"

switch ($Mode) {
    'startup' {
        $installed = (& $adb -s $serial shell pm path $Package | Out-String).Trim()
        if (-not $installed.StartsWith('package:')) {
            Fail "$Package is not installed on $serial. From app/: flutter build apk --profile --flavor dev -t lib/main_dev.dart, then adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk"
        }
        # Profile builds are debuggable too, so the flags can't tell them from a
        # debug build: installing the profile APK is up to the operator.
        $out = New-OutputDir 'startup'
        $times = @()
        for ($run = 1; $run -le $Runs; $run++) {
            & $adb -s $serial shell am force-stop $Package
            Start-Sleep -Seconds 2
            $result = & $adb -s $serial shell am start -W -n "$Package/$Activity" | Out-String
            Set-Content -Encoding utf8 -Path (Join-Path $out "run-$run.txt") -Value $result
            if ($result -notmatch 'TotalTime:\s*(\d+)') {
                Fail "Run $run printed no TotalTime (see $out\run-$run.txt)."
            }
            $times += [int]$Matches[1]
            Write-Host ("Run {0,2}: TotalTime {1} ms" -f $run, $Matches[1])
        }
        & $adb -s $serial shell am force-stop $Package
        $median = Get-Median $times
        $summary = "Cold start of $Package on $serial ($model, Android $release): median TotalTime $median ms over $Runs runs ($($times -join ', ') ms)"
        Set-Content -Encoding utf8 -Path (Join-Path $out 'summary.txt') -Value $summary
        Write-Host $summary
        Write-Host "Raw output: $out"
    }
    'trace' {
        $out = New-OutputDir 'trace'
        $appDir = Join-Path $RepoRoot 'app'
        $info = Join-Path $appDir 'build\start_up_info.json'
        if (Test-Path $info) { Remove-Item -Force $info }
        Push-Location $appDir
        try {
            # Tee-Object -FilePath writes UTF-16 in Windows PowerShell; keep the log UTF-8.
            & flutter run --profile --trace-startup --flavor dev -t lib/main_dev.dart -d $serial | Tee-Object -Variable runLog
            $code = $LASTEXITCODE
            Set-Content -Encoding utf8 -Path (Join-Path $out 'flutter_run.txt') -Value $runLog
            if ($code -ne 0) { Fail "flutter run failed (see $out\flutter_run.txt)." }
        } finally {
            Pop-Location
        }
        if (-not (Test-Path $info)) { Fail "flutter run wrote no $info." }
        Copy-Item $info (Join-Path $out 'start_up_info.json')
        $json = Get-Content -Raw $info | ConvertFrom-Json
        $summary = "Startup trace of $Package on $serial ($model, Android $release): timeToFirstFrameMicros $($json.timeToFirstFrameMicros), timeToFirstFrameRasterizedMicros $($json.timeToFirstFrameRasterizedMicros)"
        Set-Content -Encoding utf8 -Path (Join-Path $out 'summary.txt') -Value $summary
        Write-Host $summary
        Write-Host "Raw output: $out"
    }
    'battery' {
        $out = New-OutputDir 'battery'
        & $adb -s $serial shell dumpsys batterystats --reset | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail 'dumpsys batterystats --reset failed.' }
        Write-Host "Unplug, open the remote connected to the TV, leave it for $Minutes minutes."
        Write-Host '(For the baseline run: force-stop the app instead, screen on.) Plug back in before the time is up; the stats are read once the device is back.'
        for ($left = $Minutes; $left -gt 0; $left--) {
            Write-Host "  $left min left"
            Start-Sleep -Seconds 60
        }
        Write-Host 'Waiting for the device...'
        & $adb -s $serial wait-for-device
        $stats = & $adb -s $serial shell dumpsys batterystats --charged $Package | Out-String
        Set-Content -Encoding utf8 -Path (Join-Path $out 'batterystats.txt') -Value $stats
        $lines = $stats -split "`r?`n"
        $power = @()
        $inSection = $false
        foreach ($line in $lines) {
            if ($line -match 'Estimated power use') { $inSection = $true; $power += $line; continue }
            if ($inSection) {
                if ($line.Trim() -eq '') { $inSection = $false; continue }
                $power += $line
            }
        }
        if ($power.Count -eq 0) {
            Write-Warning "No 'Estimated power use' section in the stats (see $out\batterystats.txt). Was the device charging the whole time?"
        }
        Set-Content -Encoding utf8 -Path (Join-Path $out 'estimated_power_use.txt') -Value ($power -join "`n")
        Write-Host "Battery, $Minutes min, $Package on $serial ($model, Android $release):"
        $power | ForEach-Object { Write-Host $_ }
        Write-Host "Raw output: $out"
    }
}
