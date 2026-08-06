import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  Activity, Bell, Box, Car, Check, ChevronRight, Circle, CircleDot, Clipboard, ClipboardCheck, Code2, Cpu,
  Crosshair, FlaskConical, Fuel, ImageOff, KeyRound, Keyboard, Map, MessageSquare,
  MousePointerClick, Package, Play, RotateCcw, Save, Search, Server, Settings,
  ShieldCheck, SquareMousePointer, Timer, Trash2, Type, Wrench, X, Zap,
} from 'lucide-react';
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
  const [dialog, setDialog] = useState(null);
  const [zoneCreator, setZoneCreator] = useState(null);
  const [attachmentCreator, setAttachmentCreator] = useState(null);
  const [bridgeLabBrowser, setBridgeLabBrowser] = useState(null);

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

      if (data.action === 'menu' || data.action === 'context' || data.action === 'input') {
        setDialog(data.payload ? { kind: data.action, ...data.payload } : null);
      }

      if (data.action === 'closeUi') setDialog(null);
      if (data.action === 'zoneCreator') setZoneCreator(data.payload || null);
      if (data.action === 'attachmentCreator') setAttachmentCreator(data.payload || null);
      if (data.action === 'bridgeLabBrowser') setBridgeLabBrowser(data.payload || null);
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  return (
    <div className="tss-ui">
      {debugUi.visible && <LocationDebugPanel data={debugUi} />}
      {zoneCreator?.visible && <ZoneCreatorPanel data={zoneCreator} />}
      {attachmentCreator?.visible && <AttachmentCreatorPanel data={attachmentCreator} />}
      {bridgeLabBrowser?.visible && <BridgeLabBrowser data={bridgeLabBrowser} />}
      {dialog && <BridgeDialog data={dialog} onClose={() => setDialog(null)} />}
      <NoticeStack notices={notices} />
      {progress && <ProgressBar data={progress} />}
    </div>
  );
}

function AttachmentCreatorPanel({ data }) {
  const [boneIndex, setBoneIndex] = useState(data.boneIndex || 1);
  const [animation, setAnimation] = useState(data.animation || { dict: '', clip: '', flag: 49 });

  useEffect(() => setBoneIndex(data.boneIndex || 1), [data.boneIndex]);
  useEffect(() => {
    if (data.settingsOpen) setAnimation(data.animation || { dict: '', clip: '', flag: 49 });
  }, [data.settingsOpen]);
  useEffect(() => {
    if (!data.settingsOpen) return undefined;
    const keydown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        postNui('attachmentCreatorAction', { action: 'close', boneIndex, ...animation });
      }
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  }, [data.settingsOpen, boneIndex, animation]);

  const sendAction = (action, extra = {}) => postNui('attachmentCreatorAction', { action, boneIndex, ...animation, ...extra });
  const changeBone = (event) => {
    const next = Number(event.target.value);
    setBoneIndex(next);
    sendAction('bone', { boneIndex: next });
  };

  return <section className={`zone-creator-panel attachment-creator-panel ${data.settingsOpen ? 'settings-open' : ''}`}>
    <div className="zone-creator-accent" />
    <header><div><span>Prop Attachment Creator</span><h2>{data.title || 'Untitled attachment'}</h2></div><div className="zone-mode"><Package size={14} />{data.mode || 'MOVE'}</div></header>
    <div className="zone-type">{data.model} · {data.bone}</div>
    <div className="zone-metrics attachment-metrics">{(data.metrics || []).map((metric) => <div key={metric.label}><span>{metric.label}</span><strong>{metric.value}</strong></div>)}</div>
    {data.message && <div className="zone-message">{data.message}</div>}
    {data.settingsOpen ? <div className="attachment-settings">
      <label><span>Ped bone</span><select value={boneIndex} onChange={changeBone}>{(data.bones || []).map((bone) => <option value={bone.index} key={bone.id}>{bone.name} · 0x{Number(bone.id).toString(16).toUpperCase().padStart(4, '0')}</option>)}</select></label>
      <div className="animation-fields">
        <label><span>Animation dictionary</span><input value={animation.dict || ''} placeholder="amb@world_human_clipboard@male@idle_a" onChange={(event) => setAnimation((current) => ({ ...current, dict: event.target.value }))} /></label>
        <label><span>Animation clip</span><input value={animation.clip || ''} placeholder="idle_c" onChange={(event) => setAnimation((current) => ({ ...current, clip: event.target.value }))} /></label>
        <label className="flag-field"><span>Flag</span><input type="number" min="0" max="1024" value={animation.flag ?? 49} onChange={(event) => setAnimation((current) => ({ ...current, flag: event.target.value }))} /></label>
      </div>
      <div className="attachment-actions"><button type="button" onClick={() => sendAction('play')}><Play size={14} />Play animation</button><button type="button" onClick={() => sendAction('stop')}><X size={14} />Stop</button><button type="button" className="done" onClick={() => sendAction('close')}><Check size={14} />Done editing</button></div>
    </div> : <button type="button" className="attachment-settings-hint"><Keyboard size={14} /><span>Press <kbd>B</kbd> for bone and animation settings</span></button>}
    <div className="zone-help">{(data.help || []).map((line) => <p key={line}><MousePointerClick size={13} />{line}</p>)}</div>
  </section>;
}

