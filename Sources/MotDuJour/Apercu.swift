import AppKit
import SwiftUI
import MotDuJourCore

// ===========================================================================
//  Les planches pour Dova : les looks possibles, dessinés par les VRAIES vues
//  du panneau (PanneauVue, Icone) nourries de parties fabriquées — la méthode
//  des planches de TokenBar. Lancé par la fabrication : --apercu <dossier>.
// ===========================================================================

@MainActor
enum Apercu {
    static let jourDemo = "2026-10-06"
    static let utc = TimeZone(secondsFromGMT: 0)!

    // MARK: - Les parties fabriquées

    static func grilleDemo(solution: String, essais: [String], jour: String) -> Grille {
        var g = Grille(solution: solution)
        for (k, e) in essais.enumerated() {
            g.essais.append(Essai(mot: e, couleurs: couleurs(essai: e, solution: solution),
                                  utc: String(format: "%@T08:%02ld:00.000Z", jour, 10 + k)))
        }
        if essais.last == solution { g.trouve = true; g.fini = true } else if essais.count >= Regles.essaisMax { g.fini = true }
        if g.fini { g.finiUtc = g.essais.last?.utc ?? "" }
        return g
    }

    static var carnetEnCours: Carnet {
        var c = Carnet(premierJour: "2026-10-01")
        c.grilles[jourDemo] = grilleDemo(solution: "plume", essais: ["salut", "plage"], jour: jourDemo)
        return c
    }

    static var carnetTrouve: Carnet {
        var c = Carnet(premierJour: "2026-10-01")
        c.grilles[jourDemo] = grilleDemo(solution: "plume", essais: ["salut", "plage", "plume"], jour: jourDemo)
        return c
    }

    /// Trois semaines de jeu, pour les statistiques : 0 = pas joué, 7 = raté.
    static var carnetHistoire: Carnet {
        var c = Carnet(premierJour: "2026-09-16")
        let resultats = [3, 4, 0, 2, 5, 3, 7, 4, 3, 2, 4, 0, 3, 6, 2, 3, 4, 5, 3, 2, 4]
        let faux = ["salut", "radio", "tigre", "monde", "fleur", "carte", "poire", "livre"]
        let n0 = numeroDeJour("2026-09-16")!
        for (i, r) in resultats.enumerated() where r > 0 {
            let jour = jourDeNumero(n0 + i)
            guard let sol = Dictionnaire.livre.motDuJour(jour) else { continue }
            let mauvais = faux.filter { $0 != sol }
            let essais = r == 7 ? Array(mauvais.prefix(6)) : Array(mauvais.prefix(r - 1)) + [sol]
            c.grilles[jour] = grilleDemo(solution: sol, essais: essais, jour: jour)
        }
        return c
    }

    static func etat(_ carnet: Carnet, jour: String = jourDemo, saisie: String = "",
                     message: MessagePassager? = nil, stats: Bool = false) -> VueEtat {
        var s = Saisie()
        for c in saisie { s.taper(c) }
        return presenter(jeu: Jeu(dico: .livre, carnet: carnet), jour: jour, aujourdhui: jourDemo,
                         saisie: s, message: message, vueStats: stats, fuseau: utc)
    }

    // MARK: - L'écriture

