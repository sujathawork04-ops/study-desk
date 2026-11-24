/// No download on this platform — the caller falls back to the clipboard.
Future<bool> saveTextFile(String name, String text) async => false;
