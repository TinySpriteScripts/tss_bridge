/* One theme registry for every integrated NUI and DUI. */
(() => {
  const base = new URL('.', document.currentScript.src);
  let registry, current, selection = 'default';
  const styles = new Set(['studio', 'classic', 'modern-slate', 'modern-glass']);
  function apply() {
    const fallback = registry.themes[registry.defaultTheme];
    const preset = registry.themes[selection] || fallback;
    current = { ...fallback, ...preset };
    const root = document.documentElement;
    root.dataset.uiStyle = styles.has(current.styleVariant) ? current.styleVariant : 'studio';
    root.dataset.themeName = current.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    for (const [key, value] of Object.entries(current)) {
      if (typeof value === 'string' && CSS.supports('color', value)) {
        root.style.setProperty('--' + key.replace(/[A-Z]/g, letter => '-' + letter.toLowerCase()), value);
      }
    }
    window.dispatchEvent(new CustomEvent('tss:theme', { detail: current }));
    return current;
  }
  // TSS.Config.DefaultTheme in shared/config.lua is the source of truth for the default preset.
  async function configuredDefault(themes) {
    const fallback = themes['TinySprite Studio'] ? 'TinySprite Studio' : Object.keys(themes)[0];
    try {
      const response = await fetch(new URL('../shared/config.lua', base), { cache: 'no-store' });
      if (!response.ok) return fallback;
      const match = (await response.text()).match(/^\s*TSS\.Config\.DefaultTheme\s*=\s*(['"])(.*?)\1/m);
      if (!match) return fallback;
      if (themes[match[2]]) return match[2];
      console.warn(`tss_bridge: DefaultTheme "${match[2]}" is not a preset in ui/theme.json; using "${fallback}"`);
    } catch (error) {
      console.warn('tss_bridge: unable to read DefaultTheme from shared/config.lua', error);
    }
    return fallback;
  }
  async function refresh() {
    const response = await fetch(new URL('theme.json', base), { cache: 'no-store' });
    if (!response.ok) throw new Error('Unable to load tss_bridge UI themes');
    const next = await response.json();
    if (!next.themes || !Object.keys(next.themes).length) throw new Error('tss_bridge theme.json has no presets');
    next.defaultTheme = await configuredDefault(next.themes);
    registry = next;
    return apply();
  }
  async function select(name) {
    selection = typeof name === 'string' && name ? name : 'default';
    if (!registry) await window.TSSTheme.ready;
    return apply();
  }
  window.TSSTheme = { select, refresh, get current() { return current; } };
  window.TSSTheme.ready = refresh();
  window.TSSTheme.ready.catch(console.error);
})();
