import Foundation

/// Les cinq cases de la ligne en cours, et le curseur.
///
/// Le comportement de TokenBar depuis le 05/10/2026 (Dova : « on devrait
/// pouvoir sélectionner la lettre qu'on modifie ») : un clic sur une case y
/// pose le curseur ; la lettre tapée REMPLACE celle de la case et le curseur
/// passe à la suivante ; ← → le déplacent ; Retour efface la case du curseur
/// si elle est pleine, sinon la précédente — la frappe ordinaire, de gauche à
/// droite, se comporte comme partout. Entrée n'envoie que cinq lettres pleines.
public struct Saisie: Equatable {
    public private(set) var cases: [Character?] = Array(repeating: nil, count: 5)
    /// 0 à 4 : la case où tombera la prochaine lettre ; 5 : après la dernière.
    public private(set) var curseur = 0

    public init() {}

    public var prete: Bool { cases.allSatisfy { $0 != nil } }
    public var vide: Bool { cases.allSatisfy { $0 == nil } }
    public var mot: String { String(cases.compactMap { $0 }) }

    @discardableResult
    public mutating func taper(_ lettre: Character) -> Bool {
        guard curseur >= 0, curseur < 5 else { return false }
        cases[curseur] = lettre
        curseur += 1
        return true
    }

    @discardableResult
    public mutating func effacer() -> Bool {
        if curseur < 5, cases[curseur] != nil {
            cases[curseur] = nil
        } else if curseur > 0 {
            curseur -= 1
            cases[curseur] = nil
        } else {
            return false
        }
        return true
    }

    @discardableResult
    public mutating func deplacer(_ pas: Int) -> Bool {
        let k = max(0, min(5, curseur + pas))
        guard k != curseur else { return false }
        curseur = k
        return true
    }

    /// Un clic sur une case de la ligne en cours (0 à 4).
    @discardableResult
    public mutating func placer(_ index: Int) -> Bool {
        let k = max(0, min(4, index))
        guard k != curseur else { return false }
        curseur = k
        return true
    }

    public mutating func vider() {
        cases = Array(repeating: nil, count: 5)
        curseur = 0
    }
}
