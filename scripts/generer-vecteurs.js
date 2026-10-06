#!/usr/bin/env node
// ===========================================================================
//  generer-vecteurs.js — fabrique Tests/MotDuJourCoreTests/vecteurs.json :
//  les réponses de RÉFÉRENCE que les tests Swift doivent retrouver.
//
//  1. couleurs   la fonction `couleursDe` du VRAI serveur TokenBar, extraite
//                du fichier (pas recopiée) et exécutée à part : le jeu Mac
//                doit colorer exactement comme celui de Dova et Nisse.
//  2. ordre      le mot du jour de quelques dates, calculé ici par une SECONDE
//                implémentation (crypto de Node) de la règle de l'appli —
//                elle attrape une erreur de date ou de HMAC côté Swift.
//  3. signature  une signature Ed25519 faite par Node, que CryptoKit doit
//                accepter, et refuser une fois abîmée : c'est le chemin des
//                mises à jour (le workflow signe avec Node, l'appli vérifie).
//
//  Usage : node scripts/generer-vecteurs.js [chemin de echecs-serveur.js]
//  Outil de fabrication : rien de ce fichier ne part dans l'appli.
// ===========================================================================
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

const racine = path.join(__dirname, '..');
const serveur = process.argv[2] || path.join(racine, '..', 'token-bar', 'serveur', 'echecs-serveur.js');
const motsLexique = path.join(racine, 'Sources', 'MotDuJourCore', 'MotsLexique.swift');
const motsGrammalecte = path.join(racine, 'Sources', 'MotDuJourCore', 'MotsGrammalecte.swift');
const sortie = path.join(racine, 'Tests', 'MotDuJourCoreTests', 'vecteurs.json');

// --- 1. la fonction du serveur, extraite telle quelle -----------------------
function extraireFonction(source, nom) {
  const debut = source.indexOf('function ' + nom + '(');
  if (debut < 0) throw new Error('fonction introuvable dans le serveur : ' + nom);
  const ouvre = source.indexOf('{', debut);
  let profondeur = 0;
  for (let i = ouvre; i < source.length; i++) {
    if (source[i] === '{') profondeur++;
    else if (source[i] === '}') { profondeur--; if (profondeur === 0) return source.slice(debut, i + 1); }
  }
  throw new Error('fin de fonction introuvable : ' + nom);
}

const codeServeur = fs.readFileSync(serveur, 'utf8');
const ctx = {};
vm.createContext(ctx);
vm.runInContext(extraireFonction(codeServeur, 'couleursDe') + '\nthis.couleursDe = couleursDe;', ctx);
const couleursDe = ctx.couleursDe;

// L'extraction se prouve sur trois cas connus avant de servir d'oracle.
// (Calculés à la main. Le troisième était faux au premier jet — « jgvgv » :
// le premier e paie le seul jaune disponible, le r aussi — et c'est ce
// contrôle qui l'a dit.)
const temoins = [['plume', 'plume', 'vvvvv'], ['salut', 'plume', 'ggjjg'], ['eerie', 'creme', 'jgjgv']];
for (const [e, s, attendu] of temoins) {
  if (couleursDe(e, s) !== attendu) throw new Error('couleursDe extraite fausse sur ' + e + '/' + s + ' : ' + couleursDe(e, s));
}

// --- les listes de l'APPLI (MotsLexique.swift, MotsGrammalecte.swift) --------
function lireListe(texte, nom) {
  const m = texte.match(new RegExp('let ' + nom + ' = """\\n([\\s\\S]*?)\\n"""'));
  if (!m) throw new Error('liste introuvable dans les fichiers de mots : ' + nom);
  return m[1].split('\n').filter(function (x) { return /^[a-z]{5}$/.test(x); });
}
const texteLexique = fs.readFileSync(motsLexique, 'utf8');
const solutions = lireListe(texteLexique, 'listeSolutionsBrut');
const acceptes = lireListe(texteLexique, 'listeAcceptesLexiqueBrut')
  .concat(lireListe(fs.readFileSync(motsGrammalecte, 'utf8'), 'listeAcceptesGrammalecteBrut'));

