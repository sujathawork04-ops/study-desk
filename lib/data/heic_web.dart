import "dart:js_interop";
import "dart:typed_data";

/// Defined by web/heic-bridge.js, which loads the decoder on first use.
@JS("studyDeskHeicToJpeg")
external JSPromise<JSUint8Array> _convert(JSUint8Array bytes);

@JS("studyDeskHeicToJpeg")
external JSAny? get _bridge;

/// JPEG bytes, or null if this photo could not be decoded.
///
/// Never throws: a photo that will not convert is a thing to explain to a
/// parent, not an error to crash a nine-year-old's homework on.
Future<Uint8List?> heicToJpeg(Uint8List bytes) async {
  if (_bridge == null) return null;        // bridge script missing from the page
  try {
    final out = await _convert(bytes.toJS).toDart;
    final jpeg = out.toDart;
    return jpeg.isEmpty ? null : jpeg;
  } catch (_) {
    return null;
  }
}
