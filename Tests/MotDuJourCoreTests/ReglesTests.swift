import XCTest
import CryptoKit
@testable import MotDuJourCore

/// Les règles, prouvées contre des réponses de RÉFÉRENCE (vecteurs.json,
/// fabriqué par scripts/generer-vecteurs.js) : les couleurs par la fonction du
/// vrai serveur TokenBar, l'ordre des mots par une seconde implémentation en
/// Node, la signature par la cryptographie de Node.
final class ReglesTests: XCTestCase {

    struct Vecteurs: Decodable {
        struct Couleur: Decodable { let essai: String; let solution: String; let couleurs: String }
        struct MotJour: Decodable { let jour: String; let numero: Int; let mot: String }
        struct Ordre: Decodable {
            let cle: String; let origine: String; let nombre: Int
            let empreinteSolutions: String; let tete: [String]; let motsDuJour: [MotJour]
        }
        struct Signature: Decodable {
            let clePublique: String; let message: String; let signature: String; let signatureAbimee: String
        }
        let couleurs: [Couleur]
        let ordre: Ordre
        let signature: Signature
    }

    static let vecteurs: Vecteurs = {
        let url = Bundle.module.url(forResource: "vecteurs", withExtension: "json")!
        return try! JSONDecoder().decode(Vecteurs.self, from: Data(contentsOf: url))
    }()

    // MARK: couleurs

    func testCouleursCommeLeServeurTokenBar() {
        let v = Self.vecteurs.couleurs
        // Un fichier vide ferait passer la boucle sans rien prouver.
        XCTAssertGreaterThan(v.count, 2_000)
        var fautes = 0
        for c in v where couleurs(essai: c.essai, solution: c.solution) != c.couleurs {
            fautes += 1
            if fautes <= 5 {
                XCTFail("\(c.essai) contre \(c.solution) : \(couleurs(essai: c.essai, solution: c.solution)), le serveur dit \(c.couleurs)")
            }
        }
        XCTAssertEqual(fautes, 0)
    }

    func testCouleursRefusentUnMotDeLaMauvaiseLongueur() {
        XCTAssertEqual(couleurs(essai: "abc", solution: "plume"), "")
        XCTAssertEqual(couleurs(essai: "plume", solution: "plumes"), "")
    }

    // MARK: jours

    func testNumeroDeJour() {
        XCTAssertEqual(numeroDeJour("1970-01-01"), 0)
        XCTAssertEqual(numeroDeJour("1970-01-02"), 1)
        XCTAssertEqual(numeroDeJour("1969-12-31"), -1)
        for m in Self.vecteurs.ordre.motsDuJour {
            XCTAssertEqual(numeroDeJour(m.jour), m.numero, m.jour)
        }
        for n in stride(from: -800, through: 40_000, by: 1) {
            let j = jourDeNumero(n)
            XCTAssertEqual(numeroDeJour(j), n, j)
            if numeroDeJour(j) != n { break }
        }
    }

    func testDatesImpossiblesRefusees() {
        for j in ["2026-02-29", "2026-13-01", "2026-00-10", "2026-04-31", "2026-1-01", "26-01-01",
                  "2026-01-1", "abcd-ef-gh", "", "2026-01-01-", "2026--01-01", "+026-01-01"] {
            XCTAssertNil(numeroDeJour(j), j)
        }
        XCTAssertNotNil(numeroDeJour("2028-02-29"))
        XCTAssertNotNil(numeroDeJour("2000-02-29"))
        XCTAssertNil(numeroDeJour("2100-02-29"))
    }

    func testJourLocalSuitLeFuseauEtResteGregorien() {
        let instant = dateDe("2026-10-06T22:30:00Z")!
        XCTAssertEqual(jourLocal(instant, fuseau: TimeZone(identifier: "Europe/Paris")!), "2026-10-07")
        XCTAssertEqual(jourLocal(instant, fuseau: TimeZone(identifier: "America/New_York")!), "2026-10-06")
        XCTAssertEqual(jourLocal(instant, fuseau: TimeZone(secondsFromGMT: 0)!), "2026-10-06")
    }

