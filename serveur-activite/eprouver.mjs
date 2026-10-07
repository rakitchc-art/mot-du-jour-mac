// Éprouve serveur.mjs pour de vrai : lancé à part (port et registre jetables),
// interrogé par HTTP, puis le REGISTRE relu sur le disque — c'est lui qui
// compte, pas les réponses. Usage : node serveur-activite/eprouver.mjs
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ici = path.dirname(fileURLToPath(import.meta.url));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mdj-activite-'));
const registre = path.join(tmp, 'activite.jsonl');
const PORT = 18790;
const base = `http://127.0.0.1:${PORT}`;
let echecs = 0;
function verifier(ok, quoi) { console.log(`  ${ok ? '✓' : '✗'} ${quoi}`); if (!ok) echecs++; }
const jour = (decalage) => new Date(Date.now() + decalage * 86_400_000).toISOString().slice(0, 10);
const lignes = () => (fs.existsSync(registre) ? fs.readFileSync(registre, 'utf8').trim().split('\n').filter(Boolean) : []);

function lancer() {
  const p = spawn(process.execPath, [process.env.MDJ_SERVEUR || path.join(ici, 'serveur.mjs')], {
    env: { ...process.env, MDJ_PORT: String(PORT), MDJ_REGISTRE: registre, MDJ_PLAFOND_JOUR: '3' }, stdio: 'pipe',
  });
  return new Promise((ok, ko) => {
    p.stdout.on('data', (d) => { if (String(d).includes('prêt')) ok(p); });
    p.on('exit', (c) => ko(new Error('serveur arrêté : ' + c)));
    setTimeout(() => ko(new Error('serveur muet')), 5000);
  });
}
async function poster(corps, chemin = '/activite', methode = 'POST') {
  const r = await fetch(base + chemin, { method: methode, body: methode === 'POST' ? corps : undefined,
    headers: { 'Content-Type': 'application/json' } });
  return r.status;
}

let serveur = await lancer();
try {
  verifier((await fetch(base + '/sante')).status === 200, 'santé : 200');
  verifier(await poster(JSON.stringify({ jour: jour(0), version: '1.0.4' })) === 201, 'un jour joué : 201');
  verifier(await poster(JSON.stringify({ jour: jour(0), version: '1.0.4' })) === 200, 'le même jour : 200 (déjà noté)');
  verifier(lignes().length === 1, 'le même jour deux fois = UNE ligne au registre');
  verifier(await poster(JSON.stringify({ jour: jour(-3), version: '1.0.4' })) === 201, 'un jour récent rattrapé : 201');
  verifier(await poster(JSON.stringify({ jour: jour(-30), version: '1.0.4' })) === 400, 'un jour d\'il y a 30 jours : 400');
  verifier(await poster(JSON.stringify({ jour: jour(5), version: '1.0.4' })) === 400, 'un jour dans 5 jours : 400');
  verifier(await poster(JSON.stringify({ jour: '2026-02-30', version: '1.0.4' })) === 400, 'un jour qui n\'existe pas : 400');
  verifier(await poster(JSON.stringify({ jour: jour(0), version: '<script>' })) === 400, 'une version fantaisiste : 400');
  verifier(await poster('pas du json') === 400, 'pas du JSON : 400');
  verifier(await poster(JSON.stringify({ jour: jour(-1), version: '1', bourrage: 'x'.repeat(2000) })) === 413, 'un corps trop gros : 413');
  verifier(await poster('', '/activite', 'GET') === 405, 'lire par le web : 405');
  verifier(await poster(JSON.stringify({ jour: jour(-1), version: '1.0.4' }), '/autre') === 404, 'une autre adresse : 404');
  verifier(await poster(JSON.stringify({ jour: jour(-1), version: '1.0.4' })) === 201, 'troisième jour : 201');
  verifier(await poster(JSON.stringify({ jour: jour(-2), version: '1.0.4' })) === 429, 'au-delà du plafond du jour (3) : 429');
  const l = lignes().map((x) => JSON.parse(x));
  verifier(l.length === 3, `registre : 3 lignes (${l.length})`);
  verifier(l.every((e) => Object.keys(e).join(',') === 'recu,jour,version'), 'chaque ligne : recu, jour, version — et rien d\'autre');

  // Redémarré, il se souvient (le fichier fait foi).
  serveur.kill(); await new Promise((r) => setTimeout(r, 300));
  serveur = await lancer();
  verifier(await poster(JSON.stringify({ jour: jour(0), version: '1.0.4' })) === 200, 'après redémarrage, le jour déjà noté : 200');
  verifier(lignes().length === 3, 'après redémarrage : toujours 3 lignes');
} catch (e) {
  console.log('  ✗ ' + e.message); echecs++;
} finally {
  serveur.kill();
  fs.rmSync(tmp, { recursive: true, force: true });
}
console.log(echecs ? `${echecs} contrôle(s) en échec` : 'serveur-activite : tout est vert');
process.exit(echecs ? 1 : 0);