function copyText(value) {
  const text = String(value ?? '');
  if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(text).catch(() => fallbackCopy(text));
  return Promise.resolve(fallbackCopy(text));
}

function fallbackCopy(text) {
  const input = document.createElement('textarea');
  input.value = text;
  input.style.position = 'fixed';
  input.style.opacity = '0';
  document.body.appendChild(input);
  input.select();
  document.execCommand('copy');
  input.remove();
}

function CopyButton({ value, label = 'Copy' }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    copyText(value).finally(() => {
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1000);
    });
  };
  return <button type="button" className="browser-copy" onClick={copy}><Clipboard size={13} />{copied ? 'Copied' : label}</button>;
}

function ItemImage({ item }) {
  const candidates = item.imageCandidates || [];
  const [index, setIndex] = useState(0);
  useEffect(() => setIndex(0), [item.name]);
  if (!candidates[index]) return <div className="item-image missing"><ImageOff size={30} /><span>{item.image || 'No image'}</span></div>;
  return <div className="item-image"><img src={candidates[index]} alt={item.label} onError={() => setIndex((current) => current + 1)} /></div>;
}

function ApiExplorer({ data }) {
  const [query, setQuery] = useState('');
  const [selectedKey, setSelectedKey] = useState('');
  const modules = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (data.modules || []).map((module) => ({
      ...module,
      functions: (module.functions || []).filter((api) => !needle || `${module.name}.${api.name}`.toLowerCase().includes(needle)),
    })).filter((module) => !needle || module.name.toLowerCase().includes(needle) || module.functions.length);
  }, [data.modules, query]);
  const functions = modules.flatMap((module) => module.functions.map((api) => ({ ...api, module: module.name })));
  const selected = functions.find((api) => `${api.module}.${api.name}` === selectedKey) || functions[0];

  useEffect(() => {
    if (selected) setSelectedKey(`${selected.module}.${selected.name}`);
  }, [query]);

  return <div className="browser-workspace api-workspace">
    <aside className="browser-list">
      <div className="browser-search"><Search size={16} /><input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search modules and functions" /></div>
      <div className="browser-scroll">
        {modules.map((module) => <section className="api-module" key={module.name}>
          <h3>{module.name}<span>{module.functions.length}</span></h3>
          {module.functions.map((api) => {
            const key = `${module.name}.${api.name}`;
            return <button type="button" className={selected && key === `${selected.module}.${selected.name}` ? 'active' : ''} key={key} onClick={() => setSelectedKey(key)}>
              <Code2 size={14} /><span>{api.name}</span><i>{api.realms.client && 'C'}{api.realms.server && 'S'}</i>
            </button>;
          })}
        </section>)}
      </div>
    </aside>
    <main className="browser-detail">
      {selected ? <>
        <div className="detail-heading"><div><span>{selected.module} module</span><h2>{selected.module}.{selected.name}</h2></div><CopyButton value={`TSS.${selected.module}.${selected.name}`} label="Copy name" /></div>
        <div className="realm-cards">
          {['client', 'server'].map((realm) => selected.realms[realm] && <article className={`realm-card ${realm}`} key={realm}>
            <header><span>{realm}</span><CopyButton value={`TSS.${selected.module}.${selected.name}(${selected.realms[realm].params})`} label="Copy call" /></header>
            <code>{selected.name}({selected.realms[realm].params})</code>
            <dl><div><dt>Parameters</dt><dd>{selected.realms[realm].params || 'None'}</dd></div><div><dt>Returns</dt><dd>{selected.realms[realm].returns || 'Nothing'}</dd></div></dl>
          </article>)}
        </div>
        <div className="module-import"><span>Consumer import</span><code>{`local TSS = exports.tss_bridge:GetModules({ '${selected.module}' })`}</code><CopyButton value={`local TSS = exports.tss_bridge:GetModules({ '${selected.module}' })`} /></div>
      </> : <div className="browser-empty">No matching API functions.</div>}
    </main>
  </div>;
}

