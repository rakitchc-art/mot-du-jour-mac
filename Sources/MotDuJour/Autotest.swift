import AppKit
import MotDuJourCore

// ===========================================================================
//  L'essai automatique, dans la VRAIE appli lancée comme un double-clic : le
//  vrai panneau sous la vraie icône, et des touches déposées dans la file
//  d'événements de l'appli — elles passent par le même moniteur que le vrai
//  clavier, mais PAS par la prise de main (quelle appli reçoit les frappes) :
//  celle-là, c'est scripts/epreuve-clavier.sh qui l'éprouve, avec un vrai clic
//  et de vraies frappes. Une partie scriptée : un mot faux, un mot inconnu,
//  cinq retours arrière, le bon mot, les stats, Échap ; puis minuit, la flèche
//  vers hier, le clic sur une case, une deuxième journée.
//
//  Il ne touche jamais au vrai carnet (bac à sable dans le dossier de sortie)
//  ni au démarrage du Mac. Le script de fabrication (scripts/autotest.sh)
//  photographie l'écran entier quand l'appli le lui demande, par des fichiers
//  témoins : etape-<nom> → capture-faite-<nom>.
// ===========================================================================

@MainActor
final class Autotest {
    private enum Etape {
        case faire(String, () -> Void)
        case pause(Double)
        case attendre(String, Double)
    }

    let delegue: Delegue
    let dossier: URL
    private var file: [Etape] = []
    private var journal: [String] = []
    private var echecs: [String] = []
    private var fini = false

    init(delegue: Delegue, dossier: URL) {
        self.delegue = delegue
        self.dossier = dossier
    }

    private var modele: Modele { delegue.modele }

