window.TSSUI = {
  createComponents(React) {
    function Button({ className = "", variant, ...props }) {
      const tone =
        variant ||
        (className.includes("primary-button")
          ? "primary"
          : className.includes("danger-button")
            ? "danger"
            : "secondary");
      return (
        <button type="button" {...props} className={`tss-button ${tone}-button tss-button-${tone} ${className}`} />
      );
    }
    function Table({ className = "", ...props }) {
      return <table {...props} className={`tss-table ${className}`} />;
    }
    function Pill({ className = "", children }) {
      return <span className={`pill ${className}`}>{children}</span>;
    }
    function Shell({ title, pages, summary = [], activePage, onPageChange, onClose, children }) {
      const page = pages.find((page2) => page2.id === activePage) || pages[0];
      return (
        <main className="app-shell">
          <section className="desktop-window tss-window">
            <header className="title-bar tss-titlebar">
              <div className="title-meta">
                <span className="tss-brand">TINYSPRITE</span>
                <strong>{title}</strong>
              </div>
              <div className="window-actions">
                <button type="button" aria-label="Close" onClick={onClose}>
                  X
                </button>
              </div>
            </header>
            <section className="window-body tss-workspace">
              <nav className="tab-strip tss-nav" aria-label="Pages">
                {pages.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    className={`tab-button tss-nav-item${item.id === page?.id ? " active" : ""}`}
                    aria-current={item.id === page?.id ? "page" : void 0}
                    onClick={() => onPageChange(item.id)}
                  >
                    <span>{item.label}</span>
                    {item.badge && <span className="mention-badge">{item.badge}</span>}
                  </button>
                ))}
              </nav>
              <div className="page-area">
                <aside className="summary-rail">
                  {summary.map((item) => (
                    <InfoCard key={item.label} {...item} />
                  ))}
                </aside>
                {page?.render()}
              </div>
            </section>
          </section>
          {children}
        </main>
      );
    }
    function TerminalIdle({ title, subtitle, instruction, footer }) {
      return (
        <main className="computer-idle">
          <header className="title-bar tss-titlebar">
            <strong>{title}</strong>
            <span>Online</span>
          </header>
          <section className="computer-idle-content">
            <div className="computer-idle-icon" aria-hidden="true">
              &#9638;
            </div>
            <h1>{title}</h1>
            <h2>{subtitle}</h2>
            <p>{instruction}</p>
            <span className="computer-idle-status" role="status">
              Ready
            </span>
          </section>
          <footer>
            {footer}
            <span>Small sprite. Big business.</span>
          </footer>
        </main>
      );
    }
    function ConfirmDialog({ title, message, confirmLabel, danger, onCancel, onConfirm }) {
      return (
        <div className="modal-overlay" role="presentation">
          <section className="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="confirm-dialog-title">
            <div className="confirm-copy">
              <h2 id="confirm-dialog-title">{title}</h2>
              <p>{message}</p>
            </div>
            <div className="confirm-actions">
              <Button onClick={onCancel}>No</Button>
              <Button variant={danger ? "danger" : "primary"} onClick={onConfirm}>
                {confirmLabel}
              </Button>
            </div>
          </section>
        </div>
      );
    }
    function Panel({ title, children, action, className }) {
      return (
        <section className={`panel tss-panel${className ? ` ${className}` : ""}`}>
          <header className={`panel-head tss-panel-head ${action ? "panel-head-split" : ""}`}>
            <h2>{title}</h2>
            {action}
          </header>
          <div className="panel-body">{children}</div>
        </section>
      );
    }
    function SectionHeader({ title, subtitle, action }) {
      return (
        <div className="section-header split-header">
          <div>
            <h1>{title}</h1>
            {subtitle && <p>{subtitle}</p>}
          </div>
          {action}
        </div>
      );
    }
    function Chart({ variant, data, formatValue, emptyMessage = "No data available", label = "Chart" }) {
      if (data.length === 0) {
        return <div className="empty-chart">{emptyMessage}</div>;
      }
      if (variant === "pie_chart") {
        const total = data.reduce((sum, point) => sum + Math.abs(point.value), 0) || 1;
        let offset = 0;
        const gradient = data
          .map((point) => {
            const start = offset;
            const end = offset + (Math.abs(point.value) / total) * 100;
            offset = end;
            return `${point.color} ${start}% ${end}%`;
          })
          .join(", ");
        return (
          <div className="finance-chart pie-chart-layout">
            <div className="pie-chart" style={{ background: `conic-gradient(${gradient})` }} />
            <div className="chart-legend">
              {data.map((point) => (
                <div key={point.label}>
                  <span style={{ background: point.color }} />
                  {point.label}: {formatValue(point.value)}
                </div>
              ))}
            </div>
          </div>
        );
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
      const zeroY = padding.top + ((maxValue - 0) / range) * plotHeight;
      const points = data
        .map((point, index) => {
          const x =
            data.length === 1 ? padding.left + plotWidth / 2 : padding.left + (index / (data.length - 1)) * plotWidth;
          const y = padding.top + ((maxValue - point.value) / range) * plotHeight;
          return `${x},${y}`;
        })
        .join(" ");
      const singlePoint = data.length === 1;
      const yTicks = [maxValue, Math.round((maxValue + minValue) / 2), minValue];
      const xTickEvery = Math.max(1, Math.ceil(data.length / 6));
      return (
        <div className="finance-chart line-chart-layout">
          <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label={label}>
            <line x1={padding.left} y1={zeroY} x2={padding.left + plotWidth} y2={zeroY} className="chart-zero-line" />
            {yTicks.map((tick, index) => {
              const y = padding.top + ((maxValue - tick) / range) * plotHeight;
              return (
                <g key={`${tick}-${index}`}>
                  <line x1={padding.left} y1={y} x2={padding.left + plotWidth} y2={y} className="chart-grid-line" />
                  <text x={padding.left + plotWidth + 10} y={y + 4} className="chart-axis-label">
                    {formatValue(tick)}
                  </text>
                </g>
              );
            })}
            {singlePoint ? (
              <line
                x1={padding.left + plotWidth / 2}
                y1={zeroY}
                x2={padding.left + plotWidth / 2}
                y2={points.split(",")[1]}
                className="chart-line single-point-line"
              />
            ) : (
              <polyline points={points} className="chart-line" />
            )}
            {data.map((point, index) => {
              const x = singlePoint
                ? padding.left + plotWidth / 2
                : padding.left + (index / (data.length - 1)) * plotWidth;
              const y = padding.top + ((maxValue - point.value) / range) * plotHeight;
              return <circle key={`${point.label}-${index}`} cx={x} cy={y} r="5" className="chart-dot" />;
            })}
            {data.map((point, index) => {
              if (index % xTickEvery !== 0 && index !== data.length - 1) return null;
              const x = singlePoint
                ? padding.left + plotWidth / 2
                : padding.left + (index / (data.length - 1)) * plotWidth;
              return (
                <text key={`label-${point.label}`} x={x} y={height - 12} className="chart-axis-label chart-x-label">
                  {point.label}
                </text>
              );
            })}
          </svg>
        </div>
      );
    }
    function InfoCard({ label, value }) {
      return (
        <div className="info-card tss-panel">
          <span>{label}</span>
          <strong>{value}</strong>
        </div>
      );
    }
    function Metric({ label, value, detail, tone }) {
      return (
        <div className={`finance-metric${tone ? ` ${tone}` : ""}`}>
          <span>{label}</span>
          <strong>{value}</strong>
          <small>{detail}</small>
        </div>
      );
    }
    return { Shell, Panel, SectionHeader, Chart, InfoCard, Metric, TerminalIdle, ConfirmDialog, Button, Table, Pill };
  },
};
