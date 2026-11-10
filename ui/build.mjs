import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { transform, build } from '../html/node_modules/esbuild/lib/main.js';

const source = await readFile(new URL('./src/components.jsx', import.meta.url), 'utf8');
const { code } = await transform(source, {
  loader: 'jsx', jsxFactory: 'React.createElement', jsxFragment: 'React.Fragment', target: 'es2020'
});
await writeFile(new URL('./components.js', import.meta.url), '// Generated from ui/src/components.jsx.\n' + code);

await build({
  entryPoints: [fileURLToPath(new URL('./src/runtime.js', import.meta.url))],
  outfile: fileURLToPath(new URL('./runtime.js', import.meta.url)),
  bundle: true, minify: true, format: 'iife', target: 'es2020',
  define: { 'process.env.NODE_ENV': '"production"' }, legalComments: 'eof'
});

await writeFile(new URL('./runtime-LICENSE.txt', import.meta.url),
  await readFile(new URL('../html/node_modules/react/LICENSE', import.meta.url), 'utf8'));
