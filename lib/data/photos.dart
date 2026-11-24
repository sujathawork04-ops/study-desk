// One gate every picked photo goes through, so the four places that take a
// photo all behave the same way.
import "dart:typed_data";

import "../rules.dart";
import "heic.dart";

/// A photo ready to use, or the reason it cannot be.
typedef ReadyPhoto = ({Uint8List bytes, String problem, bool converted});

/// Make a picked file usable if it can be made usable.
///
/// A JPEG or PNG passes straight through. An iPhone HEIC — including one
/// renamed to .jpg, which changes the name and nothing else — is decoded to a
/// JPEG here, so a parent who photographed the diary on a phone and carried it
/// to the Mac never has to know what HEIC is. Only when even that fails does
/// anyone get told to convert it by hand.
Future<ReadyPhoto> readyPhoto(Uint8List raw) async {
  if (isPhotoBytesUsable(raw)) {
    return (bytes: raw, problem: "", converted: false);
  }
  if (photoKind(raw) != "heic") {
    return (bytes: raw, problem: kOddFileAdvice, converted: false);
  }

  final jpeg = await heicToJpeg(raw);
  if (jpeg == null || !isPhotoBytesUsable(jpeg)) {
    return (bytes: raw, problem: kHeicAdvice, converted: false);
  }
  return (bytes: jpeg, problem: "", converted: true);
}

/// Shown while the decoder is fetched and run — it takes a second or two on a
/// big photo, and silence looks like a frozen app.
const kConvertingPhoto = "Changing your iPhone photo into one I can read…";
