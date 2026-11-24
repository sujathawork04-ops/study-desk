import "dart:typed_data";

/// No decoder on this platform. Phones hand over JPEGs already, so this is
/// only ever reached if a HEIC arrives some other way.
Future<Uint8List?> heicToJpeg(Uint8List bytes) async => null;
