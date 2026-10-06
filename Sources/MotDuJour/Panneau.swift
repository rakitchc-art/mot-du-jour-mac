import SwiftUI
import MotDuJourCore

// ===========================================================================
//  Le panneau qui tombe sous l'icône. Ces vues ne contiennent AUCUNE règle de
//  jeu : elles dessinent un `VueEtat` (calculé par `presenter`, dans le cœur)
//  et renvoient les gestes par des `Actions`. La planche les nourrit avec des
//  états fabriqués ; l'appli, avec le vrai carnet.
// ===========================================================================

enum ToucheClavier: Equatable {
    case lettre(Character)
    case entree
    case effacer
}

struct Actions {
    var precedent: () -> Void = {}
    var suivant: () -> Void = {}
    var basculerStats: () -> Void = {}
    var clicCase: (Int) -> Void = { _ in }
    var touche: (ToucheClavier) -> Void = { _ in }
    var menu: () -> Void = {}
}

struct PanneauVue: View {
    let etat: VueEtat
    let theme: Theme
    var secousse = 0
    var actions = Actions()

    var body: some View {
        VStack(spacing: 0) {
            Entete(etat: etat, theme: theme, actions: actions)
                .frame(height: theme.hauteurEntete)
            Spacer().frame(height: 8)
            if etat.vueStats {
                VueStatistiques(stats: etat.stats, resultat: etat.resultatDuJour, theme: theme)
                    .frame(height: theme.hauteurGrille + theme.hauteurMessage + (theme.clavier ? theme.hauteurClavier : 0),
                           alignment: .top)
            } else {
                GrilleVue(etat: etat, theme: theme, secousse: secousse, clicCase: actions.clicCase)
                Text(etat.message)
                    .font(.system(size: 12, weight: .medium, design: theme.dessinPolice))
                    .foregroundColor(etat.messageErreur ? theme.erreur : theme.grisTexte)
                    .lineLimit(1)
                    .frame(height: theme.hauteurMessage)
                if theme.clavier {
                    ClavierVue(lettres: etat.lettresClavier, theme: theme, touche: actions.touche)
                        .frame(height: theme.hauteurClavier, alignment: .top)
                }
            }
            PiedDePage(theme: theme, menu: actions.menu)
                .frame(height: theme.hauteurPied)
        }
        .padding(.horizontal, theme.marge)
        .padding(.vertical, theme.margeVerticale)
        .frame(width: theme.largeur, height: theme.hauteur)
        .background(theme.fond)
    }
}

// MARK: - L'en-tête : ‹ titre › et le bouton des statistiques

struct Entete: View {
    let etat: VueEtat
    let theme: Theme
    let actions: Actions

    var body: some View {
        HStack(spacing: 6) {
            Fleche(gauche: true, visible: etat.precedentPossible, theme: theme, action: actions.precedent)
            VStack(alignment: .leading, spacing: 1) {
                Text(etat.titre)
                    .font(.system(size: 15, weight: .semibold, design: theme.dessinPolice))
                    .foregroundColor(theme.encre)
                    .lineLimit(1)
                if let s = etat.sousTitre {
                    Text(s)
                        .font(.system(size: 10.5, weight: .regular, design: theme.dessinPolice))
                        .foregroundColor(theme.grisTexte)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            BoutonStats(actif: etat.vueStats, theme: theme, action: actions.basculerStats)
            Fleche(gauche: false, visible: etat.suivantPossible, theme: theme, action: actions.suivant)
        }
    }
}

/// Une flèche des jours. Invisible (mais à sa place) quand il n'y a rien de
/// ce côté-là : le titre ne bouge pas d'un jour à l'autre.
struct Fleche: View {
    let gauche: Bool
    let visible: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: gauche ? "chevron.left" : "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.encre)
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .disabled(!visible)
        .help(gauche ? "Le jour d'avant" : "Le jour d'après")
    }
}

struct BoutonStats: View {
    let actif: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(actif ? theme.fond : theme.encre)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(actif ? theme.encre : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(theme.bordPlein, lineWidth: actif ? 0 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(actif ? "Revenir à la grille" : "Tes statistiques")
    }
}

// MARK: - La grille

struct GrilleVue: View {
    let etat: VueEtat
    let theme: Theme
    let secousse: Int
    let clicCase: (Int) -> Void

    var body: some View {
        VStack(spacing: theme.ecart) {
            ForEach(0..<etat.lignes.count, id: \.self) { r in
                HStack(spacing: theme.ecart) {
                    ForEach(0..<5, id: \.self) { c in
                        CaseVue(c: etat.lignes[r][c], theme: theme)
                            .contentShape(Rectangle())
                            .onTapGesture { if r == etat.ligneEnCours { clicCase(c) } }
                    }
                }
                .modifier(Secousse(phase: r == etat.ligneEnCours ? CGFloat(secousse) : 0))
                .animation(.linear(duration: 0.45), value: secousse)
            }
        }
        .frame(width: theme.largeurGrille, height: theme.hauteurGrille)
    }
}

/// La ligne qui tremble quand un mot est refusé (0,45 s, comme dans TokenBar).
struct Secousse: GeometryEffect {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(phase * .pi * 4), y: 0))
    }
}

