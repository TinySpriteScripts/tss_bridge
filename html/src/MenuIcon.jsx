import React, { useState } from 'react';
import {
  Activity, Bell, Box, Car, Check, ChevronRight, Circle, CircleDot, Clipboard, ClipboardCheck, Code2, Cpu,
  Crosshair, FlaskConical, Fuel, ImageOff, KeyRound, Keyboard, Map, MessageSquare,
  MousePointerClick, Package, Play, RotateCcw, Save, Search, Server, Settings,
  ShieldCheck, SquareMousePointer, Timer, Trash2, Type, Wrench, X, Zap,
} from 'lucide-react';

// Images stay in the resource that owns them; the bridge only renders their URL.
export default function MenuIcon({ icon, size = 20 }) {
  const [failedSrc, setFailedSrc] = useState(null);
  const source = typeof icon === 'object' && icon?.type === 'image'
    ? icon.src
    : typeof icon === 'string' && /^(https?:\/\/|nui:\/\/|data:image\/)/i.test(icon) ? icon : null;
  if (source) {
    if (typeof source !== 'string' || failedSrc === source) return <ImageOff size={size} aria-hidden="true" />;
    return <img className="bridge-image-icon" src={source} width={size} height={size}
      alt="" draggable={false} onError={() => setFailedSrc(source)} />;
  }
  if (typeof icon === 'string' && /(?:^|\s)fa(?:s|r|b|l|d|t|-solid|-regular|-brands)?(?:\s|$)/.test(icon)) {
    return <i className={`bridge-font-icon ${icon}`} style={{ width: size, height: size, fontSize: size }} aria-hidden="true" />;
  }
  const Icon = iconFor(typeof icon === 'string' ? icon : null);
  return <Icon size={size} strokeWidth={1.7} aria-hidden="true" />;
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
    ped: CircleDot,
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