function ItemBrowser({ data }) {
  const [query, setQuery] = useState('');
  const [selectedName, setSelectedName] = useState('');
  const items = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (data.items || []).filter((item) => !needle || `${item.name} ${item.label}`.toLowerCase().includes(needle));
  }, [data.items, query]);
  const selected = items.find((item) => item.name === selectedName) || items[0];

  useEffect(() => {
    if (selected) setSelectedName(selected.name);
  }, [query]);

  return <div className="browser-workspace item-workspace">
    <aside className="browser-list">
      <div className="browser-search"><Search size={16} /><input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search item code or label" /></div>
      <div className="browser-scroll item-list">
        {items.map((item) => <button type="button" className={selected?.name === item.name ? 'active' : ''} key={item.name} onClick={() => setSelectedName(item.name)}>
          <ItemImage item={item} /><span><strong>{item.label}</strong><small>{item.name}</small></span>
        </button>)}
      </div>
    </aside>
    <main className="browser-detail">
      {selected ? <>
        <div className="item-heading"><ItemImage item={selected} /><div><span>Shared item definition</span><h2>{selected.label}</h2><code>{selected.name}</code></div><CopyButton value={selected.name} label="Copy item code" /></div>
        <div className="item-fields">
          {selected.fields.map((field) => <div className="item-field" key={field.name}><span><strong>{field.name}</strong><small>{field.valueType}</small></span><code>{field.value}</code><CopyButton value={field.value} /></div>)}
        </div>
      </> : <div className="browser-empty">No matching shared items.</div>}
    </main>
  </div>;
}

