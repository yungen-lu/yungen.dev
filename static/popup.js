/* popup.js — gwern-style link popups. On hover over an internal link that has an
   annotation, float a small card with the target's title, byline, and abstract.

   Data comes from /metadata/annotations.json (written by sync, Layer C): a map of
   { "/route/": { title, byline, abstract } } keyed by the flat post route, which
   is exactly what internal links carry as their href — so matching is a lookup.

   Progressive enhancement: without JS, or on touch/coarse-pointer devices, links
   behave normally. Content is inserted as text (never innerHTML), so nothing in
   the map can inject markup. */
(function () {
  "use strict";

  // Hover-only: no popups on touch / coarse pointers (they'd hijack the tap).
  if (
    !window.matchMedia ||
    !window.matchMedia("(hover: hover) and (pointer: fine)").matches
  )
    return;

  var SPAWN_DELAY = 500; // ms hovering a link before it spawns
  var DESPAWN_DELAY = 200; // ms grace to cross the gap into the popup
  var GAP = 8; // px between link and popup
  var PAD = 8; // px minimum distance from the viewport edge
  var MAX_WIDTH = 420; // px popup width cap

  var annotations = null;
  var popup = null;
  var spawnTimer = null;
  var despawnTimer = null;

  fetch("/metadata/annotations.json")
    .then(function (r) {
      return r.ok ? r.json() : null;
    })
    .then(function (data) {
      if (!data) return;
      annotations = data;
      wireLinks();
    })
    .catch(function () {
      /* no annotations available — links stay plain */
    });

  function wireLinks() {
    var links = document.querySelectorAll("a[href]");
    [].forEach.call(links, function (link) {
      var href = link.getAttribute("href");
      if (!annotations.hasOwnProperty(href)) return;
      link.classList.add("link-annotated");
      link.addEventListener("mouseenter", function () {
        scheduleSpawn(link);
      });
      link.addEventListener("mouseleave", function () {
        cancelSpawn();
        scheduleDespawn();
      });
    });
  }

  function getPopup() {
    if (!popup) {
      popup = document.createElement("div");
      popup.className = "link-popup";
      popup.setAttribute("role", "tooltip");
      popup.addEventListener("mouseenter", cancelDespawn);
      popup.addEventListener("mouseleave", scheduleDespawn);
      document.body.appendChild(popup);
    }
    return popup;
  }

  function field(tag, cls, text) {
    var el = document.createElement(tag);
    el.className = cls;
    el.textContent = text;
    return el;
  }

  function spawn(target) {
    var data = annotations[target.getAttribute("href")];
    if (!data) return;

    var p = getPopup();
    p.innerHTML = "";

    var title = field("p", "link-popup__title", "");
    var a = document.createElement("a");
    a.href = target.getAttribute("href");
    a.textContent = data.title || a.href;
    title.appendChild(a);
    p.appendChild(title);

    if (data.byline) p.appendChild(field("p", "link-popup__byline", data.byline));
    if (data.abstract)
      p.appendChild(field("p", "link-popup__abstract", data.abstract));

    p.classList.add("visible");
    position(p, target);
  }

  function position(p, target) {
    var rect = target.getBoundingClientRect();

    // Measure at the capped width before deciding placement.
    p.style.left = "0px";
    p.style.top = "0px";
    p.style.maxWidth = Math.min(MAX_WIDTH, window.innerWidth - 2 * PAD) + "px";
    var pw = p.offsetWidth;
    var ph = p.offsetHeight;

    // Left-align to the link, clamped inside the viewport.
    var left = rect.left;
    if (left + pw > window.innerWidth - PAD) left = window.innerWidth - PAD - pw;
    if (left < PAD) left = PAD;

    // Below the link by default; flip above when it wouldn't fit below.
    var fitsBelow = rect.bottom + GAP + ph <= window.innerHeight - PAD;
    var fitsAbove = rect.top - GAP - ph >= PAD;
    var top = fitsBelow || !fitsAbove ? rect.bottom + GAP : rect.top - GAP - ph;

    // Absolute coords are document-relative, so add the scroll offset.
    p.style.left = left + window.pageXOffset + "px";
    p.style.top = top + window.pageYOffset + "px";
  }

  function despawn() {
    if (popup) popup.classList.remove("visible");
  }

  function scheduleSpawn(target) {
    cancelDespawn();
    clearTimeout(spawnTimer);
    spawnTimer = setTimeout(function () {
      spawn(target);
    }, SPAWN_DELAY);
  }

  function cancelSpawn() {
    clearTimeout(spawnTimer);
    spawnTimer = null;
  }

  function scheduleDespawn() {
    clearTimeout(despawnTimer);
    despawnTimer = setTimeout(despawn, DESPAWN_DELAY);
  }

  function cancelDespawn() {
    clearTimeout(despawnTimer);
    despawnTimer = null;
  }
})();
