(function (global) {
  function pad(n) {
    return String(n).padStart(2, "0");
  }

  function formatDate(fmt, now) {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return String(fmt || "HH:mm")
      .replace(/YYYY/g, now.getFullYear())
      .replace(/MM/g, pad(now.getMonth() + 1))
      .replace(/DD/g, pad(now.getDate()))
      .replace(/dddd/g, days[now.getDay()])
      .replace(/HH/g, pad(now.getHours()))
      .replace(/mm/g, pad(now.getMinutes()))
      .replace(/ss/g, pad(now.getSeconds()));
  }

  function fontFor(el) {
    const family = el.font && el.font !== "System" ? "'" + el.font + "', sans-serif" : "-apple-system, system-ui, sans-serif";
    return (el.fontSize || 24) + "px " + family;
  }

  function drawRoundedRect(ctx, x, y, w, h, r) {
    const radius = Math.max(0, Math.min(r || 0, w / 2, h / 2));
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.arcTo(x + w, y, x + w, y + h, radius);
    ctx.arcTo(x + w, y + h, x, y + h, radius);
    ctx.arcTo(x, y + h, x, y, radius);
    ctx.arcTo(x, y, x + w, y, radius);
    ctx.closePath();
  }

  function box(el, canvasW, canvasH) {
    const normalized = el.coordSpace === "normalized" || (el.x <= 1 && el.y <= 1 && el.w <= 1 && el.h <= 1 && el.w > 0);
    if (normalized) {
      return {
        x: (el.x || 0) * canvasW,
        y: (el.y || 0) * canvasH,
        w: (el.w || 0.3) * canvasW,
        h: (el.h || 0.1) * canvasH
      };
    }
    return { x: el.x || 0, y: el.y || 0, w: el.w || 120, h: el.h || 40 };
  }

  function imageCache() {
    if (!global.__sbwdImages) global.__sbwdImages = {};
    return global.__sbwdImages;
  }

  function getImage(el) {
    const key = el.dataURL || el.src;
    if (!key) return null;
    const cache = imageCache();
    if (cache[key] && cache[key].complete) return cache[key];
    if (!cache[key]) {
      const img = new Image();
      img.src = el.dataURL || el.src;
      cache[key] = img;
    }
    return cache[key].complete ? cache[key] : null;
  }

  function drawElement(ctx, el, canvasW, canvasH, now) {
    const b = box(el, canvasW, canvasH);
    ctx.save();
    ctx.globalAlpha = el.opacity == null ? 1 : Number(el.opacity);
    ctx.translate(b.x + b.w / 2, b.y + b.h / 2);
    ctx.rotate(((el.rotation || 0) * Math.PI) / 180);
    ctx.translate(-b.w / 2, -b.h / 2);

    if (el.type === "shape") {
      ctx.fillStyle = el.color || "#ffffff";
      if (el.shape === "ellipse") {
        ctx.beginPath();
        ctx.ellipse(b.w / 2, b.h / 2, b.w / 2, b.h / 2, 0, 0, Math.PI * 2);
        ctx.fill();
      } else {
        drawRoundedRect(ctx, 0, 0, b.w, b.h, el.cornerRadius || 16);
        ctx.fill();
      }
    } else if (el.type === "image") {
      const img = getImage(el);
      if (img) {
        drawRoundedRect(ctx, 0, 0, b.w, b.h, el.cornerRadius || 12);
        ctx.clip();
        ctx.drawImage(img, 0, 0, b.w, b.h);
      } else {
        ctx.fillStyle = "rgba(255,255,255,0.12)";
        drawRoundedRect(ctx, 0, 0, b.w, b.h, 12);
        ctx.fill();
      }
    } else {
      let text = el.content || "";
      if (el.type === "datetime") text = formatDate(el.content || "HH:mm", now);
      if (el.type === "weather") text = el.content || "22° Cloudy";
      ctx.fillStyle = el.color || "#ffffff";
      ctx.font = fontFor(el);
      ctx.textBaseline = "middle";
      ctx.textAlign = el.align || "left";
      const tx = el.align === "center" ? b.w / 2 : el.align === "right" ? b.w : 0;
      ctx.fillText(text, tx, b.h / 2, b.w);
    }
    ctx.restore();
  }

  function drawDocument(ctx, doc, canvasW, canvasH, now, selectedId) {
    ctx.clearRect(0, 0, canvasW, canvasH);
    const elements = (doc && doc.elements ? doc.elements.slice() : []).sort(function (a, b) {
      return (a.z || 0) - (b.z || 0);
    });
    for (let i = 0; i < elements.length; i++) {
      drawElement(ctx, elements[i], canvasW, canvasH, now);
    }
    if (selectedId) {
      const el = elements.filter(function (item) { return item.id === selectedId; })[0];
      if (el) {
        const b = box(el, canvasW, canvasH);
        ctx.save();
        ctx.strokeStyle = "#6aa6ff";
        ctx.lineWidth = 2;
        ctx.setLineDash([6, 4]);
        ctx.strokeRect(b.x, b.y, b.w, b.h);
        ctx.setLineDash([]);
        ctx.fillStyle = "#6aa6ff";
        const handles = [
          [b.x, b.y],
          [b.x + b.w, b.y],
          [b.x, b.y + b.h],
          [b.x + b.w, b.y + b.h]
        ];
        handles.forEach(function (p) {
          ctx.fillRect(p[0] - 6, p[1] - 6, 12, 12);
        });
        ctx.beginPath();
        ctx.moveTo(b.x + b.w / 2, b.y);
        ctx.lineTo(b.x + b.w / 2, b.y - 28);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(b.x + b.w / 2, b.y - 28, 7, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }
    }
  }

  global.SBWDRender = {
    drawDocument: drawDocument,
    drawElement: drawElement,
    box: box,
    formatDate: formatDate
  };
})(window);
