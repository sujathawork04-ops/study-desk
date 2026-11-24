// Reading a scanned chapter that arrived as a PDF.
//
// Only the browser build can do this — it borrows pdf.js from the page (see
// web/pdf-bridge.js) and draws each page as a picture, because pictures are
// all Teacher knows how to look at. On a phone there is no such reader, so the
// stub says "I can't" and the parent is told to use the browser or the camera.
export "pdf_stub.dart" if (dart.library.js_interop) "pdf_web.dart";
