import "dart:js_interop";

@JS("studyDeskSaveFile")
external void _save(JSString name, JSString text);

@JS("studyDeskSaveFile")
external JSAny? get _bridge;

/// Hand the browser a file to download. False if the page has no bridge, so
/// the caller can fall back to the clipboard rather than silently do nothing.
Future<bool> saveTextFile(String name, String text) async {
  if (_bridge == null) return false;
  try {
    _save(name.toJS, text.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
