# OneSource Connect: one-command setup and run on Windows with an Android emulator.
#   powershell -ExecutionPolicy Bypass -File tool\run_windows.ps1            (demo agent ERP)
#   powershell -ExecutionPolicy Bypass -File tool\run_windows.ps1 demopartner
# Safe to run again: every step skips what is already done. Output is also saved to C:\OneSourceMobile-run-log.txt.
param([string]$Target = "demoagent")
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
Start-Transcript -Path "C:\OneSourceMobile-run-log.txt" -Force | Out-Null

function Step($t) { Write-Host "`n==== $t ====" -ForegroundColor Cyan }

# ---- Android SDK at a path without spaces (Flutter warns about "C:\Users\First Last\...") --------------------
Step "Android SDK"
$realSdk = "$env:LOCALAPPDATA\Android\Sdk"
$sdk = $realSdk
if ($realSdk -match " ") {
  $sdk = "C:\Android\Sdk"
  if (-not (Test-Path $sdk)) {
    New-Item -ItemType Directory -Force C:\Android | Out-Null
    cmd /c mklink /J "$sdk" "$realSdk" | Out-Null   # a junction: same files, path without spaces
  }
}
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$jbr = "C:\Program Files\Android\Android Studio\jbr"
if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
flutter config --android-sdk "$sdk" | Out-Null
Write-Host "SDK: $sdk"

# ---- Emulator with a standard x86_64 image ---------------------------------------------------------------------
Step "Emulator"
$tools = "$sdk\cmdline-tools\latest\bin"
$image = "system-images;android-35;google_apis;x86_64"
$avd = "onesource_pixel"
if (-not (Test-Path "$sdk\system-images\android-35\google_apis\x86_64")) {
  Write-Host "Downloading Android 35 emulator image (about 1.5 GB, once)..."
  ("y`n" * 50) | & "$tools\sdkmanager.bat" "platforms;android-35" "platform-tools" "emulator" $image
}
$avds = & "$sdk\emulator\emulator.exe" -list-avds
if ($avds -notcontains $avd) {
  "no" | & "$tools\avdmanager.bat" create avd -n $avd -k $image -d pixel_7 --force
}
$adb = "$sdk\platform-tools\adb.exe"

# Returns the id of a booted emulator (e.g. emulator-5554), starting or restarting the AVD when needed.
function Find-Booted {
  foreach ($line in (& $adb devices)) { if ($line -match '^(emulator-\d+)\s+device\s*$') { return $Matches[1] } }
  return $null
}
function Get-Emulator {
  & $adb start-server | Out-Null
  $id = Find-Booted
  if (-not $id) {
    # an emulator that is listed as offline will not take an install: restart it
    foreach ($line in (& $adb devices)) { if ($line -match '^(emulator-\d+)\s+offline') { & $adb -s $Matches[1] emu kill 2>$null | Out-Null } }
    Write-Host "Starting emulator $avd ..."
    Start-Process "$sdk\emulator\emulator.exe" -ArgumentList "-avd $avd -netdelay none -netspeed full"
    & $adb wait-for-device
    $id = Find-Booted
  }
  if (-not $id) { return $null }
  $tries = 0
  while (((& $adb -s $id shell getprop sys.boot_completed) -join "").Trim() -ne "1" -and $tries -lt 120) { Start-Sleep -Seconds 2; $tries++ }
  return $id
}
$null = Get-Emulator
Write-Host "Emulator ready."

# ---- App code -----------------------------------------------------------------------------------------------
Step "Code"
git pull
if (-not (Test-Path "android\app\build.gradle.kts") -and -not (Test-Path "android\app\build.gradle")) {
  flutter create --platforms=android,ios --org qa.onesource --project-name onesource_connect .
}
Remove-Item test\widget_test.dart -ErrorAction SilentlyContinue
python tool\configure_platforms.py
flutter pub get
dart run flutter_launcher_icons
# real Doha photograph for the sign-in and home screens (see assets/photos/CREDITS.md); the app draws the skyline without it
if (-not (Test-Path "assets\photos\doha.jpg")) {
  try {
    Invoke-WebRequest -UseBasicParsing -UserAgent "OneSourceConnect-build/1.0" -OutFile "assets\photos\doha.jpg" `
      -Uri "https://commons.wikimedia.org/wiki/Special:FilePath/DohaSkylineAtNight.jpg?width=1200"
    Write-Host "Doha photo downloaded."
  } catch { Remove-Item "assets\photos\doha.jpg" -ErrorAction SilentlyContinue; Write-Host "Photo not downloaded; the app will draw the skyline." -ForegroundColor Yellow }
}
if (-not (Test-Path "config\$Target.local.json")) { Copy-Item "config\$Target.example.json" "config\$Target.local.json" }

Step "Analyze"
flutter analyze --no-fatal-infos
Step "Tests"
flutter test

Stop-Transcript | Out-Null
Step "Run (press r to reload, q to quit)"
$device = Get-Emulator
if (-not $device) { Write-Host "The emulator did not start. Open Android Studio > Device Manager, start onesource_pixel, then run this script again." -ForegroundColor Red; exit 1 }
# remove the old build so the phone can never keep showing a previous version
& $adb -s $device uninstall qa.onesource.onesource_connect 2>$null | Out-Null
Write-Host "Installing the new version on $device (first build takes a few minutes)..."
flutter run -d $device --dart-define-from-file="config\$Target.local.json"
