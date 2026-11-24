import "dart:typed_data";

/// No general file chooser here — the caller uses the photo picker instead.
bool get canPickAnyFile => false;

Future<List<Uint8List>> pickFiles(String accept, {int limit = 40}) async =>
    const <Uint8List>[];
