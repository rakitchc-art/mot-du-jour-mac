import XCTest
@testable import MotDuJourCore

final class JeuTests: XCTestCase {

    let dico = Dictionnaire(solutionsBrut: "plume\nsalut\nplage\nradio\ntigre\nmouche\nbanc",
                            acceptesBrut: "ourse\nfleur\nmonde\npoire\nlivre\ncarte")

    func jeuNeuf(premierJour: String = "2026-10-01") -> Jeu {
        Jeu(dico: dico, carnet: Carnet(premierJour: premierJour))
    }

    func testLesMotsMalFormesSontEcartesALaLecture() {
        // « mouche » (6 lettres) et « banc » (4) ne sont pas des solutions.
        XCTAssertEqual(dico.solutions, ["plume", "salut", "plage", "radio", "tigre"])
    }

    func testTrouveAuTroisiemeEssai() {
        var jeu = jeuNeuf()
        let jour = "2026-10-07"
        let sol = jeu.solution(jour)!
        let faux = ["ourse", "fleur", "monde", "poire"].filter { $0 != sol }
        XCTAssertEqual(jeu.proposer(faux[0], jour: jour, aujourdhui: jour).estJoue, true)
        XCTAssertEqual(jeu.proposer(faux[1], jour: jour, aujourdhui: jour).estJoue, true)
        guard case .joue(let e) = jeu.proposer(sol, jour: jour, aujourdhui: jour) else { return XCTFail() }
        XCTAssertEqual(e.couleurs, "vvvvv")
        let g = jeu.grille(jour)!
        XCTAssertTrue(g.fini); XCTAssertTrue(g.trouve)
        XCTAssertEqual(g.essais.count, 3)
        XCTAssertFalse(g.finiUtc.isEmpty)
        XCTAssertEqual(jeu.proposer(faux[2], jour: jour, aujourdhui: jour), .dejaFini)
        XCTAssertFalse(jeu.jouable(jour, aujourdhui: jour))
    }

    func testUnMotInconnuNeCompteNiNEcrit() {
        var jeu = jeuNeuf()
        XCTAssertEqual(jeu.proposer("zzzzz", jour: "2026-10-07", aujourdhui: "2026-10-07"), .inconnu)
        XCTAssertNil(jeu.grille("2026-10-07"))
        XCTAssertEqual(jeu.proposer("abc", jour: "2026-10-07", aujourdhui: "2026-10-07"), .malforme)
        XCTAssertEqual(jeu.proposer("PLUME", jour: "2026-10-07", aujourdhui: "2026-10-07"), .malforme)
    }

    func testSixEssaisRatesFinissentLaGrille() {
        var jeu = jeuNeuf()
        let jour = "2026-10-07"
        let sol = jeu.solution(jour)!
        let faux = (["ourse", "fleur", "monde", "poire", "livre", "carte", "plume", "salut", "plage"])
            .filter { $0 != sol }
        for k in 0..<6 {
            XCTAssertTrue(jeu.proposer(faux[k], jour: jour, aujourdhui: jour).estJoue)
        }
        let g = jeu.grille(jour)!
        XCTAssertTrue(g.fini); XCTAssertFalse(g.trouve)
        XCTAssertEqual(jeu.proposer(sol, jour: jour, aujourdhui: jour), .dejaFini)
    }

    func testLesBornesDeLInstallationAAujourdhui() {
        var jeu = jeuNeuf(premierJour: "2026-10-05")
        XCTAssertEqual(jeu.proposer("ourse", jour: "2026-10-04", aujourdhui: "2026-10-07"), .horsBornes)
        XCTAssertEqual(jeu.proposer("ourse", jour: "2026-10-08", aujourdhui: "2026-10-07"), .horsBornes)
        XCTAssertEqual(jeu.proposer("ourse", jour: "pas-une-date", aujourdhui: "2026-10-07"), .horsBornes)
        // Un jour passé depuis l'installation se rattrape.
        let sol = jeu.solution("2026-10-05")!
        let essai = sol == "ourse" ? "fleur" : "ourse"
        XCTAssertTrue(jeu.proposer(essai, jour: "2026-10-05", aujourdhui: "2026-10-07").estJoue)
        XCTAssertTrue(jeu.jouable("2026-10-05", aujourdhui: "2026-10-07"))
        XCTAssertFalse(jeu.jouable("2026-10-04", aujourdhui: "2026-10-07"))
    }

