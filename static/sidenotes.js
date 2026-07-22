/* sidenotes.js — promote Blogatto's native footnotes into the right margin on
   wide viewports. Progressive enhancement: without this script (or on narrow
   screens) the footnotes stay in their normal <section class="footnotes"> list
   at the foot of the article.

   Blogatto markup this relies on:
     ref:  <sup><a id="fnref-N" href="#fn-N">N</a></sup>
     defs: <section class="footnotes"><ol><li id="fn-N"> … <a class="footnote-backref">↩</a></li></ol></section>
*/
(function () {
  "use strict";

  var WIDE = window.matchMedia("(min-width: 76rem)");
  var GAP = 12; // px minimum vertical gap between stacked sidenotes

  function collectDefs(article) {
    var defs = {};
    article.querySelectorAll(".footnotes li[id^='fn-']").forEach(function (li) {
      var n = li.id.slice(3); // strip "fn-"
      var clone = li.cloneNode(true);
      var back = clone.querySelector(".footnote-backref");
      if (back) back.remove();
      defs[n] = clone.innerHTML.trim();
    });
    return defs;
  }

  function build(article) {
    var defs = collectDefs(article);
    var refs = article.querySelectorAll("sup a[id^='fnref-']");
    var made = [];
    refs.forEach(function (ref) {
      var n = ref.id.slice(6); // strip "fnref-"
      if (!(n in defs)) return;
      var note = document.createElement("aside");
      note.className = "sidenote";
      note.innerHTML = '<span class="sidenote-num">' + n + "</span>" + defs[n];
      article.appendChild(note);
      made.push({ el: note, ref: ref });
    });
    return made;
  }

  function position(article, made) {
    var artTop = article.getBoundingClientRect().top + window.scrollY;
    var prevBottom = -Infinity;
    made.forEach(function (m) {
      var refTop = m.ref.getBoundingClientRect().top + window.scrollY;
      var top = refTop - artTop;
      if (top < prevBottom + GAP) top = prevBottom + GAP;
      m.el.style.top = top + "px";
      prevBottom = top + m.el.offsetHeight;
    });
  }

  function clear(article) {
    article.querySelectorAll(".sidenote").forEach(function (s) {
      s.remove();
    });
  }

  function apply() {
    var article = document.querySelector("article");
    if (!article) return;
    clear(article);
    if (!WIDE.matches) {
      document.body.classList.remove("has-sidenotes");
      return;
    }
    var made = build(article);
    if (made.length) {
      document.body.classList.add("has-sidenotes");
      position(article, made); // measure/place after the class is applied
    } else {
      document.body.classList.remove("has-sidenotes");
    }
  }

  var timer;
  function debounced() {
    clearTimeout(timer);
    timer = setTimeout(apply, 150);
  }

  if (document.readyState !== "loading") apply();
  else document.addEventListener("DOMContentLoaded", apply);
  window.addEventListener("load", apply); // re-place once fonts/images settle
  window.addEventListener("resize", debounced);
})();
