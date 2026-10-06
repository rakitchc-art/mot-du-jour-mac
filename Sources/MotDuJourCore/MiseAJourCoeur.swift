import Foundation
import CryptoKit

// ===========================================================================
//  Le cœur de la mise à jour automatique (décision du 06/10/2026) : ce qui se
//  décide sans réseau ni disque, donc ce qui se teste. Le geste lui-même
//  (télécharger, poser, relancer) vit dans l'appli.
//
//  Le chemin : l'API PUBLIQUE de GitHub donne la dernière publication du
//  dépôt ; on n'en prend une que si elle est plus récente, pas déjà refusée,
//  et accompagnée de son archive ET de sa signature. L'archive n'est posée
//  que si sa signature Ed25519 est valide pour la clé publique livrée dans
//  l'appli — la clé privée ne vit que dans les secrets du dépôt.
// ===========================================================================

/// « 1.2.3 » → [1, 2, 3]. Un « v » devant est toléré ; tout le reste rend nil.
public func composantesVersion(_ version: String) -> [Int]? {
    var s = version.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
    let morceaux = s.split(separator: ".", omittingEmptySubsequences: false)
    guard !morceaux.isEmpty, morceaux.count <= 4 else { return nil }
    var res: [Int] = []
    for m in morceaux {
        guard !m.isEmpty, m.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(m) else { return nil }
        res.append(n)
    }
    return res
}

/// `a` est-elle strictement plus récente que `b` ? Une version illisible ne
/// l'est jamais : dans le doute, on ne remplace rien.
public func estPlusRecente(_ a: String, que b: String) -> Bool {
    guard let x = composantesVersion(a), let y = composantesVersion(b) else { return false }
    for i in 0..<max(x.count, y.count) {
        let u = i < x.count ? x[i] : 0
        let w = i < y.count ? y[i] : 0
        if u != w { return u > w }
    }
    return false
}

/// Le nom de l'archive d'une version, tel que la fabrication la publie.
public func nomArchive(version: String) -> String { "Mot-du-jour-\(version).zip" }

/// Une publication GitHub, telle que l'API la rend (seulement ce qu'on lit).
public struct Publication: Decodable {
    public struct Piece: Decodable {
        public let name: String
        public let browser_download_url: String
    }
    public let tag_name: String
    public let draft: Bool?
    public let prerelease: Bool?
    public let assets: [Piece]
}

public struct PlanMiseAJour: Equatable {
    public let version: String
    public let archive: URL
    public let signature: URL
}

/// Une adresse d'où l'on accepte de télécharger : https, toujours — sauf
/// l'épreuve de la fabrication, qui sert ses fausses versions depuis la
/// machine elle-même (http://127.0.0.1) et le DIT par `accepteLocal`. Même
/// alors, jamais du http vers une autre machine.
public func adresseAcceptable(_ u: URL, accepteLocal: Bool) -> Bool {
    if u.scheme == "https" { return true }
    return accepteLocal && u.scheme == "http" && (u.host == "127.0.0.1" || u.host == "localhost")
}

/// Que faire de la dernière publication ? nil = rien.
/// `acceptePrepublication` ne sert qu'au contrôle d'une publication par le
/// script de publication : elle est d'abord mise en ligne en « préversion »
/// (invisible des applis installées), jugée par l'appli, puis seulement
/// rendue « dernière version ». Une appli installée ne le passe jamais.
public func planDeMiseAJour(_ p: Publication, versionCourante: String, refusees: Set<String>,
                            accepteLocal: Bool = false, acceptePrepublication: Bool = false) -> PlanMiseAJour? {
    if p.draft == true { return nil }
    if p.prerelease == true && !acceptePrepublication { return nil }
    guard let comps = composantesVersion(p.tag_name) else { return nil }
    let version = comps.map(String.init).joined(separator: ".")
    guard estPlusRecente(version, que: versionCourante), !refusees.contains(version) else { return nil }
    let nom = nomArchive(version: version)
    guard let a = p.assets.first(where: { $0.name == nom }),
          let s = p.assets.first(where: { $0.name == nom + ".sig" }),
          let ua = URL(string: a.browser_download_url), let us = URL(string: s.browser_download_url),
          adresseAcceptable(ua, accepteLocal: accepteLocal),
          adresseAcceptable(us, accepteLocal: accepteLocal) else { return nil }
    return PlanMiseAJour(version: version, archive: ua, signature: us)
}