    func testLaSolutionCopieeSurvitAUneListeChangee() {
        var jeu = jeuNeuf()
        let jour = "2026-10-07"
        let sol = jeu.solution(jour)!
        let essai = sol == "ourse" ? "fleur" : "ourse"
        XCTAssertTrue(jeu.proposer(essai, jour: jour, aujourdhui: jour).estJoue)
        // Une mise à jour arrive avec une liste où ce mot n'existe plus.
        let autre = Dictionnaire(solutionsBrut: "zebre\nlapin\nchien", acceptesBrut: "ourse\nfleur")
        var suite = Jeu(dico: autre, carnet: jeu.carnet)
        XCTAssertEqual(suite.solution(jour), sol)
        guard case .joue(let e) = suite.proposer(sol, jour: jour, aujourdhui: jour) else { return XCTFail() }
        XCTAssertEqual(e.couleurs, "vvvvv")
        // Un jour pas encore commencé, lui, prend le mot de la nouvelle liste.
        XCTAssertTrue(["zebre", "lapin", "chien"].contains(suite.solution("2026-10-08")!))
    }

    func testRecalerPremierJourQuandLHorlogeRecule() {
        var jeu = jeuNeuf(premierJour: "2026-10-07")
        XCTAssertFalse(jeu.recalerPremierJour(aujourdhui: "2026-10-08"))
        XCTAssertTrue(jeu.recalerPremierJour(aujourdhui: "2026-10-03"))
        XCTAssertEqual(jeu.carnet.premierJour, "2026-10-03")
    }

    // MARK: le dépôt

    func dossierTemporaire() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("mdj-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: d) }
        return d
    }

    func testDepotAllerRetour() throws {
        let depot = Depot(dossier: dossierTemporaire())
        let neuf = depot.charger(aujourdhui: "2026-10-07")
        XCTAssertNil(neuf.avertissement)
        XCTAssertEqual(neuf.carnet.premierJour, "2026-10-07")
        var jeu = Jeu(dico: dico, carnet: neuf.carnet)
        let sol = jeu.solution("2026-10-07")!
        _ = jeu.proposer(sol, jour: "2026-10-07", aujourdhui: "2026-10-07")
        try depot.enregistrer(jeu.carnet)
        let relu = depot.charger(aujourdhui: "2026-10-09")
        XCTAssertNil(relu.avertissement)
        XCTAssertEqual(relu.carnet, jeu.carnet)
    }

    func testUnCarnetIllisibleEstMisDeCoteJamaisEcrase() throws {
        let dossier = dossierTemporaire()
        let depot = Depot(dossier: dossier)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try Data("{ pas du json".utf8).write(to: depot.fichier)
        let r = depot.charger(aujourdhui: "2026-10-07")
        XCTAssertNotNil(r.avertissement)
        XCTAssertEqual(r.carnet.premierJour, "2026-10-07")
        let restes = try FileManager.default.contentsOfDirectory(atPath: dossier.path)
        XCTAssertTrue(restes.contains { $0.hasPrefix("carnet-illisible-") }, "\(restes)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: depot.fichier.path))
    }

    func testUneGrilleSeRelitAvecDesChampsManquants() throws {
        let json = #"{"premierJour":"2026-10-01","grilles":{"2026-10-02":{"solution":"plume","essais":[{"mot":"plume","couleurs":"vvvvv","utc":"2026-10-02T08:00:00.000Z"}]}}}"#
        let c = try JSONDecoder().decode(Carnet.self, from: Data(json.utf8))
        XCTAssertEqual(c.format, 1)
        XCTAssertEqual(c.grilles["2026-10-02"]?.essais.count, 1)
        XCTAssertEqual(c.grilles["2026-10-02"]?.fini, false)
    }
}

extension Verdict {
    var estJoue: Bool { if case .joue = self { return true } else { return false } }
}
