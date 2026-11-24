// Choosing a file rather than a photo.
//
// The photo picker greys out every PDF, which is the only thing a parent who
// scanned a textbook actually has. The browser can open a chooser that takes
// both; a phone cannot, and falls back to its camera roll.
export "pick_file_stub.dart" if (dart.library.js_interop) "pick_file_web.dart";
