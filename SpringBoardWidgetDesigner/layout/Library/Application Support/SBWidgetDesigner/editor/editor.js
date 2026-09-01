(function () {
  const canvas = document.getElementById("stage");
  const ctx = canvas.getContext("2d");
  const emptyHint = document.getElementById("emptyHint");
  const pageLabel = document.getElementById("pageLabel");
  const fontModal = document.getElementById("fontModal");
  const fontList = document.getElementById("fontList");

  const state = {
    page: 0,
    fonts: [{ family: "System" }],
    doc: { version: 1, page: 0, enabled: true, elements: [] },
    selectedId: null,
    drag: null
  };

  function post(payload) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.sbwd) {
      window.webkit.messageHandlers.sbwd.postMessage(payload);
    }
  }

  function uid() {
    return "el_" + Math.random().toString(36).slice(2, 10);
  }

  function resize() {
    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.floor(rect.width * dpr));
    canvas.height = Math.max(1, Math.floor(rect.height * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    paint();
  }

  function cssSize() {
    const rect = canvas.getBoundingClientRect();
    return { w: rect.width, h: rect.height };
  }

  function elements() {
    return state.doc.elements || [];
  }

  function selected() {
    return elements().filter(function (el) { return el.id === state.selectedId; })[0] || null;
  }

  function paint() {
    const size = cssSize();
    SBWDRender.drawDocument(ctx, state.doc, size.w, size.h, new Date(), state.selectedId);
    emptyHint.style.display = elements().length ? "none" : "flex";
  }

  function hitHandle(el, x, y, size) {
    const b = SBWDRender.box(el, size.w, size.h);
    const points = {
      nw: [b.x, b.y],
      ne: [b.x + b.w, b.y],
      sw: [b.x, b.y + b.h],
      se: [b.x + b.w, b.y + b.h],
      rot: [b.x + b.w / 2, b.y - 28]
    };
    const names = Object.keys(points);
    for (let i = 0; i < names.length; i++) {
      const p = points[names[i]];
      if (Math.abs(x - p[0]) <= 14 && Math.abs(y - p[1]) <= 14) return names[i];
    }
    if (x >= b.x && y >= b.y && x <= b.x + b.w && y <= b.y + b.h) return "move";
    return null;
  }

  function hitTest(x, y) {
    const size = cssSize();
    const ordered = elements().slice().sort(function (a, b) { return (b.z || 0) - (a.z || 0); });
    if (state.selectedId) {
      const current = selected();
      if (current) {
        const handle = hitHandle(current, x, y, size);
        if (handle) return { el: current, handle: handle };
      }
    }
    for (let i = 0; i < ordered.length; i++) {
      const handle = hitHandle(ordered[i], x, y, size);
      if (handle) return { el: ordered[i], handle: handle === "rot" ? "move" : handle };
    }
    return null;
  }

  function pointerPos(event) {
    const rect = canvas.getBoundingClientRect();
    const t = event.touches ? event.touches[0] : event;
    return { x: t.clientX - rect.left, y: t.clientY - rect.top };
  }

  function normalize(el) {
    const size = cssSize();
    const b = SBWDRender.box(el, size.w, size.h);
    el.coordSpace = "normalized";
    el.x = b.x / size.w;
    el.y = b.y / size.h;
    el.w = b.w / size.w;
    el.h = b.h / size.h;
  }

  function addElement(type) {
    const nextZ = elements().reduce(function (max, el) { return Math.max(max, el.z || 0); }, 0) + 1;
    const el = {
      id: uid(),
      type: type,
      x: 0.12,
      y: 0.18 + (elements().length % 5) * 0.08,
      w: type === "shape" || type === "image" ? 0.42 : 0.62,
      h: type === "shape" || type === "image" ? 0.22 : 0.1,
      coordSpace: "normalized",
      rotation: 0,
      z: nextZ,
      font: "System",
      fontSize: type === "datetime" ? 42 : 28,
      color: "#ffffff",
      opacity: 1,
      align: "left",
      content: type === "text" ? "Текст" : type === "datetime" ? "HH:mm" : type === "weather" ? "22° Cloudy" : "",
      shape: "rect",
      cornerRadius: 16
    };
    state.doc.elements.push(el);
    state.selectedId = el.id;
    if (type === "image") post({ action: "pickImage" });
    syncProps();
    paint();
  }

  function syncProps() {
    const el = selected();
    document.getElementById("elType").textContent = el ? el.type : "—";
    document.getElementById("propContent").value = el ? (el.content || "") : "";
    document.getElementById("propColor").value = el && el.color ? el.color : "#ffffff";
    document.getElementById("propOpacity").value = el ? Math.round((el.opacity == null ? 1 : el.opacity) * 100) : 100;
    document.getElementById("btnFont").textContent = el && el.font ? el.font : "System";
    document.getElementById("propSize").value = el && el.fontSize ? el.fontSize : 28;
    document.getElementById("propRotate").value = el && el.rotation ? el.rotation : 0;
  }

  function bindProps() {
    document.getElementById("propContent").addEventListener("input", function (e) {
      const el = selected();
      if (!el) return;
      el.content = e.target.value;
      paint();
    });
    document.getElementById("propColor").addEventListener("input", function (e) {
      const el = selected();
      if (!el) return;
      el.color = e.target.value;
      paint();
    });
    document.getElementById("propOpacity").addEventListener("input", function (e) {
      const el = selected();
      if (!el) return;
      el.opacity = Number(e.target.value) / 100;
      paint();
    });
    document.getElementById("propSize").addEventListener("input", function (e) {
      const el = selected();
      if (!el) return;
      el.fontSize = Number(e.target.value);
      paint();
    });
    document.getElementById("propRotate").addEventListener("input", function (e) {
      const el = selected();
      if (!el) return;
      el.rotation = Number(e.target.value);
      paint();
    });
  }

  canvas.addEventListener("pointerdown", function (event) {
    const p = pointerPos(event);
    const hit = hitTest(p.x, p.y);
    if (!hit) {
      state.selectedId = null;
      state.drag = null;
      syncProps();
      paint();
      return;
    }
    state.selectedId = hit.el.id;
    const size = cssSize();
    const b = SBWDRender.box(hit.el, size.w, size.h);
    state.drag = {
      handle: hit.handle,
      startX: p.x,
      startY: p.y,
      orig: { x: b.x, y: b.y, w: b.w, h: b.h, rotation: hit.el.rotation || 0 }
    };
    canvas.setPointerCapture(event.pointerId);
    syncProps();
    paint();
  });

  canvas.addEventListener("pointermove", function (event) {
    if (!state.drag) return;
    const el = selected();
    if (!el) return;
    const p = pointerPos(event);
    const dx = p.x - state.drag.startX;
    const dy = p.y - state.drag.startY;
    const o = state.drag.orig;
    let x = o.x, y = o.y, w = o.w, h = o.h;
    if (state.drag.handle === "move") {
      x = o.x + dx;
      y = o.y + dy;
    } else if (state.drag.handle === "se") {
      w = Math.max(24, o.w + dx);
      h = Math.max(24, o.h + dy);
    } else if (state.drag.handle === "ne") {
      w = Math.max(24, o.w + dx);
      h = Math.max(24, o.h - dy);
      y = o.y + dy;
    } else if (state.drag.handle === "sw") {
      w = Math.max(24, o.w - dx);
      h = Math.max(24, o.h + dy);
      x = o.x + dx;
    } else if (state.drag.handle === "nw") {
      w = Math.max(24, o.w - dx);
      h = Math.max(24, o.h - dy);
      x = o.x + dx;
      y = o.y + dy;
    } else if (state.drag.handle === "rot") {
      const size = cssSize();
      const b = { x: o.x, y: o.y, w: o.w, h: o.h };
      const cx = b.x + b.w / 2;
      const cy = b.y + b.h / 2;
      el.rotation = Math.round(Math.atan2(p.y - cy, p.x - cx) * (180 / Math.PI) + 90);
      document.getElementById("propRotate").value = el.rotation;
      paint();
      return;
    }
    const size = cssSize();
    el.coordSpace = "normalized";
    el.x = x / size.w;
    el.y = y / size.h;
    el.w = w / size.w;
    el.h = h / size.h;
    paint();
  });

  canvas.addEventListener("pointerup", function () {
    const el = selected();
    if (el) normalize(el);
    state.drag = null;
  });

  document.querySelectorAll("[data-tool]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      addElement(btn.getAttribute("data-tool"));
    });
  });

  document.getElementById("btnDelete").addEventListener("click", function () {
    state.doc.elements = elements().filter(function (el) { return el.id !== state.selectedId; });
    state.selectedId = null;
    syncProps();
    paint();
  });

  document.getElementById("btnFront").addEventListener("click", function () {
    const el = selected();
    if (!el) return;
    el.z = elements().reduce(function (max, item) { return Math.max(max, item.z || 0); }, 0) + 1;
    paint();
  });

  document.getElementById("btnBack").addEventListener("click", function () {
    const el = selected();
    if (!el) return;
    el.z = elements().reduce(function (min, item) { return Math.min(min, item.z || 0); }, 0) - 1;
    paint();
  });

  document.getElementById("btnClose").addEventListener("click", function () {
    post({ action: "saveAndClose", document: state.doc });
  });

  document.getElementById("btnSave").addEventListener("click", function () {
    post({ action: "save", document: state.doc });
  });

  document.getElementById("btnFont").addEventListener("click", function () {
    renderFonts();
    fontModal.classList.remove("hidden");
  });

  document.getElementById("btnFontClose").addEventListener("click", function () {
    fontModal.classList.add("hidden");
  });

  function renderFonts() {
    fontList.innerHTML = "";
    state.fonts.forEach(function (font) {
      const item = document.createElement("button");
      item.className = "font-item";
      item.style.width = "100%";
      item.style.textAlign = "left";
      item.style.background = "transparent";
      const preview = document.createElement("div");
      preview.className = "preview";
      preview.textContent = "Ag  " + font.family;
      preview.style.fontFamily = font.family === "System" ? "-apple-system, system-ui" : "'" + font.family + "', sans-serif";
      item.appendChild(preview);
      item.addEventListener("click", function () {
        const el = selected();
        if (el) el.font = font.family;
        document.getElementById("btnFont").textContent = font.family;
        fontModal.classList.add("hidden");
        paint();
      });
      fontList.appendChild(item);
    });
  }

  window.SBWDBoot = function (doc, fonts, css, page) {
    if (css) {
      let style = document.getElementById("sbwd-fonts");
      if (!style) {
        style = document.createElement("style");
        style.id = "sbwd-fonts";
        document.head.appendChild(style);
      }
      style.textContent = css;
    }
    state.doc = doc && doc.elements ? doc : { version: 1, page: page || 0, enabled: true, elements: [] };
    state.fonts = fonts && fonts.length ? fonts : [{ family: "System" }];
    state.page = page || 0;
    pageLabel.textContent = String(state.page);
    if (!state.selectedId && state.doc.elements[0]) state.selectedId = state.doc.elements[0].id;
    syncProps();
    paint();
  };

  window.SBWDDidPickImage = function (src, b64) {
    const el = selected() && selected().type === "image" ? selected() : elements().filter(function (item) { return item.type === "image"; }).pop();
    if (!el) return;
    el.src = src;
    el.dataURL = "data:image/jpeg;base64," + b64;
    paint();
  };

  bindProps();
  window.addEventListener("resize", resize);
  setInterval(paint, 1000);
  resize();
})();
