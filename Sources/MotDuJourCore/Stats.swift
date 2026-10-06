import Foundation

/// Ses statistiques à elle (décision du 06/10/2026 : série, meilleure série,
/// moyenne, répartition).
///
/// Mêmes règles que les stats du mot dans TokenBar (`statsMotDe` du serveur),
/// pour une seule joueuse : aujourd'hui ne compte que si sa grille est FINIE ;
/// un jour passé sans grille casse la série, aujourd'hui pas encore joué ne la
/// casse pas (la journée n'est pas finie) ; un jour rattrapé compte comme un
/// autre. Calculées à la demande, jamais écrites : une stat gardée serait une
/// seconde vérité à tenir d'accord avec le carnet.
public struct Statistiques: Equatable {
    public var joues = 0
    public var trouves = 0
    /// Trouvé en 1, 2… 6, puis raté (index 6).
    public var distribution = Array(repeating: 0, count: 7)
    public var serie = 0
    public var meilleureSerie = 0
    public var moyenneEssais: Double?
    /// Les jours joués après coup.
    public var rattrapes = 0

    public init() {}

    /// Le pourcentage de mots trouvés, arrondi ; nil avant le premier jeu.
    public var reussite: Int? {
        joues > 0 ? Int((100.0 * Double(trouves) / Double(joues)).rounded()) : nil
    }
}

public func statistiques(_ carnet: Carnet, aujourdhui: String, fuseau: TimeZone = .current) -> Statistiques {
    var s = Statistiques()
    guard let n0 = numeroDeJour(carnet.premierJour), let n1 = numeroDeJour(aujourdhui), n0 <= n1 else { return s }
    var serie = 0
    var sommeEssais = 0
    for n in n0...n1 {
        let jour = jourDeNumero(n)
        let estAujourdhui = (n == n1)
        let g = carnet.grilles[jour]
        // Aujourd'hui pas fini : il n'existe pas encore pour les stats.
        if estAujourdhui && !(g?.fini ?? false) { continue }
        guard let g = g, let premier = g.essais.first else {
            serie = 0   // un jour passé sans grille casse la série
            continue
        }
        s.joues += 1
        if let d = dateDe(premier.utc), let n2 = numeroDeJour(jourLocal(d, fuseau: fuseau)), n2 > n {
            s.rattrapes += 1
        }
        if g.trouve {
            s.trouves += 1
            s.distribution[min(6, g.essais.count) - 1] += 1
            sommeEssais += g.essais.count
            serie += 1
        } else {
            if g.fini { s.distribution[6] += 1 }
            serie = 0
        }
        s.meilleureSerie = max(s.meilleureSerie, serie)
    }
    s.serie = serie
    if s.trouves > 0 { s.moyenneEssais = Double(sommeEssais) / Double(s.trouves) }
    return s
}
