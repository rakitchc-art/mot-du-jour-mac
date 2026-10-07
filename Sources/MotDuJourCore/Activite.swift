import Foundation

// ===========================================================================
//  « Dire à Dova quand j'ai joué » (07/10/2026, avec l'accord de Kelly) :
//  quels jours signaler. Tiré du CARNET, pas d'un drapeau à part : un jour
//  joué hors connexion, ou juste avant que l'appli ne se ferme, reste à
//  signaler tant qu'il n'a pas été accepté — rien ne se perd en route.
// ===========================================================================

/// Les jours où elle a joué : au moins un essai compté ce jour-là, à l'heure
/// du Mac (le jour où elle a joué, pas celui de la grille : rattraper hier,
/// c'est jouer aujourd'hui).
public func joursJoues(_ carnet: Carnet, fuseau: TimeZone = .current) -> Set<String> {
    var jours = Set<String>()
    for grille in carnet.grilles.values {
        for essai in grille.essais {
            if let d = dateDe(essai.utc) { jours.insert(jourLocal(d, fuseau: fuseau)) }
        }
    }
    return jours
}

/// Ceux à signaler, du plus ancien au plus récent : joués, pas encore
/// acceptés, et dans les `fenetre` derniers jours (aujourd'hui compris) —
/// au-delà, le registre les refuserait de toute façon.
public func joursASignaler(joues: Set<String>, deja: Set<String>, aujourdhui: String, fenetre: Int = 7) -> [String] {
    guard let n = numeroDeJour(aujourdhui) else { return [] }
    return joues.subtracting(deja)
        .filter { jour in numeroDeJour(jour).map { $0 > n - fenetre && $0 <= n } ?? false }
        .sorted()
}
