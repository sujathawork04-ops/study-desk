#!/bin/sh
# Build Study Desk as a website you can host.
#
#   cd ~/study-desk && sh build-web.sh
#
# Produces build/web — a folder of plain files. Drag that folder onto
# app.netlify.com/drop (or Cloudflare Pages) and you get a link to send.
# Anyone with the link opens it in a browser; on a phone, "Add to Home Screen"
# makes it look and behave like an installed app.
#
# Same two Supabase values as run.sh, compiled in. The Anthropic key is NOT
# here and must never be: it lives only in the Supabase Edge Function secrets,
# so nothing in this folder can leak it even though the folder is public.
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

flutter build web --release \
  --dart-define=SUPABASE_URL="$VITE_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$VITE_SUPABASE_ANON_KEY" \
  --dart-define=FREE_MODE=true || exit 1

# THERE ARE TWO FOLDERS CALLED "web" IN THIS PROJECT, and dragging the wrong
# one puts a blank white page online with no error to explain it. The one at
# the top of the project is the source; the app itself is only ever in
# build/web. Rather than describe the difference and hope, this checks that the
# built app is really there and then opens Finder with the right folder already
# highlighted, so the one to drag is the one that is selected.
if [ ! -f build/web/flutter_bootstrap.js ] || [ ! -f build/web/main.dart.js ]; then
  echo "build/web has no app in it — don't upload it. Run this script again."
  exit 1
fi

echo
echo "Built: $PWD/build/web"
echo "Size:  $(du -sh build/web | cut -f1)"
echo
echo "To put it online, free:"
echo "  1. Open  https://app.netlify.com/drop"
echo "  2. Drag the folder highlighted in Finder (build > web) onto the page."
echo "     NOT the 'web' folder at the top of the project — that one is the"
echo "     source, and uploading it gives a blank white page."
echo "  3. You get a link. Send that."

command -v open >/dev/null 2>&1 && open -R build/web
echo
echo "Before you send it to anyone, turn OFF open sign-ups in Supabase:"
echo "  Authentication -> Sign In / Providers -> 'Allow new users to sign up'"
echo "Otherwise anyone with the link can make an account on your project,"
echo "and every message they send is billed to you."
