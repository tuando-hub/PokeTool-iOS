#!/bin/bash
set -euo pipefail
out="${1:?output directory}"; mkdir -p "$out"
device=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')
test -n "$device"; xcrun simctl boot "$device" 2>/dev/null || true; xcrun simctl bootstatus "$device" -b
xcodebuild -project PokeTool.xcodeproj -scheme PokeTool -configuration Debug -sdk iphonesimulator -destination "id=$device" CODE_SIGNING_ALLOWED=NO build -quiet
app=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug-iphonesimulator/PokeTool.app' -print -quit); test -d "$app"; bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist"); xcrun simctl install "$device" "$app"
states=(dashboardIdle modeSelection taskInput dashboardRunning dashboardSuccess dashboardError dashboardStopped resultsHistory phoneOtpSettings phoneOtpWaiting smokeTests smokeTestResult pokemonFlow jumpplusFlow jumpcsFlow threeDSWaiting)
names=(01-dashboard-idle 02-mode-selection 03-task-input 04-dashboard-running 05-dashboard-success 06-dashboard-error 07-dashboard-stopped 08-results-history 09-phone-otp-settings 10-phone-otp-waiting 11-smoke-tests 12-smoke-test-result 13-pokemon-flow 14-jumpplus-flow 15-jumpcs-flow 16-3ds-waiting)
for i in "${!states[@]}"; do xcrun simctl launch --terminate-running-process "$device" "$bundle" -uiTesting -screenshotState "${states[$i]}" >/dev/null; sleep 2; xcrun simctl io "$device" screenshot "$out/${names[$i]}.png"; done
if command -v montage >/dev/null 2>&1; then montage "$out"/*.png -thumbnail 300x -tile 4x4 -geometry +12+36 "$out/PokeTool-UI-Overview.png"; else cp "$out/01-dashboard-idle.png" "$out/PokeTool-UI-Overview.png"; fi
printf 'Commit: %s\nSimulator: %s\nAll screenshots are real iOS Simulator captures using fake fixture data.\n' "${GITHUB_SHA:-local}" "$device" > "$out/README.txt"
