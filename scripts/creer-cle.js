#!/usr/bin/env node
// ===========================================================================
//  creer-cle.js — fabrique une paire de clés Ed25519 pour signer les mises à
//  jour : la clé PRIVÉE (qui signe) et la clé PUBLIQUE (que l'appli garde pour
//  vérifier).
//
//    node scripts/creer-cle.js <dossier>
//
//  Écrit <dossier>/cle-maj-privee.pem et <dossier>/cle-maj-publique.txt.
//  Le dossier doit être HORS du dépôt (public) : la clé privée ne vit que là
//  et dans les secrets du dépôt GitHub. Refuse d'écraser une clé existante —
//  la perdre ou la remplacer, c'est que l'appli installée refuse désormais
//  toutes les versions signées avec la nouvelle.
//
//  L'épreuve de la fabrication s'en sert aussi, avec une clé jetable.
// ===========================================================================
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const dossier = process.argv[2];
if (!dossier) { console.error('usage : node scripts/creer-cle.js <dossier>'); process.exit(2); }
const privee = path.join(dossier, 'cle-maj-privee.pem');
const publique = path.join(dossier, 'cle-maj-publique.txt');
if (fs.existsSync(privee)) {
  console.error('Une clé existe déjà dans ' + dossier + ' : je ne l\'écrase pas.');
  process.exit(1);
}
fs.mkdirSync(dossier, { recursive: true });
const paire = crypto.generateKeyPairSync('ed25519');
fs.writeFileSync(privee, paire.privateKey.export({ format: 'pem', type: 'pkcs8' }), { mode: 0o600 });
const brute = paire.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');
fs.writeFileSync(publique, brute + '\n');

// L'effet : la clé relue signe, et la publique vérifie.
const relue = crypto.createPrivateKey(fs.readFileSync(privee));
const essai = Buffer.from('essai');
const pub = crypto.createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'),
                                                         Buffer.from(brute, 'base64')]), format: 'der', type: 'spki' });
if (!crypto.verify(null, essai, pub, crypto.sign(null, essai, relue))) {
  console.error('La clé écrite ne se vérifie pas : rien n\'est fiable, supprimer le dossier.');
  process.exit(1);
}
console.log('clé publique (pour Info.plist, MDJMiseAJourCle) : ' + brute);
