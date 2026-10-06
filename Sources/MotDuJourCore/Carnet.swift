import Foundation

// ===========================================================================
//  Le carnet : toutes ses grilles, jour par jour, et ce qui les juge.
// ===========================================================================

/// Un essai joué, tel qu'il est gardé.
public struct Essai: Codable, Equatable {
    public var mot: String
    public var couleurs: String
    public var utc: String
    public init(mot: String, couleurs: String, utc: String) {
        self.mot = mot; self.couleurs = couleurs; self.utc = utc
    }
}

/// La grille d'un jour. La solution y est COPIÉE au premier essai : une mise
/// à jour qui changerait la liste des mots ne peut plus changer le mot d'un
/// jour déjà commencé (le serveur de TokenBar copie le sien de la même façon).
public struct Grille: Codable, Equatable {
    public var solution: String
    public var essais: [Essai] = []
    public var fini = false
    public var trouve = false
    public var finiUtc = ""

    public init(solution: String) { self.solution = solution }

    enum CodingKeys: String, CodingKey { case solution, essais, fini, trouve, finiUtc }

    // Lu avec indulgence : un champ absent prend sa valeur par défaut, pour
    // qu'un carnet écrit par une autre version se relise sans tout perdre.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        solution = try c.decode(String.self, forKey: .solution)
        essais = try c.decodeIfPresent([Essai].self, forKey: .essais) ?? []
        fini = try c.decodeIfPresent(Bool.self, forKey: .fini) ?? false
        trouve = try c.decodeIfPresent(Bool.self, forKey: .trouve) ?? false
        finiUtc = try c.decodeIfPresent(String.self, forKey: .finiUtc) ?? ""
    }
}

/// Tout ce qui se garde sur le disque.
public struct Carnet: Codable, Equatable {
    /// Le format que CETTE version sait lire et écrire. Un carnet d'un format
    /// plus récent (écrit par une version future) n'est jamais réécrit.
    public static let formatConnu = 1
    public var format = Carnet.formatConnu
    /// Le jour de l'installation : les flèches ne remontent pas plus loin
    /// (« jours passés depuis son installation », décision du 06/10/2026).
    public var premierJour: String
    /// Les grilles, par jour « AAAA-MM-JJ ». Un jour sans grille n'a pas été joué.
    public var grilles: [String: Grille] = [:]

    public init(premierJour: String) { self.premierJour = premierJour }

    enum CodingKeys: String, CodingKey { case format, premierJour, grilles }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(Int.self, forKey: .format) ?? 1
        premierJour = try c.decode(String.self, forKey: .premierJour)
        grilles = try c.decodeIfPresent([String: Grille].self, forKey: .grilles) ?? [:]
    }
}

/// Ce que devient une proposition.
public enum Verdict: Equatable {
    /// Comptée : elle prend une ligne.
    case joue(Essai)
    /// Pas dans la liste : NI comptée NI grisée, la ligne tremble et on retape
    /// (une faute de frappe n'est pas un essai raté — règle de TokenBar).
    case inconnu
    /// Pas cinq lettres de a à z.
    case malforme
    /// La grille de ce jour est déjà finie.
    case dejaFini
    /// Avant l'installation, ou dans le futur.
    case horsBornes
}

/// Le jeu : le dictionnaire et le carnet, et les seuls gestes qui le changent.
public struct Jeu {
    public let dico: Dictionnaire
    public private(set) var carnet: Carnet

    public init(dico: Dictionnaire, carnet: Carnet) {
        self.dico = dico
        self.carnet = carnet
    }

    public func grille(_ jour: String) -> Grille? { carnet.grilles[jour] }

    /// De l'installation à aujourd'hui, bornes comprises.
    public func dansLesBornes(_ jour: String, aujourdhui: String) -> Bool {
        guard let n = numeroDeJour(jour), let a = numeroDeJour(aujourdhui),
              let p = numeroDeJour(carnet.premierJour) else { return false }
        return n >= p && n <= a
    }

    /// Peut-on encore jouer ce jour-là ? (Les jours passés se rattrapent.)
    public func jouable(_ jour: String, aujourdhui: String) -> Bool {
        dansLesBornes(jour, aujourdhui: aujourdhui) && !(carnet.grilles[jour]?.fini ?? false)
    }

    /// Le mot de ce jour : celui copié dans la grille s'il existe, sinon celui
    /// de la liste.
    public func solution(_ jour: String) -> String? {
        carnet.grilles[jour]?.solution ?? dico.motDuJour(jour)
    }

