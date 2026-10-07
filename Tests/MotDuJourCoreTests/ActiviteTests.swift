import XCTest
@testable import MotDuJourCore

final class ActiviteTests: XCTestCase {

    private func essai(_ utc: String) -> Essai { Essai(mot: "abces", couleurs: "ggggg", utc: utc) }

    private func carnet(_ grilles: [String: [String]]) -> Carnet {
        var c = Carnet(premierJour: "2026-10-01")
        for (jour, utcs) in grilles {
            var g = Grille(solution: "abces")
            g.essais = utcs.map(essai)
            c.grilles[jour] = g
        }
        return c
    }

    func testLesJoursJouesSontCeuxDesEssaisALHeureDuMac() {
        let paris = TimeZone(identifier: "Europe/Paris")!
        let c = carnet([
            "2026-10-06": ["2026-10-06T09:00:00.000Z", "2026-10-06T09:01:00.000Z"],
            // Rattrapée le lendemain : c'est le 7 qu'elle a joué, pas le 5.
            "2026-10-05": ["2026-10-07T08:00:00.000Z"],
            // 23 h 30 UTC le 7 = 1 h 30 le 8 à Paris.
            "2026-10-07": ["2026-10-07T23:30:00.000Z"],
        ])
        XCTAssertEqual(joursJoues(c, fuseau: paris), ["2026-10-06", "2026-10-07", "2026-10-08"])
        XCTAssertEqual(joursJoues(c, fuseau: TimeZone(identifier: "UTC")!), ["2026-10-06", "2026-10-07"])
    }

    func testUneGrilleOuverteSansEssaiNEstPasUnJourJoue() {
        var c = Carnet(premierJour: "2026-10-01")
        c.grilles["2026-10-06"] = Grille(solution: "abces")
        XCTAssertEqual(joursJoues(c), [])
    }

    func testUnHorodatageIlisibleNeCasseRien() {
        let c = carnet(["2026-10-06": ["pas une date", "2026-10-06T09:00:00.000Z"]])
        XCTAssertEqual(joursJoues(c, fuseau: TimeZone(identifier: "UTC")!), ["2026-10-06"])
    }

    func testOnSignaleCeQuiResteDansLaFenetreDuPlusAncienAuPlusRecent() {
        let joues: Set<String> = ["2026-09-20", "2026-10-01", "2026-10-03", "2026-10-07", "2026-10-09"]
        XCTAssertEqual(joursASignaler(joues: joues, deja: ["2026-10-03"], aujourdhui: "2026-10-07"),
                       ["2026-10-01", "2026-10-07"],
                       "le 20/09 est trop vieux, le 03 déjà accepté, le 09 dans le futur")
        XCTAssertEqual(joursASignaler(joues: joues, deja: [], aujourdhui: "2026-10-07", fenetre: 1), ["2026-10-07"])
        XCTAssertEqual(joursASignaler(joues: ["2026-10-07"], deja: ["2026-10-07"], aujourdhui: "2026-10-07"), [])
        XCTAssertEqual(joursASignaler(joues: joues, deja: [], aujourdhui: "n'importe quoi"), [])
    }

    func testLaFenetreDeSeptJoursEnTraverseUnMois() {
        // 2026-10-01 moins 6 jours = 2026-09-25 (inclus) ; le 24 est dehors.
        XCTAssertEqual(joursASignaler(joues: ["2026-09-24", "2026-09-25", "2026-10-01"], deja: [], aujourdhui: "2026-10-01"),
                       ["2026-09-25", "2026-10-01"])
    }
}
