// Turning an iPhone photo into one a browser can actually show.
//
// Chrome cannot decode HEIC at all — the format a modern iPhone saves by
// default — so a diary page photographed on a phone and carried to the Mac is
// unreadable here however it is renamed. heic2any (MIT, vendored beside this
// file) is a WebAssembly build of libheif that does the decoding in the page.
//
// It is over a megabyte, so it is NOT loaded with the app: this small bridge
// fetches it the first time an iPhone photo actually turns up, and never again
// after that. A family whose phone already saves JPEGs never downloads it.
(function () {
  "use strict";

  var loading = null;

  function loadDecoder() {
    if (window.heic2any) return Promise.resolve();
    if (loading) return loading;
    loading = new Promise(function (resolve, reject) {
      var s = document.createElement("script");
      s.src = "heic2any.min.js";
      s.onload = resolve;
      s.onerror = function () {
        loading = null;                       // let a later photo try again
        reject(new Error("decoder-unavailable"));
      };
      document.head.appendChild(s);
    });
    return loading;
  }

  /// Bytes in, JPEG bytes out. Throws if this photo cannot be decoded, which
  /// the Dart side turns into advice rather than an error message.
  window.studyDeskHeicToJpeg = async function (bytes) {
    await loadDecoder();
    var out = await window.heic2any({
      blob: new Blob([bytes], { type: "image/heic" }),
      toType: "image/jpeg",
      quality: 0.82,                          // a diary page, not a photograph
    });
    // A HEIC can hold a burst of images; the first one is the picture.
    var blob = Array.isArray(out) ? out[0] : out;
    return new Uint8Array(await blob.arrayBuffer());
  };
})();
