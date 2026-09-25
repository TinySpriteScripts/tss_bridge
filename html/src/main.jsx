import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  Activity, Bell, Box, Car, Check, ChevronRight, Circle, CircleDot, Clipboard, ClipboardCheck, Code2, Cpu,
  Crosshair, FlaskConical, ImageOff, KeyRound, Keyboard, Map, MessageSquare,
  MousePointerClick, Package, PackagePlus, Play, RotateCcw, Save, Search, Server, Settings,
  ShieldCheck, SquareMousePointer, Timer, Trash2, Type, Wrench, X, Zap,
} from 'lucide-react';
import '@fortawesome/fontawesome-free/css/all.min.css';
import './styles.css';
import MenuIcon from './MenuIcon';

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
  const [pedAnimationEditor, setPedAnimationEditor] = useState(null);
  const [propSceneEditor, setPropSceneEditor] = useState(null);
  const [gizmoOverlay, setGizmoOverlay] = useState(null);
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
      if (data.action === 'pedAnimationEditor') setPedAnimationEditor(data.payload || null);
      if (data.action === 'propSceneEditor') {
        setPropSceneEditor((current) => data.payload
          ? { ...current, ...data.payload, library: data.payload.library || current?.library || [] }
          : null);
      }
      if (data.action === 'gizmoOverlay') setGizmoOverlay(data.payload || null);
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
      {pedAnimationEditor?.visible && <PedAnimationEditorPanel data={pedAnimationEditor} />}
      {propSceneEditor?.visible && <PropSceneEditorPanel data={propSceneEditor} />}
      {gizmoOverlay?.visible && <GizmoOverlay data={gizmoOverlay} />}
      {bridgeLabBrowser?.visible && <BridgeLabBrowser data={bridgeLabBrowser} />}
      {dialog && <BridgeDialog data={dialog} onClose={() => setDialog(null)} />}
      <NoticeStack notices={notices} />
      {progress && <ProgressBar data={progress} />}
    </div>
  );
}

function GizmoOverlay({ data }) {
  const width = window.innerWidth || 1920;
  const height = window.innerHeight || 1080;
  const point = (value) => ({ x: value.x * width, y: value.y * height });
  const color = (handle) => `rgb(${(handle.color || [255, 255, 255]).join(',')})`;

  return <svg className="gizmo-overlay" viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
    <defs>
      <filter id="gizmo-glow" x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="2.2" result="blur" />
        <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
      </filter>
    </defs>
    {(data.handles || []).map((handle) => {
      const stroke = color(handle);
      const className = `gizmo-handle ${handle.active ? 'active' : ''}`;
      if (handle.kind === 'ring') {
        const points = (handle.points || []).map(point).map((p) => `${p.x},${p.y}`).join(' ');
        return <polyline key={handle.id} className={`${className} gizmo-ring`} points={points} stroke={stroke} />;
      }
      if (handle.kind === 'axis') {
        const start = point(handle.origin);
        const end = point(handle.position);
        const dx = end.x - start.x;
        const dy = end.y - start.y;
        const magnitude = Math.max(Math.hypot(dx, dy), 0.001);
        const ux = dx / magnitude;
        const uy = dy / magnitude;
        const head = handle.active ? 19 : 15;
        const wing = handle.active ? 8 : 6.5;
        const base = { x: end.x - ux * head, y: end.y - uy * head };
        const arrow = `${end.x},${end.y} ${base.x - uy * wing},${base.y + ux * wing} ${base.x + uy * wing},${base.y - ux * wing}`;
        return <g key={handle.id} className={className} filter={handle.active ? 'url(#gizmo-glow)' : undefined}>
          <line className="gizmo-axis" x1={start.x} y1={start.y} x2={handle.shape === 'cube' ? end.x : base.x} y2={handle.shape === 'cube' ? end.y : base.y} stroke={stroke} />
          {handle.shape === 'cube'
            ? <rect className="gizmo-cube" x={end.x - (handle.active ? 8 : 6)} y={end.y - (handle.active ? 8 : 6)} width={handle.active ? 16 : 12} height={handle.active ? 16 : 12} fill={stroke} />
            : <polygon className="gizmo-arrow" points={arrow} fill={stroke} />}
        </g>;
      }
      const position = point(handle.position);
      return <circle key={handle.id} className={className} cx={position.x} cy={position.y} r={handle.active ? 8 : 6} fill={stroke} />;
    })}
    {data.handles?.find((handle) => handle.kind === 'axis') && (() => {
      const center = point(data.handles.find((handle) => handle.kind === 'axis').origin);
      return <circle className="gizmo-center" cx={center.x} cy={center.y} r="4.5" />;
    })()}
  </svg>;
}