    static func planches(dans dossier: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        } catch {
            print("planches : dossier impossible — \(error.localizedDescription)")
            return false
        }
        let a = ecrire(PlanchePanneaux(), "planche-1-panneaux.png", dans: dossier)
        let b = ecrire(PlancheEtats(), "planche-2-etats.png", dans: dossier)
        let c = ecrire(PlancheIcones(), "planche-3-icones.png", dans: dossier)
        return a && b && c
    }

    static func ecrire<V: View>(_ vue: V, _ nom: String, dans dossier: URL) -> Bool {
        guard #available(macOS 13.0, *) else {
            print("planches : il faut macOS 13 pour les dessiner")
            return false
        }
        let rendu = ImageRenderer(content: vue)
        rendu.scale = 2
        guard let image = rendu.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("planches : rendu impossible — \(nom)")
            return false
        }
        do {
            try png.write(to: dossier.appendingPathComponent(nom))
            print("planche écrite : \(nom) (\(image.width) × \(image.height) px)")
            return true
        } catch {
            print("planches : écriture impossible — \(nom) : \(error.localizedDescription)")
            return false
        }
    }

    /// Les PNG du .icns de l'appli (le nom des fichiers est celui qu'exige iconutil).
    static func iconesAppli(dans dossier: URL) -> Bool {
        let tailles: [(String, Int)] = [
            ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32), ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256), ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512), ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
        ]
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            for (nom, cote) in tailles {
                guard let rep = Icone.appli(cote: cote),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("icône impossible : \(nom)")
                    return false
                }
                try png.write(to: dossier.appendingPathComponent(nom))
            }
            print("icônes de l'appli : \(tailles.count) fichiers")
            return true
        } catch {
            print("icônes de l'appli : \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Planche 1 : trois looks, avec ou sans clavier

struct PlanchePanneaux: View {
    var body: some View {
        let etat = Apercu.etat(Apercu.carnetEnCours, saisie: "plu")
        VStack(alignment: .leading, spacing: 20) {
            Text("Planche 1 — le panneau : la même partie, trois looks, avec ou sans clavier")
                .font(.system(size: 21, weight: .bold)).foregroundColor(.black)
            Text("Partie en cours : SALUT, puis PLAGE, et « PLU » en train d'être tapé (le cadre clair = la case où tombe la prochaine lettre).")
                .font(.system(size: 13)).foregroundColor(Color(white: 0.3))
            ForEach([false, true], id: \.self) { clavier in
                VStack(alignment: .leading, spacing: 8) {
                    Text(clavier ? "Avec un clavier à l'écran (les lettres prennent leur couleur)" : "Sans clavier à l'écran (on tape au vrai clavier, comme dans ta barre)")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    HStack(alignment: .top, spacing: 30) {
                        Variante(titre: "A · comme ta barre (toujours sombre)", theme: .de(.barre, clair: false, clavier: clavier), etat: etat)
                        Variante(titre: "B · façon Mac, Mac réglé en clair", theme: .de(.mac, clair: true, clavier: clavier), etat: etat)
                        Variante(titre: "B · façon Mac, Mac réglé en sombre", theme: .de(.mac, clair: false, clavier: clavier), etat: etat)
                    }
                }
            }
        }
        .padding(30)
        .background(Color(white: 0.93))
    }
}

struct Variante: View {
    let titre: String
    let theme: Theme
    let etat: VueEtat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre).font(.system(size: 13, weight: .medium)).foregroundColor(.black)
            PanneauVue(etat: etat, theme: theme)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Planche 2 : les autres moments du jeu

struct PlancheEtats: View {
    var body: some View {
        let etats: [(String, VueEtat)] = [
            ("Trouvé en 3", Apercu.etat(Apercu.carnetTrouve)),
            ("Mot refusé : la ligne tremble", Apercu.etat(Apercu.carnetEnCours, saisie: "plxme",
                                                           message: MessagePassager("Mot inconnu", erreur: true))),
            ("Un jour passé, à rattraper", Apercu.etat(Apercu.carnetHistoire, jour: "2026-09-27")),
            ("Ses statistiques", Apercu.etat(Apercu.carnetHistoire, stats: true)),
        ]
        let themes: [(String, Theme)] = [
            ("A · comme ta barre", .de(.barre, clair: false, clavier: false)),
            ("B · façon Mac (clair)", .de(.mac, clair: true, clavier: false)),
        ]
        VStack(alignment: .leading, spacing: 20) {
            Text("Planche 2 — les autres moments, dans les looks A et B")
                .font(.system(size: 21, weight: .bold)).foregroundColor(.black)
            ForEach(0..<themes.count, id: \.self) { t in
                VStack(alignment: .leading, spacing: 8) {
                    Text(themes[t].0).font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    HStack(alignment: .top, spacing: 26) {
                        ForEach(0..<etats.count, id: \.self) { e in
                            Variante(titre: etats[e].0, theme: themes[t].1, etat: etats[e].1)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(Color(white: 0.93))
    }
}

// MARK: - Planche 3 : l'icône de la barre des menus, et celle de l'appli

struct PlancheIcones: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Planche 3 — l'icône en haut à droite")
                .font(.system(size: 21, weight: .bold)).foregroundColor(.black)
            Text("Dans une fausse barre des menus, à la taille réelle ; puis agrandie. La pastille = un mot l'attend aujourd'hui (elle s'éteint quand il est trouvé).")
                .font(.system(size: 13)).foregroundColor(Color(white: 0.3))
            HStack(spacing: 18) {
                Text("").frame(width: 200)
                Text("barre claire").frame(width: 190)
                Text("barre sombre").frame(width: 190)
                Text("claire + pastille").frame(width: 190)
                Text("sombre + pastille").frame(width: 190)
                Text("agrandie").frame(width: 90)
            }
            .font(.system(size: 12, weight: .medium)).foregroundColor(Color(white: 0.3))
            ForEach(VarianteIcone.allCases, id: \.self) { v in
                HStack(spacing: 18) {
                    Text(v.nom).font(.system(size: 14, weight: .semibold)).foregroundColor(.black)
                        .frame(width: 200, alignment: .leading)
                    FausseBarre(variante: v, sombre: false, pastille: false)
                    FausseBarre(variante: v, sombre: true, pastille: false)
                    FausseBarre(variante: v, sombre: false, pastille: true)
                    FausseBarre(variante: v, sombre: true, pastille: true)
                    IconeAgrandie(variante: v)
                }
            }
            HStack(spacing: 18) {
                Text("L'icône de l'appli (Applications, le .dmg, l'avertissement d'Apple) — provisoire, elle suivra ton choix :")
                    .font(.system(size: 13)).foregroundColor(.black)
                    .frame(width: 420, alignment: .leading)
                if let rep = Icone.appli(cote: 256) {
                    Image(nsImage: imageDe(rep)).resizable().frame(width: 128, height: 128)
                }
            }
        }
        .padding(30)
        .background(Color(white: 0.93))
    }

    func imageDe(_ rep: NSBitmapImageRep) -> NSImage {
        let i = NSImage(size: rep.size)
        i.addRepresentation(rep)
        return i
    }
}

struct FausseBarre: View {
    let variante: VarianteIcone
    let sombre: Bool
    let pastille: Bool

    var encre: Color { sombre ? .white : .black }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundColor(encre)
            Image(systemName: "wifi").font(.system(size: 12, weight: .medium)).foregroundColor(encre)
            icone.frame(width: 18, height: 18)
            Text("mar. 6 oct.  11:42").font(.system(size: 12.5)).foregroundColor(encre)
        }
        .padding(.horizontal, 10)
        .frame(width: 190, height: 24)
        .background(sombre ? Color(white: 0.17) : Color(white: 0.97))
    }

    @ViewBuilder var icone: some View {
        let image = Image(nsImage: Icone.barre(variante, pastille: pastille))
        if variante.estModele {
            image.renderingMode(.template).foregroundColor(encre)
        } else {
            image.renderingMode(.original)
        }
    }
}

struct IconeAgrandie: View {
    let variante: VarianteIcone

    var body: some View {
        let image = Image(nsImage: Icone.barre(variante, pastille: true)).resizable()
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.8))
            if variante.estModele {
                image.renderingMode(.template).foregroundColor(.black).frame(width: 72, height: 72)
            } else {
                image.renderingMode(.original).frame(width: 72, height: 72)
            }
        }
        .frame(width: 90, height: 90)
    }
}
