// Everything that changes between installations. Pass at build time:
//
//   flutter run \
//     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<your-anon-publishable-key> \
//     --dart-define=FREE_MODE=true
//
// The Anthropic key is NOT here and never reaches the phone — it lives in the
// Supabase Edge Function secrets, exactly as in the web app.
class Config {
  /// Bumped whenever the app changes, and shown at the bottom of Settings —
  /// the quickest way to tell a fresh build from one the browser cached.
  static const build = "2026-11-26 · 62";

  static const supabaseUrl = String.fromEnvironment("SUPABASE_URL");
  static const supabaseAnonKey = String.fromEnvironment("SUPABASE_ANON_KEY");

  /// No payment screen at all — for your own family and for an NGO centre.
  static const freeMode =
      bool.fromEnvironment("FREE_MODE", defaultValue: true);

  static bool get ok =>
      supabaseUrl.startsWith("http") && supabaseAnonKey.length > 20;

  static String get functionsBase => "$supabaseUrl/functions/v1";
}
