import Foundation
import CryptoKit

// ===========================================================================
//  Les règles du mot du jour, sans aucune interface.
//
//  Elles reprennent celles du mot mystère de TokenBar (le serveur
//  `echecs-serveur.js` de Dova), à une différence près : ici tout se passe
//  sur le Mac, il n'y a pas de serveur. Elle joue seule, avec son propre mot.
//
//  Ce module ne connaît ni AppKit ni SwiftUI : il se teste seul, et ce sont
//  les mêmes fonctions qui jouent dans l'appli et qui dessinent la planche.
// ===========================================================================

public enum Regles {
    /// Six essais, comme dans TokenBar.
    public static let essaisMax = 6
    /// Le jour 0 de l'ordre des mots. Le changer décale TOUS les mots à venir.
    public static let origine = "2026-09-01"
    /// La clé qui mélange l'ordre des mots. Elle est publique (le dépôt l'est) :
    /// elle ne cache rien, elle fixe seulement un ordre, le même sur tous les
    /// Mac. La changer décale tous les mots, comme l'origine.
    public static let cleOrdre = "mot-du-jour-mac"
}

// MARK: - Les jours

/// Le numéro d'un jour civil « AAAA-MM-JJ » : le nombre de jours depuis le
/// 1970-01-01, sans fuseau ni calendrier système — la même date donne toujours
/// le même numéro. Une date impossible (30 février, mois 13…) rend nil.
/// Algorithme « days from civil » de Howard Hinnant.
public func numeroDeJour(_ jour: String) -> Int? {
    let morceaux = jour.split(separator: "-", omittingEmptySubsequences: false)
    guard morceaux.count == 3,
          morceaux[0].count == 4, morceaux[1].count == 2, morceaux[2].count == 2,
          let a = Int(morceaux[0]), let m = Int(morceaux[1]), let j = Int(morceaux[2]),
          (1...12).contains(m), (1...31).contains(j) else { return nil }
    let y = m <= 2 ? a - 1 : a
    let ere = (y >= 0 ? y : y - 399) / 400
    let anDeLEre = y - ere * 400
    let mp = (m + 9) % 12
    let jourDeLAn = (153 * mp + 2) / 5 + j - 1
    let jourDeLEre = anDeLEre * 365 + anDeLEre / 4 - anDeLEre / 100 + jourDeLAn
    let n = ere * 146097 + jourDeLEre - 719468
    // Le 30 février passe les bornes ci-dessus : seul l'aller-retour le refuse.
    return jourDeNumero(n) == jour ? n : nil
}

/// L'inverse de `numeroDeJour` : « AAAA-MM-JJ ».
public func jourDeNumero(_ n: Int) -> String {
    let z = n + 719468
    let ere = (z >= 0 ? z : z - 146096) / 146097
    let jourDeLEre = z - ere * 146097
    let anDeLEre = (jourDeLEre - jourDeLEre / 1460 + jourDeLEre / 36524 - jourDeLEre / 146096) / 365
    let jourDeLAn = jourDeLEre - (365 * anDeLEre + anDeLEre / 4 - anDeLEre / 100)
    let mp = (5 * jourDeLAn + 2) / 153
    let j = jourDeLAn - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    let a = anDeLEre + ere * 400 + (m <= 2 ? 1 : 0)
    return String(format: "%04ld-%02ld-%02ld", a, m, j)
}

/// Le jour civil de `date` sur ce Mac (son fuseau), toujours en calendrier
/// GRÉGORIEN : un Mac réglé sur un autre calendrier (bouddhiste, japonais…)
/// donnerait sinon une autre année, donc un autre mot.
public func jourLocal(_ date: Date = Date(), fuseau: TimeZone = .current) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = fuseau
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04ld-%02ld-%02ld", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
}

/// L'instant d'un geste, écrit comme le serveur de TokenBar (toISOString).
public func horodatage(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f.string(from: date)
}

/// L'inverse de `horodatage` (accepte aussi l'écriture sans millisecondes).
public func dateDe(_ horodatage: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: horodatage) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: horodatage)
}

/// Le titre du panneau pour `jour` : « Mot du jour » aujourd'hui, « Hier »,
/// sinon la date courte (« 27 septembre ») — le jour de la semaine passe dans
/// le sous-titre : « dimanche 27 septembre » ne tenait pas à côté des flèches
/// (vu sur la première planche, le 06/10).
public func titreDuJour(_ jour: String, aujourdhui: String) -> String {
    guard let n = numeroDeJour(jour), let a = numeroDeJour(aujourdhui) else { return jour }
    if n == a { return "Mot du jour" }
    if n == a - 1 { return "Hier" }
    return dateCourte(jour)
}

private func formatFrancais(_ motif: String, _ jour: String) -> String? {
    guard let n = numeroDeJour(jour) else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "fr_FR")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = motif
    return f.string(from: Date(timeIntervalSince1970: TimeInterval(n) * 86_400))
}