/// La version écrite dans le .app d'à côté (Info.plist), lue sans le charger.
public func versionDuPaquet(_ app: URL) -> (identifiant: String, version: String)? {
    let plist = app.appendingPathComponent("Contents/Info.plist")
    guard let data = try? Data(contentsOf: plist),
          let d = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let id = d["CFBundleIdentifier"] as? String,
          let v = d["CFBundleShortVersionString"] as? String else { return nil }
    return (id, v)
}

// MARK: - La mémoire sur le disque (leçon de TokenBar : un garde-fou en
// mémoire meurt avec le processus, et c'est justement le redémarrage qui
// rejoue la boucle)

/// La pose annoncée avant de quitter : relue au démarrage suivant.
public struct PoseAttendue: Codable, Equatable {
    public var version: String
    public var depuis: String
    public var utc: String
    public init(version: String, depuis: String, utc: String) {
        self.version = version; self.depuis = depuis; self.utc = utc
    }
}

public enum BilanPose: Equatable {
    case rien
    /// La nouvelle version tourne : la pose a réussi.
    case reussie(String)
    /// C'est toujours l'ancienne qui tourne : cette version est refusée pour toujours.
    case ratee(String)
}

/// Au démarrage : que dit la pose annoncée, s'il y en a une ? Écrit le
/// refus sur le disque AVANT de rendre la main, et efface l'annonce.
public final class MemoireMiseAJour {
    public let dossier: URL
    /// L'annonce d'une pose : le script de pose la surveille — tant qu'elle est
    /// là, la neuve n'a pas fait son bilan (elle l'efface en démarrant).
    public var fichierAttendue: URL { dossier.appendingPathComponent("maj-attendue.json") }
    var fichierRefusees: URL { dossier.appendingPathComponent("maj-refusees.json") }
    /// L'ancienne version, mise de côté pendant une pose. Ici (Application
    /// Support) et pas dans les Caches, que macOS peut vider : c'est elle qui
    /// revient si la neuve ne démarre pas.
    public var sauvegarde: URL { dossier.appendingPathComponent("ancienne.app", isDirectory: true) }

    public init(dossier: URL) { self.dossier = dossier }

    public func refusees() -> Set<String> {
        guard let data = try? Data(contentsOf: fichierRefusees),
              let liste = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(liste)
    }

    public func refuser(_ version: String) throws {
        var r = refusees()
        r.insert(version)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try JSONEncoder().encode(r.sorted()).write(to: fichierRefusees, options: .atomic)
    }

    public func annoncer(_ p: PoseAttendue) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try JSONEncoder().encode(p).write(to: fichierAttendue, options: .atomic)
    }

    /// Retire une annonce dont la pose n'a finalement pas été lancée : sinon le
    /// démarrage suivant la compterait comme une pose ratée, et refuserait pour
    /// toujours une version qui n'a jamais été essayée.
    public func oublierAnnonce() {
        try? FileManager.default.removeItem(at: fichierAttendue)
    }

    public func attendue() -> PoseAttendue? {
        guard let data = try? Data(contentsOf: fichierAttendue) else { return nil }
        return try? JSONDecoder().decode(PoseAttendue.self, from: data)
    }

    public func bilan(versionCourante: String) throws -> BilanPose {
        guard let a = attendue() else {
            // Une annonce illisible ne doit pas survivre : elle reviendrait à chaque démarrage.
            if FileManager.default.fileExists(atPath: fichierAttendue.path) { try? FileManager.default.removeItem(at: fichierAttendue) }
            return .rien
        }
        let bilan: BilanPose
        if composantesVersion(versionCourante) == composantesVersion(a.version) {
            bilan = .reussie(a.version)
        } else {
            try refuser(a.version)
            bilan = .ratee(a.version)
        }
        try FileManager.default.removeItem(at: fichierAttendue)
        return bilan
    }
}

/// La signature Ed25519 d'une archive, vérifiée avec la clé publique de l'appli.
public func signatureValide(_ donnees: Data, signatureBase64: String, clePubliqueBase64: String) -> Bool {
    guard let cle = Data(base64Encoded: clePubliqueBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
          let sig = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
          let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: cle) else { return false }
    return pub.isValidSignature(sig, for: donnees)
}