    func testHorodatageAllerRetour() {
        let d = Date(timeIntervalSince1970: 1_791_000_000.123)
        let h = horodatage(d)
        XCTAssertTrue(h.hasSuffix("Z"), h)
        XCTAssertEqual(dateDe(h)!.timeIntervalSince1970, d.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertNotNil(dateDe("2026-10-06T09:12:34Z"))
        XCTAssertNil(dateDe("hier"))
    }

    func testTitreDuJour() {
        XCTAssertEqual(titreDuJour("2026-10-07", aujourdhui: "2026-10-07"), "Mot du jour")
        XCTAssertEqual(titreDuJour("2026-10-06", aujourdhui: "2026-10-07"), "Hier")
        XCTAssertEqual(titreDuJour("2026-10-05", aujourdhui: "2026-10-07"), "lundi 5 octobre")
        XCTAssertEqual(titreDuJour("2027-01-01", aujourdhui: "2027-01-03"), "vendredi 1 janvier")
    }

    // MARK: l'ordre des mots

    func testOrdreDesMotsCommeLaSecondeImplementation() {
        let o = Self.vecteurs.ordre
        let dico = Dictionnaire.livre
        XCTAssertEqual(Regles.cleOrdre, o.cle)
        XCTAssertEqual(Regles.origine, o.origine)
        XCTAssertEqual(dico.ordre.count, o.nombre)
        XCTAssertEqual(Array(dico.ordre.prefix(10)), o.tete)
        XCTAssertGreaterThan(o.motsDuJour.count, 5)
        for m in o.motsDuJour {
            XCTAssertEqual(dico.motDuJour(m.jour), m.mot, m.jour)
        }
    }

    /// La garde de la liste des solutions : la changer décale le mot de chaque
    /// jour. Ce contrôle rougit si Mots.swift est retouché à la main ; après un
    /// `Generer-Mots.ps1 -ChangerSolutions` voulu, on régénère les vecteurs.
    func testListeDesSolutionsFigee() {
        let dico = Dictionnaire.livre
        let empreinte = SHA256.hash(data: Data(dico.solutions.joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(empreinte, Self.vecteurs.ordre.empreinteSolutions)
    }

    func testPasDeRepetitionAvantLaFinDuTour() {
        let dico = Dictionnaire.livre
        let n0 = numeroDeJour(Regles.origine)!
        var vus = Set<String>()
        for i in 0..<dico.ordre.count { vus.insert(dico.motDuJour(jourDeNumero(n0 + i))!) }
        XCTAssertEqual(vus.count, dico.ordre.count)
    }

    func testLesSolutionsSontAcceptees() {
        let dico = Dictionnaire.livre
        XCTAssertTrue(dico.solutions.allSatisfy(dico.accepte))
        XCTAssertGreaterThan(dico.acceptes.count, 7_000)
        XCTAssertFalse(dico.accepte("zzzzz"))
    }

    // MARK: la frappe

    func testLettreDeTouche() {
        XCTAssertEqual(lettreDeTouche("é"), "e")
        XCTAssertEqual(lettreDeTouche("É"), "e")
        XCTAssertEqual(lettreDeTouche("ç"), "c")
        XCTAssertEqual(lettreDeTouche("ü"), "u")
        XCTAssertEqual(lettreDeTouche("A"), "a")
        XCTAssertEqual(lettreDeTouche("z"), "z")
        XCTAssertNil(lettreDeTouche("œ"))
        XCTAssertNil(lettreDeTouche("1"))
        XCTAssertNil(lettreDeTouche("ab"))
        XCTAssertNil(lettreDeTouche(" "))
        XCTAssertNil(lettreDeTouche(""))
    }

    func testEstMotValide() {
        XCTAssertTrue(estMotValide("plume"))
        XCTAssertFalse(estMotValide("Plume"))
        XCTAssertFalse(estMotValide("plumé"))
        XCTAssertFalse(estMotValide("plum"))
        XCTAssertFalse(estMotValide("plumes"))
    }

    // MARK: la signature des mises à jour

    func testSignatureDeNodeAccepteeParCryptoKit() {
        let s = Self.vecteurs.signature
        let message = Data(base64Encoded: s.message)!
        XCTAssertTrue(signatureValide(message, signatureBase64: s.signature, clePubliqueBase64: s.clePublique))
        XCTAssertFalse(signatureValide(message, signatureBase64: s.signatureAbimee, clePubliqueBase64: s.clePublique))
        var autre = message; autre.append(0x20)
        XCTAssertFalse(signatureValide(autre, signatureBase64: s.signature, clePubliqueBase64: s.clePublique))
        XCTAssertFalse(signatureValide(message, signatureBase64: "pas du base64", clePubliqueBase64: s.clePublique))
        XCTAssertFalse(signatureValide(message, signatureBase64: s.signature, clePubliqueBase64: "AAAA"))
    }
}
