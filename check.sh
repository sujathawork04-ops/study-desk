#!/bin/sh
# One command that runs every check and writes the result to check-output.txt,
# so the whole report can be read back without copying anything by hand.
#
#   cd ~/study-desk && sh check.sh
#
cd "$(dirname "$0")" || exit 1
OUT=check-output.txt

{
  echo "=== when ==="
  date
  echo
  echo "=== flutter version ==="
  flutter --version 2>&1
  echo
  echo "=== flutter pub get ==="
  flutter pub get 2>&1
  echo
  echo "=== flutter analyze ==="
  flutter analyze 2>&1
  echo
  echo "=== flutter test ==="
  flutter test 2>&1
  echo
  echo "=== done ==="
} > "$OUT" 2>&1

echo "Finished. Report written to $(pwd)/$OUT"
tail -20 "$OUT"