function BridgeLabBrowser({ data }) {
  useEffect(() => {
    const keydown = (event) => {
      if (event.key === 'Escape') postNui('bridgeLabBrowserClose');
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  }, []);

  return <section className="bridge-lab-browser">
    <header className="browser-header"><div><span>Bridge Lab / Developer Tools</span><h1>{data.title}</h1></div><div className="browser-summary">{data.kind === 'api' ? `${data.moduleCount} modules · ${data.functionCount} functions` : `${data.itemCount} items · ${data.system} / ${data.resource}`}</div><button type="button" onClick={() => postNui('bridgeLabBrowserClose')}><X size={18} /></button></header>
    {data.kind === 'api' ? <ApiExplorer data={data} /> : <ItemBrowser data={data} />}
    <footer><kbd>ESC</kbd><span>Return to Developer Tools</span><i>Click any copy button to place its exact value on your clipboard</i></footer>
  </section>;
}

function ZoneCreatorPanel({ data }) {
  return (
    <section className="zone-creator-panel">
      <div className="zone-creator-accent" />
      <header>
        <div>
          <span>PolyZone Creator</span>
          <h2>{data.title || 'Untitled zone'}</h2>
        </div>
        <div className="zone-mode"><Crosshair size={14} />{data.mode || 'EDITING'}</div>
      </header>
      <div className="zone-type">{data.zoneType || 'zone'} shape</div>
      <div className="zone-metrics">
        {(data.metrics || []).map((metric) => (
          <div key={metric.label}><span>{metric.label}</span><strong>{metric.value}</strong></div>
        ))}
      </div>
      {data.message && <div className="zone-message">{data.message}</div>}
      <div className="zone-help">
        {(data.help || []).map((line) => <p key={line}><MousePointerClick size={13} />{line}</p>)}
      </div>
    </section>
  );
}

function BridgeDialog({ data, onClose }) {
  const items = data.options || data.items || [];
  const [selected, setSelected] = useState(Math.max(0, data.selected || 0));
  const selectedOption = items[selected] || {};
  const SelectedIcon = iconFor(selectedOption.icon);

  useEffect(() => setSelected(Math.max(0, data.selected || 0)), [data]);

  const close = () => {
    postNui('uiClose', { id: data.id, kind: data.kind });
    onClose();
  };

  const choose = (index) => {
    const option = items[index];
    if (!option || option.disabled) return;
    postNui('uiSelect', { id: data.id, kind: data.kind, index: index + 1, value: option.value });
    if (option.keepOpen !== true) onClose();
  };

  useEffect(() => {
    const keydown = (event) => {
      if (data.kind === 'input') return;
      if (event.key === 'Escape' || event.key === 'Backspace') close();
      if (event.key === 'ArrowDown') setSelected((current) => (current + 1) % Math.max(1, items.length));
      if (event.key === 'ArrowUp') setSelected((current) => (current - 1 + Math.max(1, items.length)) % Math.max(1, items.length));
      if (event.key === 'Enter') choose(selected);
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  }, [selected, items.length, data.kind]);

  if (data.kind === 'input') return <InputDialog data={data} close={close} onClose={onClose} />;

  return (
    <div className={`bridge-dialog-layer ${data.kind}`}>
      <section className={`bridge-menu ${data.kind}-panel`}>
        <div className="bridge-kicker">{data.label || (data.kind === 'context' ? 'Context menu' : 'Menu')}</div>
        {data.kind === 'menu' && (
          <header className="bridge-menu-header">
            <div className="bridge-menu-heading">
              <h2>{data.title || 'Menu'}</h2>
              {data.status && <span className={`bridge-status ${data.statusTone || 'neutral'}`}>{data.status}</span>}
            </div>
            {data.description && <p>{data.description}</p>}
            <i />
          </header>
        )}
        <div className={data.kind === 'menu' ? 'bridge-menu-body' : undefined}>
          <div className="bridge-options">
            {items.map((option, index) => {
              const Icon = iconFor(option.icon);
              return (
                <button
                  className={`bridge-option ${selected === index ? 'selected' : ''}`}
                  disabled={option.disabled}
                  key={option.id || `${option.label}-${index}`}
                  onMouseEnter={() => setSelected(index)}
                  onClick={() => choose(index)}
                >
                  {Icon && <Icon size={20} strokeWidth={1.7} />}
                  <span className="bridge-option-copy">
                    <strong>{option.label || option.title}</strong>
                    {option.description && <small>{option.description}</small>}
                  </span>
                  {(option.arrow !== false && data.kind === 'menu') && <ChevronRight className="option-arrow" size={19} />}
                </button>
              );
            })}
            {data.kind === 'context' && (
              <button className="bridge-option close-option" onClick={close}><X size={20} /><span>{data.closeLabel || 'Close Menu'}</span></button>
            )}
          </div>
          {data.kind === 'menu' && (
            <aside className={`bridge-menu-preview ${selectedOption.disabled ? 'disabled' : ''}`}>
              <div className="preview-icon">{SelectedIcon && <SelectedIcon size={30} strokeWidth={1.5} />}</div>
              <span className="preview-label">{selectedOption.eyebrow || data.previewLabel || 'Selected item'}</span>
              <h3>{selectedOption.label || selectedOption.title || 'No options available'}</h3>
              <p>{selectedOption.description || 'Select this option to continue.'}</p>
              {selectedOption.badge && <span className="preview-badge">{selectedOption.badge}</span>}
              <span className="preview-count">{String(selected + 1).padStart(2, '0')} / {String(items.length).padStart(2, '0')}</span>
            </aside>
          )}
        </div>
        {data.kind === 'menu' && <footer className="menu-controls"><kbd>ESC</kbd><span>Back</span><b /> <kbd>ENTER</kbd><span>Select</span></footer>}
      </section>
    </div>
  );
}

function iconFor(name) {
  if (!name) return CircleDot;
  return {
    activity: Activity,
    api: Code2,
    audit: ClipboardCheck,
    boxzone: Box,
    check: Check,
    circlezone: Circle,
    cleanup: Trash2,
    close: X,
    configuration: Settings,
    deploy: Play,
    feedback: MessageSquare,
    framework: Cpu,
    fuel: Fuel,
    gameplay: Car,
    input: Keyboard,
    items: Package,
    interaction: MousePointerClick,
    keys: KeyRound,
    menu: MessageSquare,
    mutations: RotateCcw,
    notify: Bell,
    polyzone: Map,
    prop: Package,
    save: Save,
    server: Server,
    stash: Package,
    target: Crosshair,
    tests: FlaskConical,
    text: Type,
    timer: Timer,
    tools: Wrench,
    vehicle: Car,
    shield: ShieldCheck,
    wrench: Wrench,
    x: X,
    zap: Zap,
  }[String(name).toLowerCase()] || CircleDot;
}

function InputDialog({ data, close, onClose }) {
  const fields = data.fields || [{ name: 'value', label: data.fieldLabel, type: data.type || 'text', value: data.value || '', placeholder: data.placeholder }];
  const [values, setValues] = useState(() => Object.fromEntries(fields.map((field) => [field.name || 'value', field.value ?? ''])));

  useEffect(() => {
    const keydown = (event) => {
      if (event.key === 'Escape') close();
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  }, []);

  const submit = (event) => {
    event.preventDefault();
    postNui('uiSubmit', { id: data.id, values });
    onClose();
  };

  return (
    <div className="bridge-dialog-layer input">
      <form className="input-panel" onSubmit={submit}>
        <div className="bridge-kicker">{data.label || 'Input menu'}</div>
        <h2>{data.title || 'Enter Details'}</h2>
        {data.description && <p>{data.description}</p>}
        <div className="input-fields">
          {fields.map((field, index) => {
            const name = field.name || 'value';
            return <label key={name}><span>{field.label}</span><div className="field-wrap"><input autoFocus={index === 0} type={field.type || 'text'} value={values[name]} placeholder={field.placeholder || ''} min={field.min} max={field.max} onChange={(event) => setValues((current) => ({ ...current, [name]: event.target.value }))} />{field.suffix && <em>{field.suffix}</em>}</div></label>;
          })}
        </div>
        <div className="input-actions"><button type="submit" className="confirm">{data.confirmLabel || 'Confirm'}<Check size={20} /></button><button type="button" onClick={close}>{data.cancelLabel || 'Cancel'}<X size={20} /></button></div>
      </form>
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
      <div className="debug-kicker">Debug menu</div>
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
