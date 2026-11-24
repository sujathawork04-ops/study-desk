// Reading a scanned book that arrived as a PDF.
//
// A parent who scans a chapter on a printer or a phone app gets ONE pdf, not
// twelve photographs. Teacher only knows how to look at pictures, so this
// turns each page of that pdf into a picture, in the page, before anything is
// uploaded. Nothing is sent anywhere to do it.
//
// pdf.js (Apache 2.0, Mozilla — vendored beside this file) does the rendering.
// It is a megabyte and a half with its worker, so it is NOT loaded with the
// app: this bridge fetches it the first time a pdf actually turns up. A family
// that only ever photographs pages never downloads it.
(function () {
  "use strict";

  var loading = null;
  var open = null;            // the pdf currently being read, one at a time

  function loadPdfjs() {
    if (window.pdfjsLib) return Promise.resolve();
    if (loading) return loading;
    loading = new Promise(function (resolve, reject) {
      var s = document.createElement("script");
      s.src = "pdfjs.min.js";
      s.onload = function () {
        try {
          // The worker does the parsing off the main thread, so the app does
          // not freeze while a forty-page chapter is read.
          window.pdfjsLib.GlobalWorkerOptions.workerSrc = "pdfjs.worker.min.js";
          resolve();
        } catch (e) {
          loading = null;
          reject(e);
        }
      };
      s.onerror = function () {
        loading = null;                       // let a later pdf try again
        reject(new Error("pdf-reader-unavailable"));
      };
      document.head.appendChild(s);
    });
    return loading;
  }

  /// Open a pdf and say how many pages are in it. Opening and rendering are
  /// two steps on purpose: the Dart side needs the count first, so it can tell
  /// a parent "reading page 3 of 12" instead of going quiet for a minute.
  window.studyDeskPdfOpen = async function (bytes) {
    await loadPdfjs();
    await window.studyDeskPdfClose();
    // A copy: pdf.js takes ownership of the buffer it is handed, and the
    // original belongs to Dart.
    var doc = await window.pdfjsLib.getDocument({
      data: new Uint8Array(bytes),
      // A scanned book is pictures of paper. None of this is wanted, and
      // refusing it is also what stops a stray pdf running anything here.
      disableFontFace: false,
      isEvalSupported: false,
    }).promise;
    open = doc;
    return doc.numPages;
  };

  /// One page, as JPEG bytes, at roughly the width asked for.
  window.studyDeskPdfRender = async function (index, width) {
    if (!open) throw new Error("no-pdf-open");
    var page = await open.getPage(index + 1);     // pdf.js counts from 1
    var natural = page.getViewport({ scale: 1 });
    // Small enough to upload, big enough to read small print in a textbook.
    var scale = Math.min(3, Math.max(0.5, width / natural.width));
    var viewport = page.getViewport({ scale: scale });

    var canvas = document.createElement("canvas");
    canvas.width = Math.ceil(viewport.width);
    canvas.height = Math.ceil(viewport.height);
    var ctx = canvas.getContext("2d");
    // A pdf page is transparent where there is no ink; a JPEG has no
    // transparency, so without this the paper comes out black.
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    await page.render({ canvasContext: ctx, viewport: viewport }).promise;

    var blob = await new Promise(function (resolve) {
      canvas.toBlob(resolve, "image/jpeg", 0.82);
    });
    page.cleanup();
    // Safari keeps big canvases alive until they are shrunk.
    canvas.width = 0;
    canvas.height = 0;
    if (!blob) throw new Error("page-not-drawn");
    return new Uint8Array(await blob.arrayBuffer());
  };

  /// Let go of the pdf. Forty rendered pages is a lot of memory to leave lying
  /// about on a laptop that is also running a browser full of tabs.
  window.studyDeskPdfClose = async function () {
    if (!open) return;
    var doc = open;
    open = null;
    try { await doc.destroy(); } catch (e) { /* already gone */ }
  };
})();
