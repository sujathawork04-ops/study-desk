#!/bin/sh
# Run Study Desk in Chrome.
#
#   cd ~/study-desk && sh run.sh
#
# The app needs two values — your Supabase address and its anon (publishable)
# key — and they are passed in at BUILD time, not read from a file at runtime.
# Start it with a plain `flutter run` and you get the "Almost there — two
# values to pass in" screen, because the app was built without them.
#
# This script reads them from your .env and passes them through, so there is
# nothing to remember and nothing to paste.
#
# The Anthropic key is NOT here and must never be. It lives only in the
# Supabase Edge Function secrets.
cd "$(dirname "$0")" || exit 1

# Whichever .env exists — the Flutter folder first, the web app's as fallback.
for f in "$PWD/.env"; do
  if [ -f "$f" ]; then ENV_FILE="$f"; break; fi
done

if [ -z "$ENV_FILE" ]; then
  echo "Couldn't find a .env with your Supabase details."
  echo "Looked in: $PWD/.env — copy .env.example to .env and fill it in."
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

exec flutter run -d chrome \
  --dart-define=SUPABASE_URL="$VITE_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$VITE_SUPABASE_ANON_KEY" \
  --dart-define=FREE_MODE=true
