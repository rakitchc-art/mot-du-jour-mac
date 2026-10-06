#!/usr/bin/env node
// ===========================================================================
//  signer-archive.js — signe une archive de mise à jour (Ed25519) et écrit
//  <archive>.sig, puis VÉRIFIE la signature avec la clé publique que l'appli
//  embarque : si la clé privée du dépôt ne correspond plus à celle de l'appli,
//  aucune appli installée n'accepterait cette version — on s'arrête là.
//
//    node scripts/signer-archive.js <archive> <clé privée> <clé publique attendue>
//
//  <clé privée> : un chemin vers le .pem, ou env:NOM pour la lire dans une
//  variable d'environnement (le secret du dépôt, sur les Mac de GitHub).
//  <clé publique attendue> : base64, celle d'Info.plist (MDJMiseAJourCle).
// ===========================================================================
'use strict';

const fs = require('fs');
const crypto = require('crypto');

const [archive, sourceCle, publiqueAttendue] = process.argv.slice(2);
if (!archive || !sourceCle || !publiqueAttendue) {
  console.error('usage : node scripts/signer-archive.js <archive> <clé privée|env:NOM> <clé publique base64>');
  process.exit(2);
}
let pem;
if (sourceCle.startsWith('env:')) {
  pem = process.env[sourceCle.slice(4)] || '';
  if (!pem.trim()) { console.error('la variable ' + sourceCle.slice(4) + ' est vide : pas de clé pour signer'); process.exit(1); }
} else {
  pem = fs.readFileSync(sourceCle, 'utf8');
}
const privee = crypto.createPrivateKey(pem);
const donnees = fs.readFileSync(archive);
const signature = crypto.sign(null, donnees, privee);

// D'abord vérifier avec la clé de l'APPLI, ENSUITE écrire : un .sig qui ne
// correspond pas ne doit jamais exister sur le disque (tour de code du 06/10).
let publique;
try {
  publique = crypto.createPublicKey({
    key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), Buffer.from(publiqueAttendue.trim(), 'base64')]),
    format: 'der', type: 'spki',
  });
} catch (e) {
  console.error('La clé publique attendue est illisible : ' + e.message);
  process.exit(1);
}
if (!crypto.verify(null, donnees, publique, signature)) {
  console.error('La signature ne se vérifie PAS avec la clé de l\'appli : la clé privée et Info.plist ne vont pas ensemble.');
  process.exit(1);
}
fs.writeFileSync(archive + '.sig', signature.toString('base64') + '\n');
// L'effet : le fichier écrit, relu, se vérifie encore.
const relue = Buffer.from(fs.readFileSync(archive + '.sig', 'utf8').trim(), 'base64');
if (!crypto.verify(null, donnees, publique, relue)) {
  fs.unlinkSync(archive + '.sig');
  console.error('Le .sig relu ne se vérifie plus : retiré.');
  process.exit(1);
}
console.log('signée et vérifiée avec la clé de l\'appli : ' + archive + '.sig');