/// « lundi ».
public func jourDeLaSemaine(_ jour: String) -> String { formatFrancais("EEEE", jour) ?? jour }

/// « 27 septembre », « 1er janvier ».
public func dateCourte(_ jour: String) -> String {
    guard let mois = formatFrancais("MMMM", jour), let n = Int(jour.suffix(2)) else { return jour }
    return (n == 1 ? "1er" : "\(n)") + " " + mois
}

/// « mardi 6 octobre », « vendredi 1er janvier ».
public func dateEnLettres(_ jour: String) -> String {
    guard numeroDeJour(jour) != nil else { return jour }
    return jourDeLaSemaine(jour) + " " + dateCourte(jour)
}

// MARK: - Les mots

/// Un mot jouable : exactement cinq lettres de a à z, sans accent.
public func estMotValide(_ mot: String) -> Bool {
    let u = Array(mot.unicodeScalars)
    return u.count == 5 && u.allSatisfy { $0.value >= 97 && $0.value <= 122 }
}

/// La lettre que représente une touche : « é » devient e, « Ç » devient c.
/// Rien pour le reste (chiffres, ponctuation, « œ » qui fait deux lettres).
public func lettreDeTouche(_ texte: String) -> Character? {
    let plie = texte.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                             locale: Locale(identifier: "fr_FR")).lowercased()
    let u = Array(plie.unicodeScalars)
    guard u.count == 1, u[0].value >= 97, u[0].value <= 122 else { return nil }
    return Character(u[0])
}

/// Les couleurs d'un essai, une lettre par case : v (bien placée), j (dans le
/// mot, ailleurs), g (absente). La règle de Wordle avec les lettres répétées :
/// d'abord les bonnes places, puis chaque lettre restante de la solution ne
/// « paie » qu'un seul jaune. C'est `couleursDe` du serveur TokenBar, et les
/// tests le prouvent contre elle (vecteurs.json est produit par SA fonction).
public func couleurs(essai: String, solution: String) -> String {
    let e = Array(essai.unicodeScalars), s = Array(solution.unicodeScalars)
    guard e.count == 5, s.count == 5 else { return "" }
    var res = Array(repeating: Character("g"), count: 5)
    var reste: [Unicode.Scalar: Int] = [:]
    for i in 0..<5 {
        if e[i] == s[i] { res[i] = "v" } else { reste[s[i], default: 0] += 1 }
    }
    for i in 0..<5 where res[i] != "v" {
        if let n = reste[e[i]], n > 0 { res[i] = "j"; reste[e[i]] = n - 1 }
    }
    return String(res)
}

/// Les deux listes du jeu, et l'ordre des mots du jour.
public struct Dictionnaire {
    /// Les mots qui peuvent être LE mot d'un jour.
    public let solutions: [String]
    /// Les mots acceptés en essai (les solutions comprises).
    public let acceptes: Set<String>
    /// Les solutions dans l'ordre des jours : triées par leur empreinte HMAC
    /// (clé `Regles.cleOrdre`), comme le serveur de TokenBar trie les siennes
    /// avec son code secret. Un ordre fixe, sans répétition avant la fin du tour.
    public let ordre: [String]

    public init(solutionsBrut: String, acceptesBrut: String) {
        let sol = Dictionnaire.lire(solutionsBrut)
        solutions = sol
        acceptes = Set(Dictionnaire.lire(acceptesBrut)).union(sol)
        let cle = SymmetricKey(data: Data(Regles.cleOrdre.utf8))
        let empreintes = sol.map { mot -> (String, String) in
            let code = HMAC<SHA256>.authenticationCode(for: Data(mot.utf8), using: cle)
            let hexa = code.withUnsafeBytes { Data($0) }.map { String(format: "%02x", $0) }.joined()
            return (mot, hexa)
        }
        ordre = empreintes.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    /// Les listes livrées avec l'appli, générées depuis TokenBar en deux
    /// fichiers, un par licence (MotsLexique.swift, MotsGrammalecte.swift).
    public static let livre = Dictionnaire(
        solutionsBrut: listeSolutionsBrut,
        acceptesBrut: listeAcceptesLexiqueBrut + "\n" + listeAcceptesGrammalecteBrut)

    static func lire(_ brut: String) -> [String] {
        brut.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter(estMotValide)
    }

    /// Le mot de `jour`, ou nil si la date est illisible.
    public func motDuJour(_ jour: String) -> String? {
        guard !ordre.isEmpty, let n = numeroDeJour(jour), let o = numeroDeJour(Regles.origine) else { return nil }
        let k = ordre.count
        return ordre[((n - o) % k + k) % k]
    }

    public func accepte(_ mot: String) -> Bool { acceptes.contains(mot) }
}
