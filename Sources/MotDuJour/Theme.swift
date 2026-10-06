import SwiftUI

/// L'apparence du panneau.
///
/// Deux familles, dessinées toutes deux sur les planches :
///  - « barre » : les couleurs du mot mystère de TokenBar, toujours sombre ;
///  - « mac »   : suit le réglage clair / sombre du Mac, couleurs de Wordle.
/// Et, pour chacune, avec ou sans clavier à l'écran. Choix de Dova (06/10) :
/// « mac », sans clavier (Delegue.theme) ; l'autre reste pour les planches.
struct Theme {
    enum Famille: String { case barre, mac }

    let famille: Famille
    let clair: Bool
    let clavier: Bool

    // La géométrie (en points).
    let tailleCase: CGFloat = 44
    let ecart: CGFloat = 5
    let marge: CGFloat = 18
    let hauteurEntete: CGFloat = 34
    let hauteurMessage: CGFloat = 30
    let hauteurClavier: CGFloat = 118
    let hauteurPied: CGFloat = 20
    let margeVerticale: CGFloat = 12

    var largeurGrille: CGFloat { 5 * tailleCase + 4 * ecart }
    var hauteurGrille: CGFloat { 6 * tailleCase + 5 * ecart }
    var largeur: CGFloat { largeurGrille + 2 * marge }
    var hauteur: CGFloat {
        2 * margeVerticale + hauteurEntete + 8 + hauteurGrille + hauteurMessage
            + (clavier ? hauteurClavier : 0) + hauteurPied
    }

    // Les couleurs.
    let fond: Color
    let encre: Color
    let grisTexte: Color
    let vert: Color
    let jaune: Color
    let grisCase: Color
    let bordVide: Color
    let bordActif: Color
    let bordPlein: Color
    let bordCurseur: Color
    let voileCurseur: Color
    let lettreSurCouleur: Color
    let lettreSaisie: Color
    let erreur: Color
    let touche: Color
    let encreTouche: Color
    let dessinPolice: Font.Design
    let rayon: CGFloat

    func couleur(_ teinte: Character) -> Color {
        switch teinte {
        case "v": return vert
        case "j": return jaune
        default: return grisCase
        }
    }

    static func de(_ famille: Famille, clair: Bool, clavier: Bool) -> Theme {
        switch famille {
        case .barre:
            // Les teintes exactes de Mot-Barre.ps1 (Get-CouleurCaseMot, Draw-CaseMot).
            return Theme(famille: .barre, clair: false, clavier: clavier,
                         fond: rvb(36, 35, 32), encre: rvb(236, 234, 229), grisTexte: rvb(160, 158, 152),
                         vert: rvb(83, 141, 78), jaune: rvb(181, 159, 59), grisCase: rvb(66, 64, 60),
                         bordVide: rvb(82, 80, 75), bordActif: rvb(110, 108, 102), bordPlein: rvb(150, 148, 142),
                         bordCurseur: rvb(236, 234, 229), voileCurseur: rvb(52, 51, 47),
                         lettreSurCouleur: rvb(250, 249, 245), lettreSaisie: rvb(250, 249, 245),
                         erreur: rvb(232, 120, 110), touche: rvb(82, 80, 75), encreTouche: rvb(236, 234, 229),
                         dessinPolice: .default, rayon: 5)
        case .mac:
            if clair {
                return Theme(famille: .mac, clair: true, clavier: clavier,
                             fond: rvb(248, 248, 248), encre: rvb(29, 29, 31), grisTexte: rvb(110, 110, 115),
                             vert: rvb(106, 170, 100), jaune: rvb(201, 180, 88), grisCase: rvb(120, 124, 126),
                             bordVide: rvb(211, 214, 218), bordActif: rvb(170, 174, 178), bordPlein: rvb(135, 138, 140),
                             bordCurseur: rvb(29, 29, 31), voileCurseur: rvb(236, 236, 240),
                             lettreSurCouleur: .white, lettreSaisie: rvb(29, 29, 31),
                             erreur: rvb(215, 60, 50), touche: rvb(211, 214, 218), encreTouche: rvb(29, 29, 31),
                             dessinPolice: .rounded, rayon: 7)
            }
            return Theme(famille: .mac, clair: false, clavier: clavier,
                         fond: rvb(30, 30, 32), encre: rvb(240, 240, 242), grisTexte: rvb(152, 152, 157),
                         vert: rvb(83, 141, 78), jaune: rvb(181, 159, 59), grisCase: rvb(58, 58, 60),
                         bordVide: rvb(58, 58, 60), bordActif: rvb(78, 78, 80), bordPlein: rvb(110, 111, 112),
                         bordCurseur: rvb(240, 240, 242), voileCurseur: rvb(44, 44, 46),
                         lettreSurCouleur: .white, lettreSaisie: rvb(240, 240, 242),
                         erreur: rvb(255, 105, 97), touche: rvb(80, 80, 84), encreTouche: rvb(240, 240, 242),
                         dessinPolice: .rounded, rayon: 7)
        }
    }
}

func rvb(_ r: Double, _ v: Double, _ b: Double) -> Color {
    Color(.sRGB, red: r / 255, green: v / 255, blue: b / 255, opacity: 1)
}
