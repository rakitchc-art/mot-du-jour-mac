import AppKit

/// Les visages possibles de l'icône de la barre des menus (choix de Dova sur
/// la planche). « Modèle » = une image monochrome que macOS peint lui-même en
/// noir ou en blanc selon la barre — la convention des icônes Apple. Les
/// autres gardent leurs couleurs, comme la tuile du mot dans TokenBar.
enum VarianteIcone: String, CaseIterable {
    /// La tuile verte avec un A — l'icône du mot dans TokenBar (choisie le 01/09).
    case tuile
    /// La même tuile, en modèle monochrome : un contour et un A.
    case tuileModele
    /// Trois cases gris, jaune, vert : un mot jugé.
    case tuiles
    /// Une mini-grille 3 × 2 en modèle monochrome.
    case grille

    var estModele: Bool { self == .tuileModele || self == .grille }

    var nom: String {
        switch self {
        case .tuile: return "1 · tuile verte"
        case .tuileModele: return "2 · tuile (noir et blanc)"
        case .tuiles: return "3 · trois cases"
        case .grille: return "4 · grille (noir et blanc)"
        }
    }
}

enum Icone {
    static let vert = NSColor(srgbRed: 83 / 255, green: 141 / 255, blue: 78 / 255, alpha: 1)
    static let jaune = NSColor(srgbRed: 181 / 255, green: 159 / 255, blue: 59 / 255, alpha: 1)
    static let gris = NSColor(srgbRed: 150 / 255, green: 148 / 255, blue: 142 / 255, alpha: 1)
    static let rouge = NSColor(srgbRed: 240 / 255, green: 55 / 255, blue: 60 / 255, alpha: 1)

    /// L'icône de la barre des menus, 18 × 18 points. La pastille dit qu'un
    /// mot attend (aujourd'hui pas encore fini). `echelle` ne sert qu'à la
    /// planche : la même icône REDESSINÉE en grand, pas étirée (étirée, elle
    /// était floue sur la première planche).
    static func barre(_ v: VarianteIcone, pastille: Bool, echelle: CGFloat = 1) -> NSImage {
        let image = NSImage(size: NSSize(width: 18 * echelle, height: 18 * echelle), flipped: false) { _ in
            NSGraphicsContext.current?.cgContext.scaleBy(x: echelle, y: echelle)
            dessiner(v, dans: NSRect(x: 0, y: 0, width: 18, height: 18), pastille: pastille)
            return true
        }
        image.isTemplate = v.estModele
        image.accessibilityDescription = pastille ? "Mot du jour — un mot t'attend" : "Mot du jour"
        return image
    }

    static func dessiner(_ v: VarianteIcone, dans r: NSRect, pastille: Bool) {
        let encre = NSColor.black   // pour les modèles : macOS repeint
        switch v {
        case .tuile:
            let t = r.insetBy(dx: 1.5, dy: 1.5)
            vert.setFill()
            NSBezierPath(roundedRect: t, xRadius: 3.5, yRadius: 3.5).fill()
            lettre("A", dans: t, couleur: NSColor(white: 0.97, alpha: 1), taille: 11.5)
        case .tuileModele:
            let t = r.insetBy(dx: 2, dy: 2)
            encre.setStroke()
            let p = NSBezierPath(roundedRect: t, xRadius: 3.5, yRadius: 3.5)
            p.lineWidth = 1.5
            p.stroke()
            lettre("A", dans: t, couleur: encre, taille: 10.5)
        case .tuiles:
            let c: CGFloat = 4.6, e: CGFloat = 1.4
            let x0 = r.midX - (3 * c + 2 * e) / 2, y0 = r.midY - c / 2
            for (k, couleur) in [gris, jaune, vert].enumerated() {
                couleur.setFill()
                NSBezierPath(roundedRect: NSRect(x: x0 + CGFloat(k) * (c + e), y: y0, width: c, height: c),
                             xRadius: 1, yRadius: 1).fill()
            }
        case .grille:
            let c: CGFloat = 4.4, e: CGFloat = 1.6
            let x0 = r.midX - (3 * c + 2 * e) / 2, y0 = r.midY - (2 * c + e) / 2
            encre.setFill(); encre.setStroke()
            for ligne in 0..<2 {
                for k in 0..<3 {
                    let carre = NSRect(x: x0 + CGFloat(k) * (c + e), y: y0 + CGFloat(ligne) * (c + e), width: c, height: c)
                    if ligne == 0 {
                        NSBezierPath(roundedRect: carre, xRadius: 0.8, yRadius: 0.8).fill()   // la ligne jugée
                    } else {
                        let p = NSBezierPath(roundedRect: carre.insetBy(dx: 0.5, dy: 0.5), xRadius: 0.8, yRadius: 0.8)
                        p.lineWidth = 1
                        p.stroke()                                                          // la ligne à jouer
                    }
                }
            }
        }
        if pastille {
            let d: CGFloat = 6
            let rond = NSRect(x: r.maxX - d, y: r.maxY - d, width: d, height: d)
            if v.estModele {
                // Un anneau vide autour du point, pour qu'il se détache du dessin.
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: rond.insetBy(dx: -1.2, dy: -1.2)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                encre.setFill()
            } else {
                NSColor(white: 0.12, alpha: 1).setFill()
                NSBezierPath(ovalIn: rond.insetBy(dx: -1, dy: -1)).fill()
                rouge.setFill()
            }
            NSBezierPath(ovalIn: rond).fill()
        }
    }

