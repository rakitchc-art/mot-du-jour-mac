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

/// Que faire de la dernière publication ? nil = rien.
public func planDeMiseAJour(_ p: Publication, versionCourante: String, refusees: Set<String>) -> PlanMiseAJour? {
    if p.draft == true || p.prerelease == true { return nil }
    guard let comps = composantesVersion(p.tag_name) else { return nil }
    let version = comps.map(String.init).joined(separator: ".")
    guard estPlusRecente(version, que: versionCourante), !refusees.contains(version) else { return nil }
    let nom = nomArchive(version: version)
    guard let a = p.assets.first(where: { $0.name == nom }),
          let s = p.assets.first(where: { $0.name == nom + ".sig" }),
          let ua = URL(string: a.browser_download_url), let us = URL(string: s.browser_download_url),
          ua.scheme == "https", us.scheme == "https" else { return nil }
    return PlanMiseAJour(version: version, archive: ua, signature: us)
}

/// La signature Ed25519 d'une archive, vérifiée avec la clé publique de l'appli.
public func signatureValide(_ donnees: Data, signatureBase64: String, clePubliqueBase64: String) -> Bool {
    guard let cle = Data(base64Encoded: clePubliqueBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
          let sig = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
          let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: cle) else { return false }
    return pub.isValidSignature(sig, for: donnees)
}
