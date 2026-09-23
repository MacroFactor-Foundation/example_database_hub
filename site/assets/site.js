// Site behaviour for the hub pages. Two jobs:
//
// 1. Inline generated SVG figures (img.mf-inline-svg) so their text uses the
//    page's DM Sans web font; an <img> cannot load web fonts. If fetching fails
//    (e.g. a page opened from file://), the plain <img> stays in place.
// 2. The data visualiser: two selectors switching between pre-rendered static
//    SVGs described by generated/viz/manifest.json. The selection is kept in
//    the URL hash so a view can be linked to.

(function () {
  "use strict";

  var svgCache = {};

  function fetchSvg(url) {
    if (!svgCache[url]) {
      svgCache[url] = fetch(url).then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status + " for " + url);
        return r.text();
      });
    }
    return svgCache[url];
  }

  function toSvgElement(text, label) {
    var doc = new DOMParser().parseFromString(text, "image/svg+xml");
    var svg = doc.documentElement;
    if (!svg || svg.nodeName.toLowerCase() !== "svg") throw new Error("Not an SVG");
    svg.removeAttribute("width");
    svg.removeAttribute("height");
    svg.setAttribute("role", "img");
    if (label) svg.setAttribute("aria-label", label);
    svg.classList.add("mf-inline-svg");
    return document.importNode(svg, true);
  }

  function inlineFigures() {
    var imgs = document.querySelectorAll("img.mf-inline-svg");
    Array.prototype.forEach.call(imgs, function (img) {
      fetchSvg(img.getAttribute("src"))
        .then(function (text) {
          img.replaceWith(toSvgElement(text, img.getAttribute("alt")));
        })
        .catch(function () { /* keep the <img> fallback */ });
    });
  }

  // ---- visualiser --------------------------------------------------------------

  function initVisualiser(root) {
    var base = root.getAttribute("data-manifest");
    var dir = base.replace(/[^/]*$/, "");
    var viewSel = root.querySelector("#viz-view");
    var domainSel = root.querySelector("#viz-domain");
    var desc = root.querySelector(".mf-viz-desc");
    var plot = root.querySelector(".mf-viz-plot");
    var link = root.querySelector(".mf-viz-open");
    var manifest;

    function readHash() {
      var out = {};
      location.hash.replace(/^#/, "").split("&").forEach(function (kv) {
        var p = kv.split("=");
        if (p[0]) out[decodeURIComponent(p[0])] = decodeURIComponent(p[1] || "");
      });
      return out;
    }

    function viewInfo(view) {
      return manifest.views.filter(function (v) { return v.view === view; })[0];
    }

    function fillDomains(view, wanted) {
      var info = viewInfo(view);
      domainSel.innerHTML = "";
      info.domains.forEach(function (d) {
        var o = document.createElement("option");
        o.value = d;
        o.textContent = d;
        domainSel.appendChild(o);
      });
      domainSel.disabled = info.domains.length < 2;
      if (wanted && info.domains.indexOf(wanted) >= 0) domainSel.value = wanted;
    }

    function show() {
      var view = viewSel.value;
      var domain = domainSel.value;
      var entry = manifest.plots.filter(function (p) { return p.view === view && p.domain === domain; })[0];
      var info = viewInfo(view);
      desc.textContent = info.description;
      if (!entry) {
        plot.innerHTML = '<p class="mf-viz-status">No plot for this combination.</p>';
        return;
      }
      var url = dir + entry.file;
      link.setAttribute("href", url);
      history.replaceState(null, "", "#view=" + encodeURIComponent(view) + "&domain=" + encodeURIComponent(domain));
      plot.setAttribute("aria-busy", "true");
      fetchSvg(url)
        .then(function (text) {
          plot.innerHTML = "";
          plot.appendChild(toSvgElement(text, entry.alt));
        })
        .catch(function () {
          plot.innerHTML = "";
          var img = document.createElement("img");
          img.src = url;
          img.alt = entry.alt;
          img.className = "mf-inline-svg";
          plot.appendChild(img);
        })
        .then(function () { plot.removeAttribute("aria-busy"); });
    }

    fetch(base)
      .then(function (r) { return r.json(); })
      .then(function (m) {
        manifest = m;
        var groups = {};
        m.views.forEach(function (v) {
          if (!groups[v.group]) {
            groups[v.group] = document.createElement("optgroup");
            groups[v.group].label = v.group;
            viewSel.appendChild(groups[v.group]);
          }
          var o = document.createElement("option");
          o.value = v.view;
          o.textContent = v.label;
          groups[v.group].appendChild(o);
        });
        var h = readHash();
        if (h.view && viewInfo(h.view)) viewSel.value = h.view;
        fillDomains(viewSel.value, h.domain);
        viewSel.addEventListener("change", function () { fillDomains(viewSel.value, domainSel.value); show(); });
        domainSel.addEventListener("change", show);
        show();
      })
      .catch(function () {
        plot.innerHTML = '<p class="mf-viz-status">The visualiser could not load its plot list. ' +
          "If you opened this page from disk, preview it with <code>quarto preview site</code> instead.</p>";
      });
  }

  document.addEventListener("DOMContentLoaded", function () {
    inlineFigures();
    var viz = document.querySelector(".mf-viz[data-manifest]");
    if (viz) initVisualiser(viz);
  });
})();