function useAnimationCatalog(dictionary, enabled = true) {
  const [catalog, setCatalog] = useState({ dictionaries: [], clips: [], exact: false, loading: false });

  useEffect(() => {
    const query = String(dictionary || '').trim();
    if (!enabled || !query) {
      setCatalog({ dictionaries: [], clips: [], exact: false, loading: false });
      return undefined;
    }

    let cancelled = false;
    setCatalog((current) => ({ ...current, loading: true }));
    const timer = window.setTimeout(async () => {
      try {
        const response = await postNui('pedAnimationSearch', { query });
        const result = await response?.json();
        if (!cancelled) {
          setCatalog({
            dictionaries: Array.isArray(result?.dictionaries) ? result.dictionaries : [],
            clips: Array.isArray(result?.clips) ? result.clips : [],
            exact: result?.exact === true,
            loading: false,
          });
        }
      } catch {
        if (!cancelled) setCatalog({ dictionaries: [], clips: [], exact: false, loading: false });
      }
    }, 120);

    return () => { cancelled = true; window.clearTimeout(timer); };
  }, [dictionary, enabled]);

  return catalog;
}

function AnimationDictionaryField({ value, onChange, autoFocus = false, required = false, placeholder = '' }) {
  const catalog = useAnimationCatalog(value);
  const [open, setOpen] = useState(false);
  const [highlighted, setHighlighted] = useState(0);
  const suggestions = catalog.dictionaries;

  useEffect(() => setHighlighted(0), [value, suggestions.length]);

  const choose = (dictionary) => {
    onChange(dictionary);
    setOpen(false);
  };
  const keyDown = (event) => {
    if (!open || suggestions.length === 0) return;
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setHighlighted((current) => (current + 1) % suggestions.length);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setHighlighted((current) => (current - 1 + suggestions.length) % suggestions.length);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      choose(suggestions[highlighted]);
    } else if (event.key === 'Escape') {
      setOpen(false);
    }
  };

  return <div className="animation-dictionary-picker">
    <input
      autoComplete="off"
      autoFocus={autoFocus}
      required={required}
      value={value || ''}
      placeholder={placeholder}
      onFocus={() => setOpen(true)}
      onBlur={() => window.setTimeout(() => setOpen(false), 100)}
      onKeyDown={keyDown}
      onChange={(event) => { onChange(event.target.value); setOpen(true); }}
    />
    {open && String(value || '').trim() && suggestions.length > 0 && <div className="animation-dictionary-results">
      {suggestions.map((dictionary, index) => <button
        type="button"
        className={index === highlighted ? 'highlighted' : ''}
        key={dictionary}
        onMouseDown={(event) => event.preventDefault()}
        onMouseEnter={() => setHighlighted(index)}
        onClick={() => choose(dictionary)}
      >{dictionary}</button>)}
    </div>}
    {open && String(value || '').trim() && !catalog.loading && suggestions.length === 0 && <small className="animation-catalog-empty">No dictionaries contain that text.</small>}
    {catalog.loading && <small className="animation-catalog-status">Searching animation dictionaries...</small>}
  </div>;
}

function AnimationClipField({ dictionary, value, onChange, autoFocus = false, required = false, placeholder = '' }) {
  const catalog = useAnimationCatalog(dictionary);
  if (catalog.exact) {
    return <select autoFocus={autoFocus} required={required} value={value || ''} onChange={(event) => onChange(event.target.value)}>
      <option value="">Select a clip...</option>
      {catalog.clips.map((clip) => <option value={clip} key={clip}>{clip}</option>)}
    </select>;
  }
  return <input
    autoFocus={autoFocus}
    required={required}
    value={value || ''}
    placeholder={dictionary ? 'Select an exact dictionary first' : placeholder}
    onChange={(event) => onChange(event.target.value)}
  />;
}

