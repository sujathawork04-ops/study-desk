// Choosing a file in the browser.
//
// The app's photo picker is exactly that — a photo picker — so in a Finder
// window every pdf is greyed out and cannot be chosen at all. A parent who
// scanned her child's textbook has pdfs and nothing else, so the browser build
// opens a plain file chooser that accepts both.
//
// Nothing is uploaded here. The bytes are read in the page and handed to Dart,
// which is the same route a photograph already takes.
(function () {
  "use strict";

  /// Up to `limit` files, as byte arrays. An empty array means the parent
  /// pressed Cancel — which must resolve, not hang: a promise that never
  /// settles leaves the button spinning forever.
  window.studyDeskPickFiles = function (accept, limit) {
    return new Promise(function (resolve) {
      var input = document.createElement("input");
      input.type = "file";
      input.accept = accept;
      input.multiple = true;
      input.style.position = "fixed";
      input.style.left = "-9999px";          // present, but never seen
      document.body.appendChild(input);

      var done = false;
      function finish(files) {
        if (done) return;
        done = true;
        window.removeEventListener("focus", onFocus, true);
        if (input.parentNode) input.parentNode.removeChild(input);
        resolve(files);
      }

      input.addEventListener("change", async function () {
        var chosen = Array.prototype.slice.call(input.files || [], 0, limit);
        var out = [];
        for (var i = 0; i < chosen.length; i++) {
          out.push(new Uint8Array(await chosen[i].arrayBuffer()));
        }
        finish(out);
      });

      // Cancel. Chrome and Safari fire this event; the focus check below is
      // the backstop for a browser that does not.
      input.addEventListener("cancel", function () { finish([]); });

      function onFocus() {
        // The change event lands after focus returns, so give it a moment
        // before deciding nothing was chosen.
        setTimeout(function () {
          if (!input.files || input.files.length === 0) finish([]);
        }, 800);
      }
      window.addEventListener("focus", onFocus, true);

      input.click();
    });
  };
})();
