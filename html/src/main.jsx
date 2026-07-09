import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Check, CircleDot, Save, SquareMousePointer, Timer, Zap } from 'lucide-react';
import './styles.css';

const initialDebug = {
  visible: false,
  screen: 'selector',
  title: 'TSS Location Debug',
  subtitle: '',
  items: [],
  footer: '',
  totalEntries: 0,
};

function App() {
  const [debugUi, setDebugUi] = useState(initialDebug);
  const [notices, setNotices] = useState([]);
  const [progress, setProgress] = useState(null);

  useEffect(() => {
    const handleMessage = (event) => {
      const data = event.data || {};

      if (data.action === 'debugUi') {
        setDebugUi((current) => ({ ...current, ...data.payload }));
      }

      if (data.action === 'notify') {
        const id = `${Date.now()}-${Math.random()}`;
        setNotices((current) => [...current.slice(-3), { id, ...data.payload }]);
        window.setTimeout(() => {
          setNotices((current) => current.filter((notice) => notice.id !== id));
        }, data.payload?.duration || 4500);
      }

      if (data.action === 'progress') {
        setProgress(data.payload || null);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  return (
    <div className="tss-ui">
      <StealthTexture />
      {debugUi.visible && <LocationDebugPanel data={debugUi} />}
      <NoticeStack notices={notices} />
      {progress && <ProgressBar data={progress} />}
    </div>
  );
}

function StealthTexture() {
  return (
    <div className="stealth-stage" aria-hidden="true">
      <div className="stealth-mark">
        <div className="stealth-ring" />
        <span>TSS</span>
      </div>
    </div>
  );
}

function LocationDebugPanel({ data }) {
  const isSelector = data.screen === 'selector';
  const isPedPicker = Boolean(data.pedPicker);

  return (
    <section className={`debug-panel ${isSelector ? 'selector-panel' : 'placement-panel'} ${isPedPicker ? 'picker-panel' : ''}`}>
      <div className="panel-glow panel-glow-top" />
      <div className="panel-glow panel-glow-left" />

      <header className="debug-header">
        <div>
          <h1>{data.title}</h1>
          {data.subtitle && <p>{data.subtitle}</p>}
        </div>
        <div className="debug-badge">
          <Zap size={14} />
          <span>{data.totalEntries || 0}</span>
        </div>
      </header>

      {isSelector ? (
        isPedPicker ? <PedPicker data={data.pedPicker} /> : <SelectorList items={data.items || []} />
      ) : (
        <PlacementReadout data={data} />
      )}

      <footer className="debug-footer">{data.footer}</footer>
    </section>
  );
}

function postNui(eventName, payload) {
  const resource = window.GetParentResourceName ? window.GetParentResourceName() : 'tss_bridge';
  return fetch(`https://${resource}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload || {}),
  }).catch(() => undefined);
}

function PedPicker({ data }) {
  const [modelIndex, setModelIndex] = useState(data.modelIndex || 1);
  const [scenarioIndex, setScenarioIndex] = useState(data.scenarioIndex || 1);
  const models = data.models || [];
  const scenarios = data.scenarios || [];

  useEffect(() => {
    setModelIndex(data.modelIndex || 1);
    setScenarioIndex(data.scenarioIndex || 1);
  }, [data.modelIndex, data.scenarioIndex]);

  const chooseModel = (event) => {
    const next = Number(event.target.value);
    setModelIndex(next);
    postNui('debugPedPicker', { modelIndex: next, scenarioIndex });
  };

  const chooseScenario = (event) => {
    const next = Number(event.target.value);
    setScenarioIndex(next);
    postNui('debugPedPicker', { modelIndex, scenarioIndex: next });
  };

  const startPlacement = () => {
    postNui('debugPedPicker', { modelIndex, scenarioIndex, start: true });
  };

  return (
    <div className="ped-picker">
      <label>
        <span>Ped Model</span>
        <select value={modelIndex} onChange={chooseModel}>
          {models.map((model, index) => (
            <option value={index + 1} key={model}>{model}</option>
          ))}
        </select>
      </label>

      <label>
        <span>Scenario</span>
        <select value={scenarioIndex} onChange={chooseScenario}>
          {scenarios.map((scenario, index) => (
            <option value={index + 1} key={scenario.value || scenario.label}>
              {scenario.value || scenario.label}
            </option>
          ))}
        </select>
      </label>

      <button type="button" onClick={startPlacement}>Place Ped</button>
    </div>
  );
}

function SelectorList({ items }) {
  return (
    <div className="selector-list">
      {items.map((item, index) => {
        const isSave = item.kind === 'save';
        const Icon = isSave ? Save : item.count > 0 ? Check : CircleDot;

        return (
          <div className={`selector-row ${item.selected ? 'selected' : ''} ${isSave ? 'save-row' : ''}`} key={`${item.label}-${index}`}>
            <div className="selector-marker">{item.selected ? '>' : ''}</div>
            <Icon size={15} />
            <span className="selector-label">{item.label}</span>
            {item.count > 0 && <span className="selector-count">{item.count}</span>}
          </div>
        );
      })}
    </div>
  );
}

function PlacementReadout({ data }) {
  const metrics = data.metrics || [];
  const help = data.help || [];

  const groupedHelp = useMemo(() => help.slice(0, 3), [help]);

  return (
    <div className="placement-readout">
      <div className="placement-status">
        <span>{data.modeLabel}</span>
        <span>{data.savedLabel}</span>
      </div>

      <div className="metrics-grid">
        {metrics.map((metric) => (
          <div className="metric" key={metric.label}>
            <span>{metric.label}</span>
            <strong>{metric.value}</strong>
          </div>
        ))}
      </div>

      <div className="help-grid">
        {groupedHelp.map((line) => (
          <div className="help-line" key={line}>
            <SquareMousePointer size={14} />
            <span>{line}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function NoticeStack({ notices }) {
  return (
    <div className="notice-stack">
      {notices.map((notice) => (
        <div className={`notice ${notice.type || 'info'}`} key={notice.id}>
          <strong>{notice.title || 'TinySprite'}</strong>
          <span>{notice.message || notice.text}</span>
        </div>
      ))}
    </div>
  );
}

function ProgressBar({ data }) {
  const pct = Math.max(0, Math.min(100, data.percent || 0));

  return (
    <div className="progress-shell">
      <div className="progress-title">
        <Timer size={15} />
        <span>{data.label || 'Working'}</span>
      </div>
      <div className="progress-track">
        <div className="progress-fill" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

createRoot(document.getElementById('root')).render(<App />);
