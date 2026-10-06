import XCTest
@testable import MotDuJourCore

final class SaisieTests: XCTestCase {

    func taper(_ s: inout Saisie, _ texte: String) { for c in texte { s.taper(c) } }

    func testLaFrappeOrdinaire() {
        var s = Saisie()
        taper(&s, "plume")
        XCTAssertTrue(s.prete)
        XCTAssertEqual(s.mot, "plume")
        XCTAssertEqual(s.curseur, 5)
        XCTAssertFalse(s.taper("x"), "une sixième lettre n'a nulle part où aller")
        XCTAssertTrue(s.effacer())
        XCTAssertEqual(s.mot, "plum"); XCTAssertEqual(s.curseur, 4)
        XCTAssertFalse(s.prete)
    }

    func testLeCurseurCommeDansTokenBar() {
        var s = Saisie()
        taper(&s, "xchec")
        // « on peut faire Xchec et modifier le X » : clic sur la 1re case.
        XCTAssertTrue(s.placer(0))
        s.taper("e")
        XCTAssertEqual(s.mot, "echec")
        XCTAssertEqual(s.curseur, 1)
        // Retour sur une case PLEINE : elle s'efface sur place, le curseur reste.
        XCTAssertTrue(s.effacer())
        XCTAssertEqual(s.curseur, 1)
        XCTAssertEqual(s.cases[1], nil)
        XCTAssertFalse(s.prete)
        // Sur une case vide : il recule et efface la précédente.
        XCTAssertTrue(s.effacer())
        XCTAssertEqual(s.curseur, 0)
        XCTAssertEqual(s.cases[0], nil)
        XCTAssertFalse(s.effacer(), "rien avant la première case")
    }

    func testDesTrousAuMilieu() {
        var s = Saisie()
        s.placer(2)
        s.taper("c")
        XCTAssertEqual(s.cases, [nil, nil, "c", nil, nil])
        XCTAssertFalse(s.prete)
        XCTAssertFalse(s.vide)
        XCTAssertEqual(s.curseur, 3)
    }

    func testLesFlechesRestentDansLesBornes() {
        var s = Saisie()
        XCTAssertFalse(s.deplacer(-1))
        XCTAssertTrue(s.deplacer(+3))
        XCTAssertTrue(s.deplacer(+9))
        XCTAssertEqual(s.curseur, 5)
        XCTAssertFalse(s.deplacer(+1))
        XCTAssertTrue(s.placer(9))
        XCTAssertEqual(s.curseur, 4, "un clic tombe toujours sur une case")
        s.vider()
        XCTAssertTrue(s.vide); XCTAssertEqual(s.curseur, 0)
    }
}

final class StatsTests: XCTestCase {

    let utc = TimeZone(secondsFromGMT: 0)!

    func grille(_ essais: Int, trouve: Bool, le jour: String) -> Grille {
        var g = Grille(solution: "plume")
        for k in 0..<essais {
            let gagnant = trouve && k == essais - 1
            g.essais.append(Essai(mot: gagnant ? "plume" : "ourse", couleurs: gagnant ? "vvvvv" : "ggggg",
                                  utc: "\(jour)T12:00:00.000Z"))
        }
        g.trouve = trouve
        g.fini = trouve || essais >= 6
        if g.fini { g.finiUtc = "\(jour)T12:05:00.000Z" }
        return g
    }

    func carnetType() -> Carnet {
        var c = Carnet(premierJour: "2026-10-01")
        c.grilles["2026-10-01"] = grille(3, trouve: true, le: "2026-10-01")
        c.grilles["2026-10-02"] = grille(4, trouve: true, le: "2026-10-02")
        // le 03 : pas joué — la série casse
        c.grilles["2026-10-04"] = grille(6, trouve: false, le: "2026-10-04")
        c.grilles["2026-10-05"] = grille(2, trouve: true, le: "2026-10-05")
        c.grilles["2026-10-06"] = grille(1, trouve: true, le: "2026-10-07")   // rattrapé le lendemain
        c.grilles["2026-10-07"] = grille(2, trouve: false, le: "2026-10-07")  // aujourd'hui, en cours
        return c
    }

    func testLesStatsDUnCarnetType() {
        let s = statistiques(carnetType(), aujourdhui: "2026-10-07", fuseau: utc)
        XCTAssertEqual(s.joues, 5)
        XCTAssertEqual(s.trouves, 4)
        XCTAssertEqual(s.reussite, 80)
        XCTAssertEqual(s.distribution, [1, 1, 1, 1, 0, 0, 1])
        XCTAssertEqual(s.serie, 2, "aujourd'hui pas fini ne casse pas la série")
        XCTAssertEqual(s.meilleureSerie, 2)
        XCTAssertEqual(s.moyenneEssais!, 2.5, accuracy: 1e-9)
        XCTAssertEqual(s.rattrapes, 1)
    }

    func testAujourdhuiCompteQuandIlEstFini() {
        var c = carnetType()
        c.grilles["2026-10-07"] = grille(5, trouve: true, le: "2026-10-07")
        let s = statistiques(c, aujourdhui: "2026-10-07", fuseau: utc)
        XCTAssertEqual(s.joues, 6)
        XCTAssertEqual(s.serie, 3)
        XCTAssertEqual(s.meilleureSerie, 3)
    }

    func testHierPasJoueCasseLaSerie() {
        var c = carnetType()
        c.grilles["2026-10-08"] = nil
        let s = statistiques(c, aujourdhui: "2026-10-09", fuseau: utc)
        XCTAssertEqual(s.serie, 0)
        XCTAssertEqual(s.meilleureSerie, 2)
    }

    /// Le relecteur du 06/10 l'a montré : aucun test ne prouvait cette règle
    /// (en la retirant d'une copie, tout restait vert). Trouvé / RIEN / trouvé :
    /// la série vaut 1, pas 2.
    func testUnJourPasseSansGrilleCasseLaSerie() {
        var c = Carnet(premierJour: "2026-10-01")
        c.grilles["2026-10-01"] = grille(3, trouve: true, le: "2026-10-01")
        // le 02 : pas joué
        c.grilles["2026-10-03"] = grille(2, trouve: true, le: "2026-10-03")
        let s = statistiques(c, aujourdhui: "2026-10-03", fuseau: utc)
        XCTAssertEqual(s.serie, 1)
        XCTAssertEqual(s.meilleureSerie, 1)
        XCTAssertEqual(s.joues, 2)
    }

    func testUnCarnetNeuf() {
        let s = statistiques(Carnet(premierJour: "2026-10-07"), aujourdhui: "2026-10-07", fuseau: utc)
        XCTAssertEqual(s, Statistiques())
        XCTAssertNil(s.reussite)
        XCTAssertNil(s.moyenneEssais)
    }
}