function PedAnimationEditorPanel({ data }) {
  const [pose, setPose] = useState(data.pose || {});
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => { if (data.settingsOpen) { setPose(data.pose || {}); setError(''); } }, [data.settingsOpen]);
  const send = async (action) => {
    setBusy(true);
    try {
      const response = await postNui('pedAnimationAction', { action, ...pose });
      const result = await response?.json();
      setError(result?.ok ? '' : result?.error || 'Editor did not respond.');
    } catch { setError('Unable to update pose.'); }
    finally { setBusy(false); }
  };
  return <section className={`zone-creator-panel ped-animation-panel ${data.settingsOpen ? 'settings-open' : ''}`}>
    <div className="zone-creator-accent" />
    <header><div><span>{data.title || 'Ped Animation Editor'}</span><h2>{data.model || 'Ped placement'}</h2></div><div className="zone-mode"><Crosshair size={14} />{data.mode || 'MOVE'}</div></header>
    <div className="zone-type">{data.behaviour}<strong>{data.count || 0} placed</strong></div>
    <div className="zone-metrics">{(data.metrics || []).map((metric) => <div key={metric.label}><span>{metric.label}</span><strong>{metric.value}</strong></div>)}</div>
    {data.message && <div className="zone-message">{data.message}</div>}
    {data.settingsOpen && <div className="attachment-settings">
      <p>Animation overrides scenario. Clear both animation fields to use a scenario.</p>
      <label><span>Scenario</span><input value={pose.scenario || ''} onChange={(e) => setPose({ ...pose, scenario: e.target.value })} /></label>
      <label><span>Animation dictionary</span><AnimationDictionaryField value={pose.dict || ''} onChange={(dict) => setPose({ ...pose, dict, clip: '' })} /></label>
      <label><span>Animation clip</span><AnimationClipField dictionary={pose.dict || ''} value={pose.clip || ''} onChange={(clip) => setPose({ ...pose, clip })} /></label>
      <label><span>Animation flag (1 = full-body loop)</span><input type="number" min="0" max="51" value={pose.flag ?? 1} onChange={(e) => setPose({ ...pose, flag: e.target.value })} /></label>
      {error && <div className="zone-message" role="alert">{error}</div>}
      <div className="attachment-actions">
        <button disabled={busy} onClick={() => send('apply')}>Apply / replay pose</button>
        <button disabled={busy} onClick={() => send('resume')}>Resume gizmo</button>
      </div>
      <div className="attachment-actions">
        <button className="done" disabled={busy || !(data.count > 0)} onClick={() => send('save')}>Save file</button>
        <button disabled={busy} onClick={() => send('export')}>Print / copy Lua</button>
        <button disabled={busy} onClick={() => send('clear')}>Clear placed peds</button>
      </div>
      {data.output && <><textarea className="ped-pose-output" aria-label="Exported Lua placements" value={data.output} readOnly /><CopyButton value={data.output} label="Copy Lua" /></>}
      <button className="ped-editor-exit" disabled={busy} onClick={() => send('exit')}>Exit editor</button>
    </div>}
    <div className="zone-help">{(data.help || []).map((line) => <p key={line}><MousePointerClick size={13} />{line}</p>)}</div>
  </section>;
}