struct CaseVue: View {
    let c: VueEtat.Case
    let theme: Theme

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: theme.rayon, style: .continuous)
        ZStack {
            if let t = c.teinte {
                forme.fill(theme.couleur(t))
            } else {
                if c.curseur { forme.fill(theme.voileCurseur) }
                forme.strokeBorder(bord, lineWidth: c.curseur ? 2.5 : 1.5)
            }
            if let l = c.lettre {
                Text(String(l).uppercased())
                    .font(.system(size: 22, weight: .bold, design: theme.dessinPolice))
                    .foregroundColor(c.teinte != nil ? theme.lettreSurCouleur : theme.lettreSaisie)
            }
        }
        .frame(width: theme.tailleCase, height: theme.tailleCase)
    }

    var bord: Color {
        if c.curseur { return theme.bordCurseur }
        if c.lettre != nil { return theme.bordPlein }
        return c.active ? theme.bordActif : theme.bordVide
    }
}

// MARK: - Le clavier à l'écran (si la planche le retient)

struct ClavierVue: View {
    let lettres: [Character: Character]
    let theme: Theme
    let touche: (ToucheClavier) -> Void

    static let rangs: [[String]] = [
        ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
        ["⏎", "w", "x", "c", "v", "b", "n", "⌫"],
    ]

    var body: some View {
        let largeurLettre = (theme.largeurGrille - 9 * 4) / 10
        let largeurLarge = (theme.largeurGrille - 7 * 4 - 6 * largeurLettre) / 2
        VStack(spacing: 6) {
            ForEach(0..<Self.rangs.count, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(Self.rangs[r], id: \.self) { t in
                        let large = (t == "⏎" || t == "⌫")
                        ToucheVue(texte: t, teinte: large ? nil : lettres[Character(t)], theme: theme)
                            .frame(width: large ? largeurLarge : largeurLettre, height: 32)
                            .onTapGesture {
                                if t == "⏎" { touche(.entree) }
                                else if t == "⌫" { touche(.effacer) }
                                else { touche(.lettre(Character(t))) }
                            }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

struct ToucheVue: View {
    let texte: String
    let teinte: Character?
    let theme: Theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(teinte.map { theme.couleur($0) } ?? theme.touche)
            Text(texte.uppercased())
                .font(.system(size: 12, weight: .semibold, design: theme.dessinPolice))
                .foregroundColor(teinte != nil ? theme.lettreSurCouleur : theme.encreTouche)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Les statistiques

struct VueStatistiques: View {
    let stats: Statistiques
    let resultat: Int?
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Chiffre(valeur: "\(stats.joues)", libelle: "joués", theme: theme)
                Chiffre(valeur: stats.reussite.map { "\($0) %" } ?? "–", libelle: "trouvés", theme: theme)
                Chiffre(valeur: "\(stats.serie)", libelle: "série", theme: theme)
                Chiffre(valeur: "\(stats.meilleureSerie)", libelle: "record", theme: theme)
            }
            Text("Répartition des essais")
                .font(.system(size: 12, weight: .semibold, design: theme.dessinPolice))
                .foregroundColor(theme.encre)
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { k in
                    BarreRepartition(rang: k, nombre: stats.distribution[k],
                                     maximum: max(1, stats.distribution.max() ?? 1),
                                     surlignee: resultat == k + 1, theme: theme)
                }
            }
            Text(phraseMoyenne)
                .font(.system(size: 11.5, weight: .regular, design: theme.dessinPolice))
                .foregroundColor(theme.grisTexte)
                .lineLimit(2)
        }
        .frame(width: theme.largeurGrille, alignment: .leading)
    }

    var phraseMoyenne: String {
        guard let m = stats.moyenneEssais else { return "Joue ton premier mot pour voir tes stats." }
        let texte = String(format: "%.1f", m).replacingOccurrences(of: ".", with: ",")
        var phrase = "En moyenne : \(texte) essais par mot trouvé."
        if stats.rattrapes > 0 { phrase += " Dont \(stats.rattrapes) rattrapé\(stats.rattrapes > 1 ? "s" : "")." }
        return phrase
    }
}

struct Chiffre: View {
    let valeur: String
    let libelle: String
    let theme: Theme

    var body: some View {
        VStack(spacing: 1) {
            Text(valeur)
                .font(.system(size: 20, weight: .bold, design: theme.dessinPolice))
                .foregroundColor(theme.encre)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(libelle)
                .font(.system(size: 10, weight: .regular, design: theme.dessinPolice))
                .foregroundColor(theme.grisTexte)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.voileCurseur))
    }
}

struct BarreRepartition: View {
    let rang: Int
    let nombre: Int
    let maximum: Int
    let surlignee: Bool
    let theme: Theme

    var body: some View {
        HStack(spacing: 6) {
            Text(rang < 6 ? "\(rang + 1)" : "✕")
                .font(.system(size: 11, weight: .semibold, design: theme.dessinPolice))
                .foregroundColor(theme.grisTexte)
                .frame(width: 14)
            GeometryReader { geo in
                let largeur = max(24, geo.size.width * CGFloat(nombre) / CGFloat(maximum))
                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(surlignee ? (rang < 6 ? theme.vert : theme.erreur) : theme.grisCase)
                    Text("\(nombre)")
                        .font(.system(size: 11, weight: .bold, design: theme.dessinPolice))
                        .foregroundColor(theme.lettreSurCouleur)
                        .padding(.trailing, 6)
                }
                .frame(width: largeur)
            }
            .frame(height: 17)
        }
    }
}

// MARK: - Le pied : le menu, toujours atteignable à la souris

struct PiedDePage: View {
    let theme: Theme
    let menu: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: menu) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.grisTexte)
                    .frame(width: 24, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Réglages : démarrage, mise à jour, quitter")
        }
    }
}
