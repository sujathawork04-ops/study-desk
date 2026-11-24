// Hand the person a file to keep. Nothing is uploaded anywhere: the text is
// already in the page, and this only wraps it in a Blob the browser saves.
window.studyDeskSaveFile = function (name, text) {
  const blob = new Blob([text], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  // Let the download start before the blob is thrown away.
  setTimeout(() => URL.revokeObjectURL(url), 10000);
};
