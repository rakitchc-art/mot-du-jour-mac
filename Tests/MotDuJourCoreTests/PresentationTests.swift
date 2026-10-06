import XCTest
@testable import MotDuJourCore

final class PresentationTests: XCTestCase {

    let dico = Dictionnaire(solutionsBrut: "plume\nsalut\nplage\nradio\ntigre",
                            acceptesBrut: "ourse\nfleur\nmonde\npoire\nlivre\ncarte")
    let utc = TimeZone(secondsFromGMT: 0)!

    func vue(_ jeu: Jeu, _ jour: String, aujourdhui: String = "2026-10-06",
             saisie: Saisie = Saisie(), message: MessagePassager? = nil) -> VueEtat {
        presenter(jeu: jeu, jour: jour, aujourdhui: aujourdhui, saisie: saisie, message: message,
                  vueStats: false, fuseau: utc)
    }

    func testLePremierJour() {
        let jeu = Jeu(dico: dico, carnet: Carnet(premierJour: "2026-10-06"))
        let v = vue(jeu, "2026-10-06")
        XCTAssertEqual(v.titre, "Mot du jour")
        XCTAssertEqual(v.sousTitre, "mardi 6 octobre")
        XCTAssertEqual(v.message, "Tape le mot, puis Entrée")
        XCTAssertFalse(v.precedentPossible, "rien avant l'installation")
        XCTAssertFalse(v.suivantPossible)
        XCTAssertEqual(v.ligneEnCours, 0)
        XCTAssertEqual(v.lignes.count, 6)
        XCTAssertTrue(v.lignes.allSatisfy { $0.count == 5 })
        XCTAssertTrue(v.lignes[0][0].curseur)
        XCTAssertTrue(v.lignes[0].allSatisfy { $0.active })
    }

    func testTrouveEtRate() {
        var jeu = Jeu(dico: dico, carnet: Carnet(premierJour: "2026-10-01"))
        let sol = jeu.solution("2026-10-06")!
        let faux = sol == "ourse" ? "fleur" : "ourse"
        _ = jeu.proposer(faux, jour: "2026-10-06", aujourdhui: "2026-10-06")
        _ = jeu.proposer(sol, jour: "2026-10-06", aujourdhui: "2026-10-06")
        var v = vue(jeu, "2026-10-06")
        XCTAssertEqual(v.message, "Trouvé en 2 !")
        XCTAssertNil(v.ligneEnCours)
        XCTAssertEqual(v.resultatDuJour, 2)
        XCTAssertEqual(v.lignes[1].map { $0.teinte }, Array(repeating: Character?("v"), count: 5))
        XCTAssertTrue(v.precedentPossible)

        let solHier = jeu.solution("2026-10-05")!
        let mauvais = ["ourse", "fleur", "monde", "poire", "livre", "carte", "plume", "salut"].filter { $0 != solHier }
        for k in 0..<6 { _ = jeu.proposer(mauvais[k], jour: "2026-10-05", aujourdhui: "2026-10-06") }
        v = vue(jeu, "2026-10-05")
        XCTAssertEqual(v.titre, "Hier")
        XCTAssertEqual(v.sousTitre, "lundi 5 octobre", "hier fini : la date")
        XCTAssertEqual(v.message, "C'était \(solHier.uppercased())")
        XCTAssertEqual(v.resultatDuJour, 7)
        XCTAssertTrue(v.suivantPossible)
    }

    func testUnJourPasseARattraper() {
        let jeu = Jeu(dico: dico, carnet: Carnet(premierJour: "2026-10-01"))
        let v = vue(jeu, "2026-10-03")
        XCTAssertEqual(v.titre, "3 octobre")
        XCTAssertEqual(v.sousTitre, "samedi · à rattraper")
        XCTAssertEqual(vue(jeu, "2026-10-05").sousTitre, "à rattraper", "hier pas joué")
        XCTAssertEqual(v.ligneEnCours, 0)
        XCTAssertTrue(v.precedentPossible)
        XCTAssertTrue(v.suivantPossible)
    }

    func testLeMessagePassagerPasseDevant() {
        let jeu = Jeu(dico: dico, carnet: Carnet(premierJour: "2026-10-06"))
        var s = Saisie(); for c in "zzzzz" { s.taper(c) }
        let v = vue(jeu, "2026-10-06", saisie: s, message: MessagePassager("Mot inconnu", erreur: true))
        XCTAssertEqual(v.message, "Mot inconnu")
        XCTAssertTrue(v.messageErreur)
        XCTAssertEqual(v.lignes[0].compactMap { $0.lettre }, Array("zzzzz"))
        XCTAssertFalse(v.lignes[0].contains { $0.curseur }, "curseur après la dernière case")
    }

    func testLeClavierGardeLaMeilleureCouleur() {
        var c = Carnet(premierJour: "2026-10-01")
        var g = Grille(solution: "plume")
        g.essais = [Essai(mot: "salut", couleurs: couleurs(essai: "salut", solution: "plume"), utc: "2026-10-06T08:00:00.000Z"),
                    Essai(mot: "plage", couleurs: couleurs(essai: "plage", solution: "plume"), utc: "2026-10-06T08:01:00.000Z")]
        c.grilles["2026-10-06"] = g
        let v = vue(Jeu(dico: dico, carnet: c), "2026-10-06")
        XCTAssertEqual(v.lettresClavier["l"], "v", "jaune dans salut, vert dans plage : vert gagne")
        XCTAssertEqual(v.lettresClavier["u"], "j")
        XCTAssertEqual(v.lettresClavier["s"], "g")
        XCTAssertEqual(v.lettresClavier["e"], "v")
        XCTAssertNil(v.lettresClavier["z"])
    }
}
