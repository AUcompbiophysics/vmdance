// A link to another project's website asks before it leaves these pages:
// the reader is told where it goes, and can stay (Cancel). A click, Enter
// on the link, and a middle click (a new tab) ask alike.
(function () {
  "use strict";
  // the websites that ask, and what each one is
  var SITES = {
    "mdance.readthedocs.io": "MDANCE's documentation"
  };

  function ask(event) {
    if (event.type === "auxclick" && event.button !== 1) return;
    var a = event.target && event.target.closest ? event.target.closest("a[href]") : null;
    if (!a || !Object.prototype.hasOwnProperty.call(SITES, a.hostname)) return;
    var go = window.confirm(
      "You are leaving the VMDance documentation.\n\n" +
      "This link opens " + SITES[a.hostname] + " (" + a.hostname + "), " +
      "a different website.\n\nGo there?");
    if (!go) event.preventDefault();
  }

  document.addEventListener("click", ask);
  document.addEventListener("auxclick", ask);
})();
