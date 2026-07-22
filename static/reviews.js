// Reviews catalog: type-filter pills + inline expand. Progressive enhancement —
// without JS all cards show and takes stay clamped with a fade (still readable).
(function () {
  var cards = [].slice.call(document.querySelectorAll(".rev"));

  // Type-filter pills.
  var pills = [].slice.call(document.querySelectorAll(".filters .pill"));
  pills.forEach(function (pill) {
    pill.addEventListener("click", function () {
      pills.forEach(function (p) { p.classList.remove("active"); });
      pill.classList.add("active");
      var f = pill.getAttribute("data-filter");
      cards.forEach(function (c) {
        var show = f === "all" || c.getAttribute("data-medium") === f;
        c.style.display = show ? "" : "none";
      });
    });
  });

  // Expand: only offer the toggle when the take actually overflows its clamp.
  cards.forEach(function (card) {
    var take = card.querySelector(".rev__take");
    var btn = card.querySelector(".rev-more");
    if (!take || !btn) return;
    if (take.scrollHeight <= take.clientHeight + 2) {
      btn.style.display = "none";
      return;
    }
    btn.addEventListener("click", function () {
      var expanded = take.classList.toggle("clamp") === false;
      btn.textContent = expanded ? "collapse ↑" : "expand ↓";
    });
  });
})();
