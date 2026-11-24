import "dart:js_interop";
import "dart:typed_data";

/// All three are defined by web/pdf-bridge.js, which loads pdf.js on first use.
@JS("studyDeskPdfOpen")
external JSPromise<JSNumber> _open(JSUint8Array bytes);

@JS("studyDeskPdfRender")
external JSPromise<JSUint8Array> _render(JSNumber index, JSNumber width);

@JS("studyDeskPdfClose")
external JSPromise<JSAny?> _close();

@JS("studyDeskPdfOpen")
external JSAny? get _bridge;

/// False if the bridge script is missing from the page — an old copy of the
/// app still in someone's browser cache, say. Better to say so than to throw.
bool get canReadPdfHere => _bridge != null;

/// How many pages this PDF has. 0 if it cannot be opened at all.
Future<int> openPdf(Uint8List bytes) async {
  if (_bridge == null) return 0;
  try {
    final n = await _open(bytes.toJS).toDart;
    return n.toDartInt;
  } catch (_) {
    return 0;
  }
}

/// One page as JPEG bytes, or null if that page would not draw.
///
/// Never throws: a page that will not render is a thing to explain to a
/// parent, not an error to lose a whole chapter over.
Future<Uint8List?> renderPdfPage(int index, {int width = 1400}) async {
  if (_bridge == null) return null;
  try {
    final out = await _render(index.toJS, width.toJS).toDart;
    final jpeg = out.toDart;
    return jpeg.isEmpty ? null : jpeg;
  } catch (_) {
    return null;
  }
}

/// Let the PDF go. Forty rendered pages is a lot of memory to leave behind.
Future<void> closePdf() async {
  if (_bridge == null) return;
  try {
    await _close().toDart;
  } catch (_) {
    // already gone
  }
}
