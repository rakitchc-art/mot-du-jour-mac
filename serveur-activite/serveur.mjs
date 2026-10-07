// ===========================================================================
//  serveur-activite — le registre « elle a joué » de Mot du jour.
//
//  Voulu par Dova le 07/10/2026, avec l'accord de Kelly : savoir SI elle se
//  sert de l'appli, rien de plus. L'appli envoie, une fois par jour joué,
//  { "jour": "AAAA-MM-JJ", "version": "x.y.z" } — jamais le mot, ni ses
//  essais, ni son nom. Ce service le note dans un fichier ; personne ne le
//  lit par le web : Claude le lit par SSH quand Dova le demande.
//
//  Il vit sur le VPS (/root/projets/mot-du-jour-activite), derrière nginx :
//  https://retroseance.fr/mot-du-jour/activite → 127.0.0.1:8790/activite.
//  Les épreuves des Mac de GitHub lancent CE MÊME fichier en local.
//
//  L'adresse est publique (le code de l'appli l'est) : n'importe qui peut
//  écrire. D'où : un jour n'est noté qu'UNE fois, dans une fenêtre de dates
//  plausibles, un plafond d'écritures par jour, une taille de fichier
//  plafonnée — et rien de ce qui est noté ne se relit par le web.
//
//  Réglages (variables d'environnement) : MDJ_PORT (8790), MDJ_HOTE
//  (127.0.0.1), MDJ_REGISTRE (./activite.jsonl), MDJ_PLAFOND_JOUR (50).
// ===========================================================================
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const PORT = Number(process.env.MDJ_PORT || 8790);
const HOTE = process.env.MDJ_HOTE || '127.0.0.1';
const REGISTRE = path.resolve(process.env.MDJ_REGISTRE || 'activite.jsonl');
const PLAFOND_JOUR = Number(process.env.MDJ_PLAFOND_JOUR || 50);
const TAILLE_MAX_REGISTRE = 1_000_000;
const TAILLE_MAX_CORPS = 512;

const JOUR_MS = 86_400_000;

// Les jours déjà notés : le fichier fait foi, relu au démarrage.
const notes = new Set();
if (fs.existsSync(REGISTRE)) {
  for (const ligne of fs.readFileSync(REGISTRE, 'utf8').split('\n')) {
    try { const e = JSON.parse(ligne); if (e && typeof e.jour === 'string') notes.add(e.jour); } catch { /* ligne vide ou abîmée */ }
  }
}
let ecrituresDuJour = { jour: '', n: 0 };

function jourUtc(ms) { return new Date(ms).toISOString().slice(0, 10); }

/** Un jour « AAAA-MM-JJ » qui existe, entre 8 jours avant et 2 jours après aujourd'hui (UTC). */
function jourPlausible(jour) {
  if (typeof jour !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(jour)) return false;
  const ms = Date.parse(jour + 'T00:00:00Z');
  if (Number.isNaN(ms) || jourUtc(ms) !== jour) return false;   // 2026-02-30 n'existe pas
  const auj = Date.parse(jourUtc(Date.now()) + 'T00:00:00Z');
  return ms >= auj - 8 * JOUR_MS && ms <= auj + 2 * JOUR_MS;
}

function repondre(res, code, corps) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(corps));
}

const serveur = http.createServer((req, res) => {
  const chemin = (req.url || '').split('?')[0];
  if (chemin === '/sante') return req.method === 'GET' ? repondre(res, 200, { etat: 'ok' }) : repondre(res, 405, { erreur: 'méthode' });
  if (chemin !== '/activite') return repondre(res, 404, { erreur: 'inconnu' });
  if (req.method !== 'POST') return repondre(res, 405, { erreur: 'méthode' });

  let corps = '';
  let trop = false;
  req.setEncoding('utf8');
  req.on('data', (morceau) => {
    if (trop) return;
    corps += morceau;
    if (Buffer.byteLength(corps) > TAILLE_MAX_CORPS) { trop = true; repondre(res, 413, { erreur: 'trop gros' }); req.destroy(); }
  });
  req.on('end', () => {
    if (trop) return;
    let e;
    try { e = JSON.parse(corps); } catch { return repondre(res, 400, { erreur: 'json' }); }
    if (!e || typeof e !== 'object') return repondre(res, 400, { erreur: 'json' });
    if (!jourPlausible(e.jour)) return repondre(res, 400, { erreur: 'jour' });
    if (typeof e.version !== 'string' || !/^\d{1,4}(\.\d{1,5}){0,3}$/.test(e.version)) return repondre(res, 400, { erreur: 'version' });
    if (notes.has(e.jour)) return repondre(res, 200, { etat: 'deja' });

    const aujourdhui = jourUtc(Date.now());
    if (ecrituresDuJour.jour !== aujourdhui) ecrituresDuJour = { jour: aujourdhui, n: 0 };
    if (ecrituresDuJour.n >= PLAFOND_JOUR) return repondre(res, 429, { erreur: 'plafond du jour' });
    let taille = 0;
    try { taille = fs.statSync(REGISTRE).size; } catch { /* pas encore de registre */ }
    if (taille > TAILLE_MAX_REGISTRE) return repondre(res, 507, { erreur: 'registre plein' });

    const ligne = JSON.stringify({ recu: new Date().toISOString(), jour: e.jour, version: e.version }) + '\n';
    try {
      fs.appendFileSync(REGISTRE, ligne);
    } catch (err) {
      console.error('écriture impossible :', err.message);
      return repondre(res, 500, { erreur: 'écriture' });
    }
    notes.add(e.jour);
    ecrituresDuJour.n += 1;
    console.log(`noté : ${e.jour} (version ${e.version})`);
    repondre(res, 201, { etat: 'note' });
  });
});

serveur.listen(PORT, HOTE, () => console.log(`prêt : http://${HOTE}:${PORT}/ — registre ${REGISTRE}`));
