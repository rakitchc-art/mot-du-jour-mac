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
    /// mot attend (aujourd'hui pas encore fini).
    static func barre(_ v: VarianteIcone, pastille: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { r in
            dessiner(v, dans: r, pastille: pastille)
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

    /// L'icône de l'appli (Finder, Applications, .dmg), dessinée à `cote`
    /// pixels : la tuile verte en grand, au gabarit des icônes de macOS.
    static func appli(cote: Int) -> NSBitmapImageRep? {
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
        let ombre = NSShadow()
        ombre.shadowColor = NSColor(white: 0, alpha: 0.35)
        ombre.shadowOffset = NSSize(width: 0, height: -s * 10 / 1024)
        ombre.shadowBlurRadius = s * 20 / 1024
        NSGraphicsContext.saveGraphicsState()
        ombre.set()
        NSColor(srgbRed: 36 / 255, green: 35 / 255, blue: 32 / 255, alpha: 1).setFill()
        forme.fill()
        NSGraphicsContext.restoreGraphicsState()
        // Une ligne de cinq cases : g j v v v — un mot presque trouvé.
        let c = carre.width * 0.15, e = carre.width * 0.03
        let x0 = carre.midX - (5 * c + 4 * e) / 2, y0 = carre.midY - c / 2
        for (k, couleur) in [gris, jaune, vert, vert, vert].enumerated() {
            couleur.setFill()
            NSBezierPath(roundedRect: NSRect(x: x0 + CGFloat(k) * (c + e), y: y0, width: c, height: c),
                         xRadius: c * 0.14, yRadius: c * 0.14).fill()
        }
        let lettres = ["M", "O", "T", "", ""]
        for (k, l) in lettres.enumerated() where !l.isEmpty {
            lettre(l, dans: NSRect(x: x0 + CGFloat(k) * (c + e), y: y0, width: c, height: c),
                   couleur: NSColor(white: 0.98, alpha: 1), taille: c * 0.62)
        }
        return rep
    }
}