    func lancer() {
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        noter("autotest — \(ProcessInfo.processInfo.operatingSystemVersionString), version \(versionDeLAppli())")
        noter("appli : \(Bundle.main.bundlePath)")
        let jour = modele.aujourdhui
        let solution = modele.jeu.solution(jour) ?? ""
        let faux = Dictionnaire.livre.solutions.first { $0 != solution } ?? "salut"
        let demain = jourDeNumero((numeroDeJour(jour) ?? 0) + 1)
        let solutionDemain = modele.jeu.solution(demain) ?? ""
        noter("jour \(jour) ; essai faux « \(faux) » ; lendemain simulé \(demain)")

        file = [
            .pause(1.5),
            .faire("ouvrir le panneau, comme un clic sur l'icône") {
                self.delegue.ouvrirPanneau()
            },
            .pause(1.0),
            .faire("le panneau est ouvert, prêt à jouer") {
                self.verifier(self.delegue.panneauOuvert, "le panneau s'ouvre sous l'icône")
                self.verifier(self.modele.etat.message == "Tape le mot, puis Entrée", "la consigne s'affiche")
                self.verifier(self.modele.pastille, "la pastille dit qu'un mot attend")
                self.photographier("vrai-1-ouvert.png")
                self.marquer("etape-panneau-ouvert")
            },
            .attendre("capture-faite-panneau-ouvert", 25),
            .faire("taper un mot faux, puis Entrée") {
                self.taper(faux)
                self.entree()
            },
            .pause(0.8),
            .faire("il prend la première ligne") {
                let g = self.modele.jeu.grille(jour)
                self.verifier(g?.essais.count == 1, "un essai compté")
                self.verifier(g?.essais.first?.couleurs == couleurs(essai: faux, solution: solution), "ses couleurs sont celles de la règle")
                self.verifier(self.modele.saisie.vide, "la ligne suivante est vide")
            },
            .faire("taper un mot inconnu, puis Entrée") {
                self.taper("zzzzz")
                self.entree()
            },
            .pause(0.8),
            .faire("il est refusé sans compter") {
                self.verifier(self.modele.jeu.grille(jour)?.essais.count == 1, "toujours un seul essai")
                self.verifier(self.modele.message?.texte == "Mot inconnu", "« Mot inconnu » s'affiche")
                self.verifier(self.modele.secousse == 1, "la ligne tremble")
                self.verifier(self.modele.saisie.mot == "zzzzz", "les lettres restent pour corriger")
                self.photographier("vrai-2-refus.png")
            },
            .faire("cinq retours arrière") {
                for _ in 0..<5 { self.retour() }
            },
            .pause(0.6),
            .faire("la ligne est vide") {
                self.verifier(self.modele.saisie.vide, "les cinq lettres sont effacées")
            },
            .faire("taper le bon mot, puis Entrée") {
                self.taper(solution)
                self.entree()
            },
            .pause(0.8),
            .faire("trouvé en 2") {
                let g = self.modele.jeu.grille(jour)
                self.verifier(g?.trouve == true && g?.fini == true, "la grille est trouvée et finie")
                self.verifier(self.modele.etat.message == "Trouvé en 2 !", "« Trouvé en 2 ! » s'affiche")
                self.verifier(!self.modele.pastille, "la pastille s'éteint")
                self.photographier("vrai-3-trouve.png")
            },
            .faire("ouvrir les statistiques") {
                self.modele.basculerStats()
            },
            .pause(0.8),
            .faire("les statistiques") {
                let s = self.modele.etat.stats
                self.verifier(s.joues == 1 && s.trouves == 1 && s.serie == 1, "1 joué, 1 trouvé, série de 1")
                self.verifier(s.distribution[1] == 1, "trouvé en 2 dans la répartition")
                self.photographier("vrai-4-stats.png")
                self.marquer("etape-stats")
            },
            .attendre("capture-faite-stats", 25),
            .faire("Échap ferme le panneau") {
                self.echap()
            },
            .pause(0.8),
            .faire("le panneau est fermé, le carnet est sur le disque") {
                self.verifier(!self.delegue.panneauOuvert, "Échap a fermé le panneau")
                if let d = self.modele.depot,
                   let data = try? Data(contentsOf: d.fichier),
                   let c = try? JSONDecoder().decode(Carnet.self, from: data) {
                    self.verifier(c.grilles[jour]?.essais.count == 2, "le carnet écrit garde les 2 essais")
                    self.verifier(c.premierJour == jour, "le premier jour est celui de l'installation")
                } else {
                    self.verifier(false, "le carnet se relit depuis le disque")
                }
            },
            // Minuit, sans attendre minuit : l'horloge du modèle avance d'un jour,
            // puis le tic de la minuterie (le même que toutes les 20 s).
            .faire("minuit passe") {
                self.modele.horloge = { demain }
                self.delegue.tic()
                self.verifier(self.modele.aujourdhui == demain, "le jour courant devient le lendemain")
                self.verifier(self.modele.pastille, "un nouveau mot attend")
                self.verifier(self.delegue.pastilleDansLaBarre == true, "l'icône de la barre reprend sa pastille")
            },
            .faire("rouvrir le panneau") {
                self.delegue.ouvrirPanneau()
            },
            .pause(1.0),
            .faire("le panneau s'ouvre sur le nouveau jour") {
                let e = self.modele.etat
                self.verifier(self.modele.jourAffiche == demain, "le jour affiché est le nouveau jour")
                self.verifier(e.titre == "Mot du jour", "titre « Mot du jour »")
                self.verifier(e.precedentPossible && !e.suivantPossible, "la flèche ‹ mène à hier, pas de flèche ›")
                self.photographier("vrai-5-lendemain.png")
                self.modele.precedent()
            },
            .pause(0.6),
            .faire("‹ : hier se relit") {
                let e = self.modele.etat
                self.verifier(e.titre == "Hier", "titre « Hier »")
                self.verifier(e.message == "Trouvé en 2 !", "la grille d'hier, trouvée en 2")
                self.verifier(e.ligneEnCours == nil, "une grille finie ne se rejoue pas")
                self.verifier(e.suivantPossible, "la flèche › ramène au jour")
                self.photographier("vrai-6-hier.png")
                self.modele.suivant()
                self.taper("abcde")
            },
            .pause(0.6),
            .faire("clic sur la 1re case, puis une lettre") {
                self.verifier(self.modele.jourAffiche == demain, "› est revenu au jour")
                self.modele.clicCase(0)
                self.taper("x")
            },
            .pause(0.6),
            .faire("la lettre tapée remplace celle de la case") {
                self.verifier(self.modele.saisie.mot == "xbcde", "« abcde » devient « xbcde »")
                for _ in 0..<5 { self.droite() }
                for _ in 0..<5 { self.retour() }
            },
            .pause(0.6),
            .faire("→ puis cinq retours arrière vident la ligne") {
                self.verifier(self.modele.saisie.vide, "la ligne est vide")
                self.taper(solutionDemain)
                self.entree()
            },
            .pause(0.8),
            .faire("trouvé du premier coup : deux jours de série") {
                // Les stats ne sont calculées dans la vue que quand elle les
                // affiche : ici on les demande au cœur directement.
                let s = statistiques(self.modele.jeu.carnet, aujourdhui: self.modele.aujourdhui)
                self.verifier(self.modele.etat.message == "Trouvé en 1 !", "« Trouvé en 1 ! »")
                self.verifier(s.joues == 2 && s.serie == 2 && s.meilleureSerie == 2, "2 joués, série de 2, record 2")
                self.verifier(!self.modele.pastille, "la pastille s'éteint")
                self.photographier("vrai-7-serie.png")
                self.echap()
            },
            .pause(0.6),
            .faire("les deux jours sont sur le disque") {
                if let d = self.modele.depot, let data = try? Data(contentsOf: d.fichier),
                   let c = try? JSONDecoder().decode(Carnet.self, from: data) {
                    self.verifier(c.grilles.count == 2 && c.grilles[demain]?.trouve == true, "deux grilles, la seconde trouvée")
                } else {
                    self.verifier(false, "le carnet se relit depuis le disque")
                }
            },
        ]
        // Un garde-fou : quoi qu'il arrive, l'essai finit et le dit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 150) {
            guard !self.fini else { return }
            self.echecs.append("délai dépassé")
            self.terminer()
        }
        suivante()
    }

    // MARK: - Le déroulé

    private func suivante() {
        guard !fini else { return }
        guard !file.isEmpty else { return terminer() }
        let e = file.removeFirst()
        switch e {
        case .faire(let nom, let action):
            noter("— \(nom)")
            action()
            DispatchQueue.main.async { self.suivante() }
        case .pause(let s):
            DispatchQueue.main.asyncAfter(deadline: .now() + s) { self.suivante() }
        case .attendre(let fichier, let max):
            attendre(fichier, reste: max)
        }
    }

    private func attendre(_ fichier: String, reste: Double) {
        if FileManager.default.fileExists(atPath: dossier.appendingPathComponent(fichier).path) { return suivante() }
        if reste <= 0 {
            noter("  (pas de « \(fichier) » : on continue sans la photo d'écran)")
            return suivante()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.attendre(fichier, reste: reste - 0.25) }
    }

    private func terminer() {
        guard !fini else { return }
        fini = true
        let resultat = echecs.isEmpty ? "REUSSI" : "ECHEC"
        noter("autotest : \(resultat)" + (echecs.isEmpty ? "" : " — " + echecs.joined(separator: " ; ")))
        try? (journal.joined(separator: "\n") + "\n")
            .write(to: dossier.appendingPathComponent("journal-autotest.txt"), atomically: true, encoding: .utf8)
        try? (resultat + "\n").write(to: dossier.appendingPathComponent("resultat-autotest.txt"), atomically: true, encoding: .utf8)
        marquer("autotest-fini")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    // MARK: - Les outils

    private func noter(_ ligne: String) {
        journal.append(ligne)
        print(ligne)
    }

    private func verifier(_ condition: Bool, _ quoi: String) {
        noter((condition ? "  ✓ " : "  ✗ ") + quoi)
        if !condition { echecs.append(quoi) }
    }

    private func marquer(_ nom: String) {
        FileManager.default.createFile(atPath: dossier.appendingPathComponent(nom).path, contents: Data())
    }

    /// Une photo du panneau tel qu'il est dessiné (la vue elle-même, sans
    /// demander l'autorisation d'enregistrer l'écran).
    private func photographier(_ nom: String) {
        if let taille = Self.photographier(delegue.vueDuPanneau, vers: dossier.appendingPathComponent(nom)) {
            noter("  photo : \(nom) (\(taille))")
        } else {
            noter("  (photo impossible : \(nom))")
        }
    }

    /// Rend la taille écrite (« 276 × 405 px »), ou nil si rien n'a été écrit.
    @discardableResult
    static func photographier(_ vue: NSView?, vers fichier: URL) -> String? {
        guard let v = vue, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return nil }
        v.cacheDisplay(in: v.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]),
              (try? png.write(to: fichier)) != nil else { return nil }
        return "\(rep.pixelsWide) × \(rep.pixelsHigh) px"
    }

    private func taper(_ texte: String) {
        for c in texte { poster(String(c), code: 0) }
    }
    private func entree() { poster("\r", code: 36) }
    private func retour() { poster("\u{7f}", code: 51) }
    private func echap() { poster("\u{1b}", code: 53) }
    private func droite() { poster("\u{F703}", code: 124) }

    /// Une vraie touche, dans la file d'événements de l'appli : elle passe par
    /// le moniteur du clavier comme une frappe de la joueuse.
    private func poster(_ caracteres: String, code: UInt16) {
        let fenetre = delegue.vueDuPanneau?.window
        guard let ev = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                        timestamp: ProcessInfo.processInfo.systemUptime,
                                        windowNumber: fenetre?.windowNumber ?? 0, context: nil,
                                        characters: caracteres, charactersIgnoringModifiers: caracteres,
                                        isARepeat: false, keyCode: code) else {
            return noter("  (touche impossible à fabriquer : \(caracteres))")
        }
        NSApp.postEvent(ev, atStart: false)
    }
}
