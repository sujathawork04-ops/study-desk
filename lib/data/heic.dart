// Turning an iPhone HEIC photo into a JPEG.
//
// Only the browser build can do this — it borrows a WebAssembly decoder from
// the page (see web/heic-bridge.js). On a phone there is nothing to do: the
// camera and the picker both hand over JPEGs already, so the stub simply says
// "I can't", and the caller shows the parent how to convert it by hand.
export "heic_stub.dart" if (dart.library.js_interop) "heic_web.dart";
