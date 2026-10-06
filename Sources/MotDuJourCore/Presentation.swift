import Foundation

// ===========================================================================
//  Ce que le panneau AFFICHE, calculé ici, sans aucune interface.
//
//  Les vues SwiftUI ne contiennent aucune règle de jeu : elles dessinent un
//  `VueEtat`. L'appli le calcule depuis le vrai carnet, la planche depuis des
//  carnets fabriqués — avec la MÊME fonction `presenter`. Et comme il vit dans
//  le cœur, les tests vérifient les textes et les flèches sans rien dessiner.
// ===========================================================================

public struct VueEtat: Equatable {
    public struct Case: Equatable {
        public var lettre: Character?
        /// v, j, g — nil pour une case pas encore jugée.
        public var teinte: Character?
        /// La ligne où l'on tape.
        public var active = false
        /// La case où tombera la prochaine lettre.
        public var curseur = false
        public init(lettre: Character? = nil, teinte: Character? = nil, active: Bool = false, curseur: Bool = false) {
            self.lettre = lettre; self.teinte = teinte; self.active = active; self.curseur = curseur
        }
    }

    public var titre: String
    public var sousTitre: String?
    public var precedentPossible: Bool
    public var suivantPossible: Bool
    /// 6 lignes de 5 cases.
    public var lignes: [[Case]]
    /// La ligne où l'on tape (c'est elle qui tremble au refus), nil si aucune.
    public var ligneEnCours: Int?
    public var message: String
    public var messageErreur: Bool
    /// La meilleure couleur connue de chaque lettre jouée ce jour-là (v > j > g).
    public var lettresClavier: [Character: Character]
    public var vueStats: Bool
    public var stats: Statistiques
    /// Le résultat du jour affiché, pour la répartition : 1 à 6, 7 = raté.
    public var resultatDuJour: Int?
}

/// Un message passager (refus, consigne), et s'il est une erreur (rouge).
public struct MessagePassager: Equatable {
    public var texte: String
    public var erreur: Bool
    public init(_ texte: String, erreur: Bool) { self.texte = texte; self.erreur = erreur }
}

/// Le sous-titre sous le titre du jour :
///  - aujourd'hui : la date (« mardi 6 octobre ») ;
///  - hier : où il en est (« à rattraper », « en cours »), sinon la date ;
///  - avant : le jour de la semaine, et où il en est (« dimanche · à rattraper »).
func sousTitreDuJour(_ jour: String, aujourdhui: String, jouable: Bool, commence: Bool) -> String {
    if jour == aujourdhui { return dateEnLettres(jour) }
    let etat: String? = jouable ? (commence ? "en cours" : "à rattraper") : nil
    if titreDuJour(jour, aujourdhui: aujourdhui) == "Hier" { return etat ?? dateEnLettres(jour) }
    return [jourDeLaSemaine(jour), etat].compactMap { $0 }.joined(separator: " · ")
}

public func presenter(jeu: Jeu, jour: String, aujourdhui: String, saisie: Saisie,
                      message: MessagePassager?, vueStats: Bool, fuseau: TimeZone = .current) -> VueEtat {
    let g = jeu.grille(jour)
    let essais = g?.essais ?? []
    let fini = g?.fini ?? false
    let jouable = jeu.jouable(jour, aujourdhui: aujourdhui)
    let enCours: Int? = (jouable && !fini && essais.count < Regles.essaisMax) ? essais.count : nil

    var lignes: [[VueEtat.Case]] = []
    for r in 0..<Regles.essaisMax {
        var ligne: [VueEtat.Case] = []
        for c in 0..<5 {
            if r < essais.count {
                let mot = Array(essais[r].mot), teintes = Array(essais[r].couleurs)
                ligne.append(VueEtat.Case(lettre: c < mot.count ? mot[c] : nil,
                                          teinte: c < teintes.count ? teintes[c] : "g"))
            } else if r == enCours {
                ligne.append(VueEtat.Case(lettre: saisie.cases[c], active: true, curseur: c == saisie.curseur))
            } else {
                ligne.append(VueEtat.Case())
            }
        }
        lignes.append(ligne)
    }

    // Le clavier : la meilleure couleur vue pour chaque lettre.
    var clavier: [Character: Character] = [:]
    let rang: [Character: Int] = ["g": 0, "j": 1, "v": 2]
    for e in essais {
        for (l, t) in zip(e.mot, e.couleurs) where (rang[t] ?? -1) > (rang[clavier[l] ?? "?"] ?? -1) {
            clavier[l] = t
        }
    }

    let texte: String
    var erreur = false
    if let m = message {
        texte = m.texte
        erreur = m.erreur
    } else if let g = g, g.fini {
        texte = g.trouve ? "Trouvé en \(g.essais.count) !" : "C'était \(g.solution.uppercased())"
    } else if essais.isEmpty && saisie.vide && jouable {
        texte = "Tape le mot, puis Entrée"
    } else {
        texte = ""
    }

    let sousTitre = sousTitreDuJour(jour, aujourdhui: aujourdhui, jouable: jouable, commence: !essais.isEmpty)

    let n = numeroDeJour(jour), p = numeroDeJour(jeu.carnet.premierJour), a = numeroDeJour(aujourdhui)
    var resultat: Int? = nil
    if let g = g, g.fini { resultat = g.trouve ? g.essais.count : 7 }

    return VueEtat(
        titre: titreDuJour(jour, aujourdhui: aujourdhui),
        sousTitre: sousTitre,
        precedentPossible: n != nil && p != nil && n! > p!,
        suivantPossible: n != nil && a != nil && n! < a!,
        lignes: lignes,
        ligneEnCours: enCours,
        message: texte,
        messageErreur: erreur,
        lettresClavier: clavier,
        vueStats: vueStats,
        stats: statistiques(jeu.carnet, aujourdhui: aujourdhui, fuseau: fuseau),
        resultatDuJour: resultat)
}