// Tirage reproductible : le fichier ne change pas d'une génération à l'autre.
function mulberry32(graine) {
  return function () {
    graine |= 0; graine = (graine + 0x6D2B79F5) | 0;
    let t = Math.imul(graine ^ (graine >>> 15), 1 | graine);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const hasard = mulberry32(20261006);
const tirer = function (liste) { return liste[Math.floor(hasard() * liste.length)]; };
const motAuHasard = function (alphabet) {
  let s = ''; for (let i = 0; i < 5; i++) s += alphabet[Math.floor(hasard() * alphabet.length)]; return s;
};

const couleurs = [];
const paires = new Set();
function ajouter(essai, solution) {
  const cle = essai + '/' + solution;
  if (paires.has(cle)) return;
  paires.add(cle);
  couleurs.push({ essai: essai, solution: solution, couleurs: couleursDe(essai, solution) });
}
// Les cas des lettres répétées, écrits à la main.
for (const [e, s] of [['aaaaa', 'abaca'], ['abaca', 'aaaaa'], ['eerie', 'creme'], ['allee', 'lapin'],
                      ['sasse', 'essai'], ['essai', 'sasse'], ['mamma', 'maman'], ['tutti', 'tutti'],
                      ['abcde', 'edcba'], ['level', 'lever'], ['nanan', 'annan']]) ajouter(e, s);
// De vrais mots : une solution contre un essai accepté.
for (let i = 0; i < 2000; i++) ajouter(tirer(acceptes), tirer(solutions));
// Un petit alphabet : les doublons à foison.
for (let i = 0; i < 1000; i++) ajouter(motAuHasard('aabe'), motAuHasard('aabe'));

// --- 2. l'ordre des mots du jour, par une seconde implémentation -------------
const CLE_ORDRE = 'mot-du-jour-mac';
const ORIGINE = '2026-09-01';
const ordre = solutions.map(function (m) {
  return { mot: m, e: crypto.createHmac('sha256', CLE_ORDRE).update(m).digest('hex') };
}).sort(function (a, b) { return a.e < b.e ? -1 : a.e > b.e ? 1 : 0; }).map(function (x) { return x.mot; });

function numero(jour) {
  const [a, m, j] = jour.split('-').map(Number);
  return Math.round(Date.UTC(a, m - 1, j) / 86400000);
}
const dates = ['2026-09-01', '2026-08-31', '2026-10-06', '2026-10-25', '2026-03-29', '2026-12-31',
               '2027-01-01', '2028-02-29', '2028-03-01', '2030-06-15', '2020-01-01', '2099-12-31'];
const motsDuJour = dates.map(function (jour) {
  const i = numero(jour) - numero(ORIGINE), n = ordre.length;
  return { jour: jour, numero: numero(jour), mot: ordre[((i % n) + n) % n] };
});

// --- 3. une signature Ed25519 de Node, pour CryptoKit -------------------------
const paire = crypto.generateKeyPairSync('ed25519');
const brutePublique = paire.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
const message = Buffer.from('Mot du jour : une archive de mise a jour, octet pour octet.', 'utf8');
const signature = crypto.sign(null, message, paire.privateKey);
const abimee = Buffer.from(signature); abimee[10] ^= 0x01;

const vecteurs = {
  genere: 'scripts/generer-vecteurs.js',
  couleurs: couleurs,
  ordre: {
    cle: CLE_ORDRE, origine: ORIGINE, nombre: ordre.length,
    empreinteSolutions: crypto.createHash('sha256').update(solutions.join('\n')).digest('hex'),
    tete: ordre.slice(0, 10), motsDuJour: motsDuJour,
  },
  signature: {
    clePublique: brutePublique.toString('base64'),
    message: message.toString('base64'),
    signature: signature.toString('base64'),
    signatureAbimee: abimee.toString('base64'),
  },
};
fs.writeFileSync(sortie, JSON.stringify(vecteurs, null, 1) + '\n', 'utf8');

// L'effet, pas le code de retour : relire le fichier écrit.
const relu = JSON.parse(fs.readFileSync(sortie, 'utf8'));
console.log('vecteurs.json : ' + relu.couleurs.length + ' couleurs, ' + relu.ordre.motsDuJour.length +
            ' mots du jour (' + relu.ordre.nombre + ' solutions), signature ' + relu.signature.signature.length + ' car.');