    /// Une proposition pour `jour`. Ne touche au carnet que si elle est COMPTÉE.
    public mutating func proposer(_ essai: String, jour: String, aujourdhui: String,
                                  maintenant: Date = Date()) -> Verdict {
        guard estMotValide(essai) else { return .malforme }
        guard dansLesBornes(jour, aujourdhui: aujourdhui), let sol = solution(jour) else { return .horsBornes }
        var g = carnet.grilles[jour] ?? Grille(solution: sol)
        if g.fini { return .dejaFini }
        // La solution du jour est toujours acceptée, même si une liste
        // retouchée l'a perdue entre-temps.
        if !(dico.accepte(essai) || essai == g.solution) { return .inconnu }
        let t = horodatage(maintenant)
        let e = Essai(mot: essai, couleurs: couleurs(essai: essai, solution: g.solution), utc: t)
        g.essais.append(e)
        if essai == g.solution { g.trouve = true; g.fini = true }
        else if g.essais.count >= Regles.essaisMax { g.fini = true }
        if g.fini { g.finiUtc = t }
        carnet.grilles[jour] = g
        return .joue(e)
    }

    /// Si l'horloge du Mac a reculé avant le premier jour, le ramène à
    /// aujourd'hui — sinon plus rien ne serait jouable. Renvoie true s'il a bougé.
    public mutating func recalerPremierJour(aujourdhui: String) -> Bool {
        guard let a = numeroDeJour(aujourdhui) else { return false }
        if let p = numeroDeJour(carnet.premierJour), p <= a { return false }
        carnet.premierJour = aujourdhui
        return true
    }
}

/// Le carnet sur le disque : ~/Library/Application Support/Mot du jour/carnet.json.
public final class Depot {
    public let dossier: URL
    public var fichier: URL { dossier.appendingPathComponent("carnet.json") }
    /// Vrai quand le carnet sur le disque ne doit PAS être réécrit : illisible
    /// et impossible à mettre de côté, ou écrit par une version plus récente.
    /// On joue alors sans enregistrer plutôt que d'effacer ses parties.
    public private(set) var ecritureInterdite = false

    public init(dossier: URL) { self.dossier = dossier }

    public static func dossierParDefaut() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Mot du jour", isDirectory: true)
    }

    public struct Chargement {
        public var carnet: Carnet
        /// Dit pourquoi on repart à neuf, si c'est le cas.
        public var avertissement: String?
    }

    /// Lit le carnet. Absent : un carnet neuf qui commence aujourd'hui.
    /// Illisible : il est mis de côté — jamais écrasé — et on repart à neuf ;
    /// l'avertissement le dit.
    public func charger(aujourdhui: String) -> Chargement {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fichier.path) else {
            return Chargement(carnet: Carnet(premierJour: aujourdhui), avertissement: nil)
        }
        do {
            let data = try Data(contentsOf: fichier)
            var c = try JSONDecoder().decode(Carnet.self, from: data)
            if c.format > Carnet.formatConnu {
                ecritureInterdite = true
                return Chargement(carnet: c, avertissement: "Carnet d'une version plus récente : il n'est pas réécrit")
            }
            if numeroDeJour(c.premierJour) == nil { c.premierJour = aujourdhui }
            return Chargement(carnet: c, avertissement: nil)
        } catch {
            let cote = dossier.appendingPathComponent("carnet-illisible-\(Int(Date().timeIntervalSince1970)).json")
            do {
                try fm.moveItem(at: fichier, to: cote)
            } catch {
                // Ni lisible ni déplaçable : on ne l'écrasera pas.
                ecritureInterdite = true
                return Chargement(carnet: Carnet(premierJour: aujourdhui),
                                  avertissement: "Carnet illisible, laissé tel quel : les parties de cette session ne seront pas enregistrées")
            }
            return Chargement(carnet: Carnet(premierJour: aujourdhui),
                              avertissement: "Carnet illisible, mis de côté : \(cote.lastPathComponent)")
        }
    }

    /// Écrit le carnet d'un seul coup (fichier temporaire puis renommage) :
    /// une coupure au milieu laisse l'ancien intact, jamais un demi-fichier.
    public func enregistrer(_ c: Carnet) throws {
        if ecritureInterdite {
            throw NSError(domain: "MotDuJour", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "le carnet sur le disque est protégé, rien n'est écrit"])
        }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(c).write(to: fichier, options: .atomic)
    }
}
