#!/bin/bash
set -euo pipefail
dir="${1:?screenshots directory}"
files=(01-dashboard-idle 02-mode-selection 03-task-input 04-dashboard-running 05-dashboard-success 06-dashboard-error 07-dashboard-stopped 08-results-history 09-phone-otp-settings 10-phone-otp-waiting 11-smoke-tests 12-smoke-test-result 13-pokemon-flow 14-jumpplus-flow 15-jumpcs-flow 16-3ds-waiting)
declare -A hashes=()
for base in "${files[@]}"; do f="$dir/$base.png"; test -s "$f"; test "$(stat -f%z "$f")" -gt 10240; file "$f" | grep -q 'PNG image'; read w h <<< "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w,h}')"; test "${w:-0}" -gt 0; test "${h:-0}" -gt 0; hash=$(shasum -a 256 "$f" | cut -d' ' -f1); hashes[$hash]=1; done
test "${#hashes[@]}" -gt 1
test -s "$dir/PokeTool-UI-Overview.png"
test -s "$dir/README.txt"
