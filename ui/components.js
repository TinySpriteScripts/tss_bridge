// Generated from ui/src/components.jsx.
window.TSSUI = {
  createComponents(React) {
    function Button({ className = "", variant, ...props }) {
      const tone = variant || (className.includes("primary-button") ? "primary" : className.includes("danger-button") ? "danger" : "secondary");
      return /* @__PURE__ */ React.createElement("button", { type: "button", ...props, className: `tss-button ${tone}-button tss-button-${tone} ${className}` });
    }
    function Table({ className = "", ...props }) {
      return /* @__PURE__ */ React.createElement("table", { ...props, className: `tss-table ${className}` });
    }
    function Pill({ className = "", children }) {
      return /* @__PURE__ */ React.createElement("span", { className: `pill ${className}` }, children);
    }
    function Shell({ title, pages, summary = [], activePage, onPageChange, onClose, children }) {
      const page = pages.find((page2) => page2.id === activePage) || pages[0];
      return /* @__PURE__ */ React.createElement("main", { className: "app-shell" }, /* @__PURE__ */ React.createElement("section", { className: "desktop-window tss-window" }, /* @__PURE__ */ React.createElement("header", { className: "title-bar tss-titlebar" }, /* @__PURE__ */ React.createElement("div", { className: "title-meta" }, /* @__PURE__ */ React.createElement("span", { className: "tss-brand" }, "TINYSPRITE"), /* @__PURE__ */ React.createElement("strong", null, title)), /* @__PURE__ */ React.createElement("div", { className: "window-actions" }, /* @__PURE__ */ React.createElement("button", { type: "button", "aria-label": "Close", onClick: onClose }, "X"))), /* @__PURE__ */ React.createElement("section", { className: "window-body tss-workspace" }, /* @__PURE__ */ React.createElement("nav", { className: "tab-strip tss-nav", "aria-label": "Pages" }, pages.map((item) => /* @__PURE__ */ React.createElement(
        "button",
        {
          key: item.id,
          type: "button",
          className: `tab-button tss-nav-item${item.id === page?.id ? " active" : ""}`,
          "aria-current": item.id === page?.id ? "page" : void 0,
          onClick: () => onPageChange(item.id)
        },
        /* @__PURE__ */ React.createElement("span", null, item.label),
        item.badge && /* @__PURE__ */ React.createElement("span", { className: "mention-badge" }, item.badge)
      ))), /* @__PURE__ */ React.createElement("div", { className: "page-area" }, /* @__PURE__ */ React.createElement("aside", { className: "summary-rail" }, summary.map((item) => /* @__PURE__ */ React.createElement(InfoCard, { key: item.label, ...item }))), page?.render()))), children);
    }
    function TerminalIdle({ title, subtitle, instruction, footer }) {
      return /* @__PURE__ */ React.createElement("main", { className: "computer-idle" }, /* @__PURE__ */ React.createElement("header", { className: "title-bar tss-titlebar" }, /* @__PURE__ */ React.createElement("strong", null, title), /* @__PURE__ */ React.createElement("span", null, "Online")), /* @__PURE__ */ React.createElement("section", { className: "computer-idle-content" }, /* @__PURE__ */ React.createElement("div", { className: "computer-idle-icon", "aria-hidden": "true" }, "\u25A6"), /* @__PURE__ */ React.createElement("h1", null, title), /* @__PURE__ */ React.createElement("h2", null, subtitle), /* @__PURE__ */ React.createElement("p", null, instruction), /* @__PURE__ */ React.createElement("span", { className: "computer-idle-status", role: "status" }, "Ready")), /* @__PURE__ */ React.createElement("footer", null, footer, /* @__PURE__ */ React.createElement("span", null, "Small sprite. Big business.")));
    }
    function ConfirmDialog({ title, message, confirmLabel, danger, onCancel, onConfirm }) {
      return /* @__PURE__ */ React.createElement("div", { className: "modal-overlay", role: "presentation" }, /* @__PURE__ */ React.createElement("section", { className: "confirm-dialog", role: "dialog", "aria-modal": "true", "aria-labelledby": "confirm-dialog-title" }, /* @__PURE__ */ React.createElement("div", { className: "confirm-copy" }, /* @__PURE__ */ React.createElement("h2", { id: "confirm-dialog-title" }, title), /* @__PURE__ */ React.createElement("p", null, message)), /* @__PURE__ */ React.createElement("div", { className: "confirm-actions" }, /* @__PURE__ */ React.createElement(Button, { onClick: onCancel }, "No"), /* @__PURE__ */ React.createElement(Button, { variant: danger ? "danger" : "primary", onClick: onConfirm }, confirmLabel))));
    }
    function Panel({ title, children, action, className }) {
      return /* @__PURE__ */ React.createElement("section", { className: `panel tss-panel${className ? ` ${className}` : ""}` }, /* @__PURE__ */ React.createElement("header", { className: `panel-head tss-panel-head ${action ? "panel-head-split" : ""}` }, /* @__PURE__ */ React.createElement("h2", null, title), action), /* @__PURE__ */ React.createElement("div", { className: "panel-body" }, children));
    }
    function SectionHeader({ title, subtitle, action }) {
      return /* @__PURE__ */ React.createElement("div", { className: "section-header split-header" }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("h1", null, title), subtitle && /* @__PURE__ */ React.createElement("p", null, subtitle)), action);
    }
    function Chart({ variant, data, formatValue, emptyMessage = "No data available", label = "Chart" }) {
      if (data.length === 0) {
        return /* @__PURE__ */ React.createElement("div", { className: "empty-chart" }, emptyMessage);
      }
      if (variant === "pie_chart") {
        const total = data.reduce((sum, point) => sum + Math.abs(point.value), 0) || 1;
        let offset = 0;
        const gradient = data.map((point) => {
          const start = offset;
          const end = offset + Math.abs(point.value) / total * 100;
          offset = end;
          return `${point.color} ${start}% ${end}%`;
        }).join(", ");
        return /* @__PURE__ */ React.createElement("div", { className: "finance-chart pie-chart-layout" }, /* @__PURE__ */ React.createElement("div", { className: "pie-chart", style: { background: `conic-gradient(${gradient})` } }), /* @__PURE__ */ React.createElement("div", { className: "chart-legend" }, data.map((point) => /* @__PURE__ */ React.createElement("div", { key: point.label }, /* @__PURE__ */ React.createElement("span", { style: { background: point.color } }), point.label, ": ", formatValue(point.value)))));
      }
      const width = 620;
      const height = 260;
      const padding = { top: 18, right: 78, bottom: 44, left: 18 };
      const plotWidth = width - padding.left - padding.right;
      const plotHeight = height - padding.top - padding.bottom;
      const values = data.map((point) => point.value);
      const minValue = Math.min(0, ...values);
      const maxValue = Math.max(0, ...values);
      const range = Math.max(1, maxValue - minValue);
      const zeroY = padding.top + (maxValue - 0) / range * plotHeight;
      const points = data.map((point, index) => {
        const x = data.length === 1 ? padding.left + plotWidth / 2 : padding.left + index / (data.length - 1) * plotWidth;
        const y = padding.top + (maxValue - point.value) / range * plotHeight;
        return `${x},${y}`;
      }).join(" ");
      const singlePoint = data.length === 1;
      const yTicks = [maxValue, Math.round((maxValue + minValue) / 2), minValue];
      const xTickEvery = Math.max(1, Math.ceil(data.length / 6));
      return /* @__PURE__ */ React.createElement("div", { className: "finance-chart line-chart-layout" }, /* @__PURE__ */ React.createElement("svg", { viewBox: `0 0 ${width} ${height}`, role: "img", "aria-label": label }, /* @__PURE__ */ React.createElement("line", { x1: padding.left, y1: zeroY, x2: padding.left + plotWidth, y2: zeroY, className: "chart-zero-line" }), yTicks.map((tick, index) => {
        const y = padding.top + (maxValue - tick) / range * plotHeight;
        return /* @__PURE__ */ React.createElement("g", { key: `${tick}-${index}` }, /* @__PURE__ */ React.createElement("line", { x1: padding.left, y1: y, x2: padding.left + plotWidth, y2: y, className: "chart-grid-line" }), /* @__PURE__ */ React.createElement("text", { x: padding.left + plotWidth + 10, y: y + 4, className: "chart-axis-label" }, formatValue(tick)));
      }), singlePoint ? /* @__PURE__ */ React.createElement(
        "line",
        {
          x1: padding.left + plotWidth / 2,
          y1: zeroY,
          x2: padding.left + plotWidth / 2,
          y2: points.split(",")[1],
          className: "chart-line single-point-line"
        }
      ) : /* @__PURE__ */ React.createElement("polyline", { points, className: "chart-line" }), data.map((point, index) => {
        const x = singlePoint ? padding.left + plotWidth / 2 : padding.left + index / (data.length - 1) * plotWidth;
        const y = padding.top + (maxValue - point.value) / range * plotHeight;
        return /* @__PURE__ */ React.createElement("circle", { key: `${point.label}-${index}`, cx: x, cy: y, r: "5", className: "chart-dot" });
      }), data.map((point, index) => {
        if (index % xTickEvery !== 0 && index !== data.length - 1) return null;
        const x = singlePoint ? padding.left + plotWidth / 2 : padding.left + index / (data.length - 1) * plotWidth;
        return /* @__PURE__ */ React.createElement("text", { key: `label-${point.label}`, x, y: height - 12, className: "chart-axis-label chart-x-label" }, point.label);
      })));
    }
    function InfoCard({ label, value }) {
      return /* @__PURE__ */ React.createElement("div", { className: "info-card tss-panel" }, /* @__PURE__ */ React.createElement("span", null, label), /* @__PURE__ */ React.createElement("strong", null, value));
    }
    function Metric({ label, value, detail, tone }) {
      return /* @__PURE__ */ React.createElement("div", { className: `finance-metric${tone ? ` ${tone}` : ""}` }, /* @__PURE__ */ React.createElement("span", null, label), /* @__PURE__ */ React.createElement("strong", null, value), /* @__PURE__ */ React.createElement("small", null, detail));
    }
    return { Shell, Panel, SectionHeader, Chart, InfoCard, Metric, TerminalIdle, ConfirmDialog, Button, Table, Pill };
  }
};
