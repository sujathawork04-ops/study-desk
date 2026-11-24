import "dart:js_interop";
import "dart:typed_data";

/// Defined by web/pick-file.js.
@JS("studyDeskPickFiles")
external JSPromise<JSArray<JSUint8Array>> _pick(JSString accept, JSNumber limit);

@JS("studyDeskPickFiles")
external JSAny? get _bridge;

bool get canPickAnyFile => _bridge != null;

/// The files the parent chose, as bytes. Empty means Cancel — and the bridge
/// guarantees Cancel resolves, so the button never spins forever.
///
/// Only bytes come back, no names: what a file IS is decided by what is inside
/// it, never by what it is called. A HEIC renamed to .jpg taught us that.
Future<List<Uint8List>> pickFiles(String accept, {int limit = 40}) async {
  if (_bridge == null) return const <Uint8List>[];
  try {
    final out = await _pick(accept.toJS, limit.toJS).toDart;
    return [for (final f in out.toDart) f.toDart];
  } catch (_) {
    return const <Uint8List>[];
  }
}
