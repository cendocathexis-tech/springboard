(function () {
  const canvas = document.getElementById("c");
  const ctx = canvas.getContext("2d");
  let doc = { elements: [] };

  function resize() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.floor(window.innerWidth * dpr));
    canvas.height = Math.max(1, Math.floor(window.innerHeight * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    paint();
  }

  function paint() {
    SBWDRender.drawDocument(ctx, doc, window.innerWidth, window.innerHeight, new Date(), null);
  }

  window.SBWDApply = function (nextDoc, css) {
    if (css) {
      let style = document.getElementById("sbwd-fonts");
      if (!style) {
        style = document.createElement("style");
        style.id = "sbwd-fonts";
        document.head.appendChild(style);
      }
      style.textContent = css;
    }
    doc = nextDoc || { elements: [] };
    paint();
  };

  window.addEventListener("resize", resize);
  setInterval(paint, 1000);
  resize();
})();
