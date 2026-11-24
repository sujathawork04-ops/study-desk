// Handing a file to the person using the app.
//
// Only the browser can really save one without another package; on a phone the
// text goes to the clipboard instead, which is enough to paste into a note or
// an email. Either way the archive leaves the app, which is the whole point.
export "save_file_stub.dart" if (dart.library.js_interop) "save_file_web.dart";