    static func lettre(_ texte: String, dans r: NSRect, couleur: NSColor, taille: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: taille, weight: .heavy),
            .foregroundColor: couleur,
            .paragraphStyle: style,
        ]
        let s = NSAttributedString(string: texte, attributes: attributs)
        let h = s.size().height
        s.draw(in: NSRect(x: r.minX, y: r.midY - h / 2 + 0.3, width: r.width, height: h))
    }

    /// L'icône de l'appli retenue — PROVISOIRE tant que Dova n'a pas choisi sur
    /// la planche 4 (les trois visages reprennent la grille de la barre des menus).
    static let appliRetenue: VarianteAppli = .blanc

    /// L'icône de l'appli (Finder, Applications, .dmg), dessinée à `cote`
    /// pixels, au gabarit des icônes de macOS : la grille de la barre des
    /// menus — la ligne jugée en bas, la ligne à jouer au-dessus, comme l'icône
    /// choisie — en grand, dans les teintes de la variante.
    static func appli(cote: Int, variante: VarianteAppli = appliRetenue) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cote, pixelsHigh: cote,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: cote, height: cote)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = ctx
        let s = CGFloat(cote)
        // Le gabarit d'Apple : un carré arrondi de 824/1024, centré.
        let carre = NSRect(x: s * 100 / 1024, y: s * 100 / 1024, width: s * 824 / 1024, height: s * 824 / 1024)
        let forme = NSBezierPath(roundedRect: carre, xRadius: s * 185 / 1024, yRadius: s * 185 / 1024)
        let c = variante.couleurs

        let ombre = NSShadow()
        ombre.shadowColor = NSColor(white: 0, alpha: 0.32)
        ombre.shadowOffset = NSSize(width: 0, height: -s * 10 / 1024)
        ombre.shadowBlurRadius = s * 22 / 1024
        NSGraphicsContext.saveGraphicsState()
        ombre.set()
        c.bas.setFill()
        forme.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: c.bas, ending: c.haut)?.draw(in: forme, angle: 90)

        // La grille 3 × 2.
        let cote1 = carre.width * 0.2, ecart = carre.width * 0.06
        let x0 = carre.midX - (3 * cote1 + 2 * ecart) / 2, y0 = carre.midY - (2 * cote1 + ecart) / 2
        for k in 0..<3 {
            let bas = NSRect(x: x0 + CGFloat(k) * (cote1 + ecart), y: y0, width: cote1, height: cote1)
            c.cases[k].setFill()
            NSBezierPath(roundedRect: bas, xRadius: cote1 * 0.16, yRadius: cote1 * 0.16).fill()
            let epaisseur = cote1 * 0.09
            let haut = bas.offsetBy(dx: 0, dy: cote1 + ecart).insetBy(dx: epaisseur / 2, dy: epaisseur / 2)
            c.contour.setStroke()
            let p = NSBezierPath(roundedRect: haut, xRadius: cote1 * 0.14, yRadius: cote1 * 0.14)
            p.lineWidth = epaisseur
            p.stroke()
        }
        return rep
    }
}

/// Les visages possibles de l'icône de l'appli (planche 4). Dova, le 06/10,
/// devant trois versions en couleurs : « en noir et blanc très soft ». Trois
/// nuances de gris, la ligne jugée en trois tons qui rappellent gris, jaune,
/// vert sans les nommer.
enum VarianteAppli: String, CaseIterable {
    case blanc
    case perle
    case graphite

    var nom: String {
        switch self {
        case .blanc: return "1 · blanc doux"
        case .perle: return "2 · gris perle"
        case .graphite: return "3 · graphite doux"
        }
    }

    struct Teintes {
        let haut: NSColor, bas: NSColor
        let cases: [NSColor]
        let contour: NSColor
    }

    var couleurs: Teintes {
        func c(_ r: CGFloat, _ v: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
            NSColor(srgbRed: r / 255, green: v / 255, blue: b / 255, alpha: a)
        }
        switch self {
        case .blanc:
            return Teintes(haut: c(253, 253, 252), bas: c(233, 233, 231),
                           cases: [c(192, 192, 190), c(170, 170, 168), c(148, 148, 146)], contour: c(212, 212, 210))
        case .perle:
            return Teintes(haut: c(241, 241, 240), bas: c(213, 213, 211),
                           cases: [c(142, 142, 140), c(120, 120, 118), c(98, 98, 96)], contour: c(178, 178, 176))
        case .graphite:
            return Teintes(haut: c(86, 86, 88), bas: c(52, 52, 54),
                           cases: [c(176, 176, 178), c(206, 206, 208), c(236, 236, 238)], contour: c(130, 130, 132))
        }
    }
}