function PropSceneEditorPanel({ data }) {
  const [model, setModel] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(null);
  const [values, setValues] = useState({ x: '', y: '', z: '' });
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All');
  const [dragged, setDragged] = useState(null);
  const categories = useMemo(() => ['All', ...new Set((data.library || []).map((item) => item.category))], [data.library]);
  const libraryItems = useMemo(() => (data.library || []).filter((item) => {
    const query = search.trim().toLowerCase();
    return (category === 'All' || item.category === category)
      && (!query || item.model.toLowerCase().includes(query) || item.label.toLowerCase().includes(query));
  }), [data.library, search, category]);
  useEffect(() => { if (data.settingsOpen) setError(''); }, [data.settingsOpen]);
  useEffect(() => {
    if (!data.settingsOpen) return undefined;
    const keydown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        postNui('propSceneAction', { action: 'resume' });
      }
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  }, [data.settingsOpen]);
  useEffect(() => {
    if (!data.libraryOpen) return undefined;
    const keydown = (event) => {
      if (event.key === 'F5') {
        event.preventDefault();
        postNui('propSceneAction', { action: 'toggleLibrary' });
      }
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  }, [data.libraryOpen]);
  const send = async (action, payload = {}) => {
    setBusy(true);
    let result;
    try {
      const response = await postNui('propSceneAction', { action, ...payload });
      result = await response?.json();
      setError(result?.ok ? '' : result?.error || 'Editor did not respond.');
      if (result?.ok && action === 'add') setModel('');
    } catch { setError('Unable to update the scene.'); }
    finally { setBusy(false); }
    return result;
  };
  const editMetric = (metric) => {
    setEditing(metric.key);
    setValues({ x: metric.components?.x ?? '', y: metric.components?.y ?? '', z: metric.components?.z ?? '' });
  };
  const applyMetric = async () => {
    const result = await send('transform', { kind: editing, ...values });
    if (result?.ok) setEditing(null);
  };
  const dropProp = async (event) => {
    event.preventDefault();
    const item = dragged;
    setDragged(null);
    if (!item) return;
    await send('libraryDrop', {
      model: item.model,
      screenX: event.clientX / window.innerWidth,
      screenY: event.clientY / window.innerHeight,
    });
  };
  return <>
  <section className={`zone-creator-panel ped-animation-panel prop-scene-panel ${data.settingsOpen ? 'settings-open' : ''}`}>
    <div className="zone-creator-accent" />
    <header><div><span>{data.title || 'Prop Scene Editor'}</span><h2>{data.sceneName || 'Prop scene'}</h2></div><div className="zone-mode"><Box size={14} />{data.mode || 'MOVE'}</div></header>
    <div className="zone-type"><span>{data.activeModel || 'No active prop'}</span><strong>{data.activeIndex || 0} / {data.count || 0}</strong></div>
    <div className="zone-metrics prop-scene-metrics">{(data.metrics || []).map((metric) => <button type="button" key={metric.label} onClick={() => editMetric(metric)}><span>{metric.label}</span><strong>{metric.value}</strong></button>)}</div>
    {editing && <div className="prop-transform-editor">
      <strong>{editing === 'coords' ? 'Position' : editing === 'rotation' ? 'Rotation' : 'Scale'}</strong>
      {['x', 'y', 'z'].map((axis) => <label key={axis}><span>{axis.toUpperCase()}</span><input type="number" step={editing === 'rotation' ? '1' : '0.01'} value={values[axis]} onFocus={() => postNui('propSceneAction', { action: 'uiFocus', focused: true })} onBlur={() => postNui('propSceneAction', { action: 'uiFocus', focused: false })} onChange={(event) => setValues({ ...values, [axis]: event.target.value })} /></label>)}
      <button disabled={busy} onClick={applyMetric}>Apply</button><button disabled={busy} onClick={() => setEditing(null)}>Cancel</button>
    </div>}
    {data.message && <div className="zone-message">{data.message}</div>}
    {data.settingsOpen && <div className="attachment-settings prop-scene-settings">
      <p>Add, select, duplicate, or remove props. Resume the gizmo to continue arranging the scene.</p>
      <label><span>Add prop model</span><div className="prop-scene-add"><input autoFocus value={model} placeholder="prop model name" onChange={(event) => setModel(event.target.value)} /><button disabled={busy || !model.trim()} onClick={() => send('add', { model })}>Add</button></div></label>
      <div className="prop-scene-list">{(data.props || []).map((prop) => <button className={prop.index === data.activeIndex ? 'active' : ''} disabled={busy} key={`${prop.index}-${prop.model}`} onClick={() => send('select', { index: prop.index })}><span>{prop.index}</span><strong>{prop.model}</strong></button>)}</div>
      {error && <div className="zone-message" role="alert">{error}</div>}
      <div className="attachment-actions">
        <button disabled={busy} onClick={() => send('duplicate')}>Duplicate active</button>
        <button disabled={busy || data.count <= 1} onClick={() => send('delete')}>Delete active</button>
        <button disabled={busy} onClick={() => send('resume')}>Resume gizmo</button>
      </div>
      <div className="attachment-actions">
        <button className="done" disabled={busy || !(data.count > 0)} onClick={() => send('save')}>Save scene file</button>
        <button disabled={busy} onClick={() => send('export')}>Generate Lua</button>
      </div>
      {data.output && <><textarea className="ped-pose-output" aria-label="Exported Lua prop scene" value={data.output} readOnly /><CopyButton value={data.output} label="Copy scene Lua" /></>}
      <button className="ped-editor-exit" disabled={busy} onClick={() => send('exit')}>Exit editor</button>
    </div>}
    <div className="zone-help">{(data.help || []).map((line) => <p key={line}><MousePointerClick size={13} />{line}</p>)}</div>
  </section>
  {data.libraryOpen && <section className="prop-library">
    <header><div><span>F5 PROP LIBRARY</span><strong>Drag a prop into the world or click to add beside the selection</strong></div><input value={search} placeholder="Search models..." onFocus={() => postNui('propSceneAction', { action: 'uiFocus', focused: true })} onBlur={() => postNui('propSceneAction', { action: 'uiFocus', focused: false })} onChange={(event) => setSearch(event.target.value)} /></header>
    <nav>{categories.map((name) => <button className={category === name ? 'active' : ''} key={name} onClick={() => setCategory(name)}>{name}</button>)}</nav>
    <div className="prop-library-grid">{libraryItems.map((item) => <button
      draggable
      key={item.model}
      onDragStart={(event) => { event.dataTransfer.setData('text/plain', item.model); setDragged(item); }}
      onDragEnd={() => setDragged(null)}
      onClick={() => send('libraryAdd', { model: item.model })}
    ><Box size={18} /><span>{item.label}</span><code>{item.model}</code></button>)}</div>
  </section>}
  {dragged && <div className="prop-library-drop-layer" onDragOver={(event) => event.preventDefault()} onDrop={dropProp}><span>Drop {dragged.label} into the scene</span></div>}
  </>;
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

function SpawnItemButton({ item }) {
  const [state, setState] = useState('idle');

  useEffect(() => setState('idle'), [item]);

  const spawn = async () => {
    if (state === 'loading') return;
    setState('loading');
    try {
      const response = await postNui('bridgeLabBrowserSpawnItem', { item });
      const result = await response?.json();
      setState(result?.success ? 'success' : 'error');
    } catch {
      setState('error');
    }
    window.setTimeout(() => setState('idle'), 1400);
  };

  const label = state === 'loading' ? 'Spawning...' : state === 'success' ? 'Spawned' : state === 'error' ? 'Failed' : 'Spawn item';
  return <button type="button" className={`browser-spawn ${state}`} onClick={spawn} disabled={state === 'loading'}><PackagePlus size={13} />{label}</button>;
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
        <div className="item-heading"><ItemImage item={selected} /><div><span>Shared item definition</span><h2>{selected.label}</h2><code>{selected.name}</code></div><div className="item-heading-actions"><CopyButton value={selected.name} label="Copy item code" /><SpawnItemButton item={selected.name} /></div></div>
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
    <footer><kbd>ESC</kbd><span>Return to Developer Tools</span><i>{data.kind === 'items' ? 'Spawn grants one item to your inventory through the secured server callback' : 'Click any copy button to place its exact value on your clipboard'}</i></footer>
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

              return (
                <button
                  className={`bridge-option ${selected === index ? 'selected' : ''}`}
                  disabled={option.disabled}
                  key={option.id || `${option.label}-${index}`}
                  onMouseEnter={() => setSelected(index)}
                  onClick={() => choose(index)}
                >
                  <MenuIcon icon={option.icon} size={20} />
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
              <div className="preview-icon"><MenuIcon icon={selectedOption.icon} size={30} /></div>
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
            let control;
            if (field.type === 'select') {
              control = <select autoFocus={index === 0} required={field.required} value={values[name]} onChange={(event) => setValues((current) => ({ ...current, [name]: event.target.value }))}><option value="" disabled>Select...</option>{(field.options || []).map((option) => <option key={option.value} value={option.value}>{option.label || option.text || option.value}</option>)}</select>;
            } else if (field.type === 'animation-dict') {
              control = <AnimationDictionaryField
                autoFocus={index === 0}
                required={field.required}
                value={values[name]}
                placeholder={field.placeholder || ''}
                onChange={(dict) => setValues((current) => ({ ...current, [name]: dict, [field.clipField || 'clip']: '' }))}
              />;
            } else if (field.type === 'animation-clip') {
              control = <AnimationClipField
                autoFocus={index === 0}
                required={field.required}
                dictionary={values[field.dictField || 'dict']}
                value={values[name]}
                placeholder={field.placeholder || ''}
                onChange={(clip) => setValues((current) => ({ ...current, [name]: clip }))}
              />;
            } else {
              control = <input autoFocus={index === 0} required={field.required} step={field.step} type={field.type || 'text'} value={values[name]} placeholder={field.placeholder || ''} min={field.min} max={field.max} onChange={(event) => setValues((current) => ({ ...current, [name]: event.target.value }))} />;
            }
            return <label key={name}><span>{field.label}</span><div className="field-wrap">{control}{field.suffix && <em>{field.suffix}</em>}</div></label>;
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
