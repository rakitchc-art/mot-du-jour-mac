#!/usr/bin/env node
// ===========================================================================
//  serveur-epreuve.js — un serveur de fichiers minimal pour l'épreuve de la
//  mise à jour : sert <dossier> sur http://127.0.0.1:<port>/ et note chaque
//  requête.
//
//  Pourquoi pas celui de Python (python3 -m http.server) : mesuré le 06/10 sur
//  le Mac de GitHub, il n'écoutait toujours pas 5 s après son lancement — son
//  socket était lié mais pas ouvert (lsof : « CLOSED »). Au démarrage, il
//  cherche le nom de la machine (socket.getfqdn), une question au DNS qui peut
//  traîner. Celui-ci ne demande rien à personne.
//
//    node scripts/serveur-epreuve.js <dossier> <port>
// ===========================================================================
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const racine = path.resolve(process.argv[2] || '.');
const port = parseInt(process.argv[3] || '8765', 10);

http.createServer(function (req, res) {
  const demande = decodeURIComponent(new URL(req.url, 'http://local').pathname);
  const chemin = path.resolve(racine, '.' + demande);
  if (chemin !== racine && !chemin.startsWith(racine + path.sep)) {
    res.writeHead(403); res.end();
    console.log(req.method + ' ' + req.url + ' 403');
    return;
  }
  fs.readFile(chemin, function (err, donnees) {
    if (err) {
      res.writeHead(404); res.end();
      console.log(req.method + ' ' + req.url + ' 404');
      return;
    }
    res.writeHead(200, {
      'Content-Type': chemin.endsWith('.json') ? 'application/json' : 'application/octet-stream',
      'Content-Length': donnees.length,
    });
    res.end(donnees);
    console.log(req.method + ' ' + req.url + ' 200 ' + donnees.length + ' octets');
  });
}).listen(port, '127.0.0.1', function () {
  console.log('prêt : http://127.0.0.1:' + port + '/ sert ' + racine);
});
