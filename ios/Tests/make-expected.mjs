// Erzeugt expected.json: Soll-Werte, berechnet mit dem echten Code aus index.html.
// Der Swift-Test (main.swift) vergleicht die App-Logik damit.
//   node ios/Tests/make-expected.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, '..', '..', 'index.html'), 'utf8');

// Ein Stück Quelltext zwischen zwei Markierungen ausschneiden (Ende nicht mit enthalten)
const cut = (from, to) => {
  const a = html.indexOf(from), b = html.indexOf(to, a);
  if (a < 0 || b < 0) throw new Error('Stelle nicht gefunden: ' + from + ' … ' + to);
  return html.slice(a, b);
};
const one = re => { const m = html.match(re); if (!m) throw new Error('Nicht gefunden: ' + re); return m[1]; };

const source = [
  'let spd = 50, base = [255, 0, 0], ch = {}, sent = [];',
  'const $ = () => ({ value: spd });',
  'const GAP = 0, sleep = async () => {};',
  'const write = async bytes => { sent.push(bytes); };',
  cut('const cmd = {', '// --- Senden ---'),
  cut('const ctrl = new Map();', 'async function write'),
  cut('function pump() {', 'const sendCtrl'),
  cut('const TAU', 'const refreshLive'),
  'FLOWS.forEach(f => { if (f.stops) f.at = palette(f.stops); });',
  cut('const period =', 'function startFlow'),
  cut('const WHITES', 'dragBar('),
  'const hueBar = ' + one(/dragBar\(\$\('hue'\), (.*)\);/) + ';',
  'const whiteBar = ' + one(/dragBar\(\$\('white'\), (.*)\);/) + ';',
  `
  const out = { hsv: [], hue: [], mix: [], flows: [], period: [], hueBar: [], whiteBar: [], commands: [], queue: [] };
  const colors = [[255,0,0],[0,255,0],[0,0,255],[255,255,255],[0,0,0],[255,147,41],[12,200,90],[138,43,226],[255,0,200],[1,2,3],[90,90,90],[255,210,63]];

  for (let i = 0; i <= 72; i++) out.hsv.push({ h: i * 5, s: 1, v: 1, out: hsv(i * 5, 1, 1) });
  for (const [s, v] of [[0.5, 1], [1, 0.4], [0.25, 0.8], [0, 1]]) for (let h = 0; h < 360; h += 37) out.hsv.push({ h, s, v, out: hsv(h, s, v) });
  for (const c of colors) out.hue.push({ rgb: c, out: hueOf(c) });
  for (const a of colors) for (const b of colors) for (const e of [0, 0.13, 0.5, 0.77, 1]) out.mix.push({ a, b, e, out: mix(a, b, e) });
  for (const f of FLOWS) for (const b of [[255,0,0],[12,200,90],[255,255,255]]) {
    base = b;
    for (let i = 0; i < 101; i++) { const t = i / 101; out.flows.push({ id: f.id, rate: f.rate || 1, base: b, t, out: f.at(t) }); }
  }
  for (let v = 0; v <= 100; v += 5) { spd = v; out.period.push({ speed: v, out: period() }); }
  for (let i = 0; i <= 40; i++) { const f = i / 40; out.hueBar.push({ f, out: hueBar(f) }); out.whiteBar.push({ f, out: whiteBar(f) }); }

  out.commands.push({ name: 'on', args: [], out: cmd.on() }, { name: 'off', args: [], out: cmd.off() });
  for (const c of colors) out.commands.push({ name: 'color', args: c, out: cmd.color(...c) });
  for (const p of [0, 1, 37, 50, 100]) out.commands.push({ name: 'bright', args: [p], out: cmd.bright(p) }, { name: 'speed', args: [p], out: cmd.speed(p) });
  for (const e of [0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x95]) out.commands.push({ name: 'effect', args: [e], out: cmd.effect(e) });

  // Warteschlange: jede Gruppe wird erst komplett eingereiht, dann leert pump() sie
  const C = c => ({ color: c }), K = (key, bytes) => ({ key, bytes });
  const scenarios = [
    [[C([1,2,3]), C([4,5,6]), C([7,8,9])]],
    [[C([9,9,9]), K('power', cmd.on()), K('bright', cmd.bright(40)), K('power', cmd.off()), C([1,1,1])]],
    [[C([5,5,5])], [C([5,5,5])], [C([6,6,6])], [C([5,5,5])]],
    [[C([5,5,5])], [K('bright', cmd.bright(10))], [C([5,5,5])]],
    [[K('effect', cmd.effect(0x87)), K('speed', cmd.speed(20)), K('speed', cmd.speed(80)), K('effect', cmd.effect(0x95))], [C([0,0,0])], [K('power', cmd.off())]],
    [[K('bright', cmd.bright(1)), C([255,0,0]), K('bright', cmd.bright(2)), C([0,255,0]), K('bright', cmd.bright(3)), C([0,0,255])], [C([0,0,255])], [C([0,0,254])]],
  ];
  const done = (async () => {
    for (const batches of scenarios) {
      ctrl.clear(); frame = null; lastSent = ''; sent = [];
      for (const batch of batches) {
        for (const op of batch) { if (op.color) frame = op.color; else ctrl.set(op.key, op.bytes); }
        pump();
        await new Promise(r => setTimeout(r, 5));
        if (pumping) throw new Error('pump läuft noch');
      }
      out.queue.push({ batches, out: sent });
    }
    return out;
  })();
  done;
  `,
].join('\n');

const result = await vm.runInNewContext(source, { setTimeout, Math, console });
const file = join(here, 'expected.json');
writeFileSync(file, JSON.stringify(result) + '\n');
console.log('geschrieben:', file, Object.entries(result).map(([k, v]) => k + '=' + v.length).join(' '));
