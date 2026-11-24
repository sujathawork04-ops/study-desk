#!/bin/sh
# Build the Android app.
#
#   cd ~/study-desk && sh build-android.sh
#
# Produces an APK you can copy to a phone and install. Same two Supabase
# values as run.sh, read from the same .env — they are compiled INTO the app,
# so an APK built without them shows the "two values to pass in" screen.
#
# The Anthropic key is NOT in here and must never be: it lives only in the
# Supabase Edge Function secrets, so nothing on the phone can leak it.
cd "$(dirname "$0")" || exit 1

for f in "$PWD/.env"; do
  if [ -f "$f" ]; then ENV_FILE="$f"; break; fi
done
if [ -z "$ENV_FILE" ]; then
  echo "Couldn't find a .env with your Supabase details."
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

if [ -z "$VITE_SUPABASE_URL" ] || [ -z "$VITE_SUPABASE_ANON_KEY" ]; then
  echo "$ENV_FILE is missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY."
  exit 1
fi

echo "Using $ENV_FILE"
echo "Project: $VITE_SUPABASE_URL"
echo

flutter build apk --release \
  --dart-define=SUPABASE_URL="$VITE_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$VITE_SUPABASE_ANON_KEY" \
  --dart-define=FREE_MODE=true || exit 1

APK="build/app/outputs/flutter-apk/app-release.apk"
echo
if [ -f "$APK" ]; then
  echo "Built: $PWD/$APK"
  echo "Size:  $(du -h "$APK" | cut -f1)"
  echo
  echo "To put it on a phone plugged in by USB (with USB debugging on):"
  echo "    flutter install"
  echo "Or AirDrop / email / copy $APK to the phone and tap it to install."
else
  echo "The build finished but no APK was found at $APK"
fi
