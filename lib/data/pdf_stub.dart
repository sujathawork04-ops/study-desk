import "dart:typed_data";

/// No PDF reader on this platform.
bool get canReadPdfHere => false;

Future<int> openPdf(Uint8List bytes) async => 0;
Future<Uint8List?> renderPdfPage(int index, {int width = 1400}) async => null;
Future<void> closePdf() async {}
