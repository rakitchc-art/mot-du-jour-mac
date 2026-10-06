import XCTest
@testable import MotDuJourCore

final class MiseAJourTests: XCTestCase {

    func testLesVersions() {
        XCTAssertEqual(composantesVersion("1.2.3"), [1, 2, 3])
        XCTAssertEqual(composantesVersion("v1.2"), [1, 2])
        XCTAssertNil(composantesVersion("1..2"))
        XCTAssertNil(composantesVersion("1.2.3-beta"))
        XCTAssertNil(composantesVersion(""))
        XCTAssertNil(composantesVersion("1.2.3.4.5"))
        XCTAssertNil(composantesVersion("1.٣"), "un chiffre non ASCII n'est pas une version")
        XCTAssertTrue(estPlusRecente("1.0.10", que: "1.0.9"))
        XCTAssertFalse(estPlusRecente("1.0", que: "1.0.0"))
        XCTAssertFalse(estPlusRecente("1.0.0", que: "1.0"))
        XCTAssertTrue(estPlusRecente("v2", que: "1.9.9"))
        XCTAssertFalse(estPlusRecente("abc", que: "1.0"))
        XCTAssertFalse(estPlusRecente("9.9", que: "abc"), "dans le doute, on ne remplace rien")
    }

    /// Une vraie réponse de l'API GitHub, raccourcie (les champs en trop sont ignorés).
    func publication(tag: String = "v1.0.1", pieces: [String]? = nil, url: String = "https://github.com/x/y/releases/download",
                     draft: Bool = false) throws -> Publication {
        let noms = pieces ?? ["Mot-du-jour-1.0.1.zip", "Mot-du-jour-1.0.1.zip.sig", "Mot-du-jour-1.0.1.dmg"]
        let assets = noms.map { #"{"name":"\#($0)","size":1234,"browser_download_url":"\#(url)/\#(tag)/\#($0)"}"# }
        let json = #"{"url":"https://api.github.com/x","tag_name":"\#(tag)","name":"Mot du jour","draft":\#(draft),"prerelease":false,"assets":[\#(assets.joined(separator: ","))]}"#
        return try JSONDecoder().decode(Publication.self, from: Data(json.utf8))
    }

    func testUnePublicationPlusRecenteDonneUnPlan() throws {
        let plan = planDeMiseAJour(try publication(), versionCourante: "1.0.0", refusees: [])
        XCTAssertEqual(plan?.version, "1.0.1")
        XCTAssertEqual(plan?.archive.lastPathComponent, "Mot-du-jour-1.0.1.zip")
        XCTAssertEqual(plan?.signature.lastPathComponent, "Mot-du-jour-1.0.1.zip.sig")
    }

    func testLAdresseLocaleNeSertQuALEpreuve() throws {
        let local = URL(string: "http://127.0.0.1:8765/Mot-du-jour-1.0.1.zip")!
        XCTAssertFalse(adresseAcceptable(local, accepteLocal: false), "sans le drapeau, jamais de http")
        XCTAssertTrue(adresseAcceptable(local, accepteLocal: true))
        XCTAssertFalse(adresseAcceptable(URL(string: "http://exemple.org/x.zip")!, accepteLocal: true),
                       "même avec le drapeau, jamais du http vers une autre machine")
        XCTAssertTrue(adresseAcceptable(URL(string: "https://github.com/x.zip")!, accepteLocal: false))
        let p = try publication(url: "http://127.0.0.1:8765")
        XCTAssertNil(planDeMiseAJour(p, versionCourante: "1.0.0", refusees: []))
        XCTAssertEqual(planDeMiseAJour(p, versionCourante: "1.0.0", refusees: [], accepteLocal: true)?.version, "1.0.1")
    }

    func dossierTemporaire() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("mdj-maj-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: d) }
        return d
    }

    func testUnePoseReussie() throws {
        let m = MemoireMiseAJour(dossier: dossierTemporaire())
        XCTAssertEqual(try m.bilan(versionCourante: "1.0.0"), .rien)
        try m.annoncer(PoseAttendue(version: "1.0.1", depuis: "1.0.0", utc: "2026-10-06T10:00:00.000Z"))
        XCTAssertEqual(try m.bilan(versionCourante: "1.0.1"), .reussie("1.0.1"))
        XCTAssertNil(m.attendue(), "l'annonce est effacée")
        XCTAssertEqual(m.refusees(), [])
    }

    func testUnePoseRateeNeSeRetenteJamais() throws {
        let dossier = dossierTemporaire()
        let m = MemoireMiseAJour(dossier: dossier)
        try m.annoncer(PoseAttendue(version: "1.0.1", depuis: "1.0.0", utc: "2026-10-06T10:00:00.000Z"))
        XCTAssertEqual(try m.bilan(versionCourante: "1.0.0"), .ratee("1.0.1"))
        // Sur le DISQUE : un processus neuf le relit (c'est le redémarrage qui
        // rejouait la boucle dans TokenBar).
        let relue = MemoireMiseAJour(dossier: dossier)
        XCTAssertEqual(relue.refusees(), ["1.0.1"])
        XCTAssertNil(planDeMiseAJour(try publication(), versionCourante: "1.0.0", refusees: relue.refusees()))
        XCTAssertEqual(try relue.bilan(versionCourante: "1.0.0"), .rien, "rien à rejouer au démarrage suivant")
    }

    func testUneAnnonceIllisibleNeSurvitPas() throws {
        let dossier = dossierTemporaire()
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let m = MemoireMiseAJour(dossier: dossier)
        try Data("{ abîmé".utf8).write(to: dossier.appendingPathComponent("maj-attendue.json"))
        XCTAssertEqual(try m.bilan(versionCourante: "1.0.0"), .rien)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dossier.appendingPathComponent("maj-attendue.json").path))
    }

    func testRienAFaire() throws {
        XCTAssertNil(planDeMiseAJour(try publication(), versionCourante: "1.0.1", refusees: []), "déjà à jour")
        XCTAssertNil(planDeMiseAJour(try publication(), versionCourante: "1.2.0", refusees: []), "jamais en arrière")
        XCTAssertNil(planDeMiseAJour(try publication(), versionCourante: "1.0.0", refusees: ["1.0.1"]), "une version refusée ne se retente pas")
        XCTAssertNil(planDeMiseAJour(try publication(pieces: ["Mot-du-jour-1.0.1.zip"]), versionCourante: "1.0.0", refusees: []), "pas de signature, pas de pose")
        XCTAssertNil(planDeMiseAJour(try publication(url: "http://github.com/x"), versionCourante: "1.0.0", refusees: []), "jamais sans chiffrement")
        XCTAssertNil(planDeMiseAJour(try publication(draft: true), versionCourante: "1.0.0", refusees: []))
        XCTAssertNil(planDeMiseAJour(try publication(tag: "nouvelle"), versionCourante: "1.0.0", refusees: []))
    }
}
