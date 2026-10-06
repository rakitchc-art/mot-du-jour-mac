import AppKit
import Combine
import SwiftUI
import MotDuJourCore

/// L'appli : l'icône en haut à droite, le panneau qui tombe dessous, le menu
/// du clic droit, le clavier, et le passage de minuit.
@MainActor
final class Delegue: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    enum Mode {
        case normal
        case apercu(URL)
        case icone(URL)
        case autotest(URL)
    }

    let mode: Mode
    private(set) var modele: Modele!
    private var element: NSStatusItem!
    let popover = NSPopover()
    private var moniteurClavier: Any?
    private var minuterie: Timer?
    private var abonnement: AnyCancellable?
    private var pastilleAffichee: Bool?

    // En attendant le choix de Dova sur la planche : le look de sa barre.
    var theme = Theme.de(.barre, clair: false, clavier: false)
    var varianteIcone: VarianteIcone = .tuile

    init(mode: Mode) {
        self.mode = mode
        super.init()
    }

    var estAutotest: Bool { if case .autotest = mode { return true } else { return false } }

    func applicationDidFinishLaunching(_ notification: Notification) {
        switch mode {
        case .apercu(let dossier):
            let ok = Apercu.planches(dans: dossier)
            exit(ok ? 0 : 1)
        case .icone(let dossier):
            let ok = Apercu.iconesAppli(dans: dossier)
            exit(ok ? 0 : 1)
        case .normal, .autotest:
            break
        }

        let dossier: URL
        if case .autotest(let d) = mode {
            // Le bac à sable de l'autotest : jamais le vrai carnet.
            dossier = d.appendingPathComponent("carnet-autotest", isDirectory: true)
            try? FileManager.default.removeItem(at: dossier)
        } else {
            dossier = Depot.dossierParDefaut()
        }
        modele = Modele(depot: Depot(dossier: dossier))

        installerElement()
        installerPanneau()
        abonnement = modele.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.majIcone() }
        }
        minuterie = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(minute(_:)),
                                         userInfo: nil, repeats: true)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reveil(_:)),
                                                          name: NSWorkspace.didWakeNotification, object: nil)

        if case .autotest(let d) = mode {
            Autotest(delegue: self, dossier: d).lancer()
        } else {
            Demarrage.activerAuPremierLancement()
            if modele.premierLancement {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.ouvrirPanneau() }
            }
        }
    }

    /// Un double-clic sur l'appli alors qu'elle tourne déjà (elle cherche
    /// l'icône, par exemple) : on ouvre le panneau.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ouvrirPanneau()
        return false
    }

    // MARK: - L'icône

    private func installerElement() {
        element = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let b = element.button else { return }
        b.imagePosition = .imageOnly
        b.toolTip = "Mot du jour"
        b.target = self
        b.action = #selector(clic(_:))
        b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        majIcone()
    }

    func majIcone() {
        guard let b = element?.button, let m = modele else { return }
        let p = m.pastille
        guard p != pastilleAffichee else { return }
        pastilleAffichee = p
        b.image = Icone.barre(varianteIcone, pastille: p)
    }

    @objc private func clic(_ sender: Any?) {
        let ev = NSApp.currentEvent
        if ev?.type == .rightMouseUp || (ev?.modifierFlags.contains(.control) ?? false) {
            montrerMenuSousIcone()
        } else {
            basculerPanneau()
        }
    }

    // MARK: - Le panneau

    private func installerPanneau() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let racine = PanneauRacine(modele: modele, theme: theme,
                                   ouvrirMenu: { [weak self] in self?.montrerMenuDansPanneau() })
        popover.contentViewController = NSHostingController(rootView: racine)
        popover.contentSize = NSSize(width: theme.largeur, height: theme.hauteur)
        if theme.famille == .barre { popover.appearance = NSAppearance(named: .darkAqua) }
    }

    var panneauOuvert: Bool { popover.isShown }
    var vueDuPanneau: NSView? { popover.contentViewController?.view }

    func basculerPanneau() {
        if popover.isShown { fermerPanneau() } else { ouvrirPanneau() }
    }

    func ouvrirPanneau() {
        guard let b = element?.button, !popover.isShown else { return }
        modele.ouverture()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func fermerPanneau() {
        popover.performClose(nil)
    }

    func popoverDidShow(_ notification: Notification) {
        guard moniteurClavier == nil else { return }
        moniteurClavier = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self = self, self.popover.isShown else { return ev }
            return self.traiterTouche(ev) ? nil : ev
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = moniteurClavier {
            NSEvent.removeMonitor(m)
            moniteurClavier = nil
        }
    }

    /// Le vrai clavier du Mac. Renvoie true si la touche a été prise.
    func traiterTouche(_ ev: NSEvent) -> Bool {
        if ev.modifierFlags.contains(.command) || ev.modifierFlags.contains(.control) { return false }
        switch ev.keyCode {
        case 53: fermerPanneau(); return true                  // Échap
        case 36, 76: modele.touche(.entree); return true       // Entrée, Entrée du pavé
        case 51, 117: modele.touche(.effacer); return true     // Retour arrière, Suppr
        case 123: modele.deplacer(-1); return true             // ←
        case 124: modele.deplacer(+1); return true             // →
        default:
            guard let texte = ev.characters, let l = lettreDeTouche(texte) else { return false }
            modele.touche(.lettre(l))
            return true
        }
    }

    // MARK: - Le menu (clic droit sur l'icône, ou « … » dans le panneau)

    private func construireMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        func ajouter(_ titre: String, _ action: Selector, coche: Bool? = nil) {
            let i = NSMenuItem(title: titre, action: action, keyEquivalent: "")
            i.target = self
            if let c = coche { i.state = c ? .on : .off }
            menu.addItem(i)
        }
        ajouter("Ouvrir le mot du jour", #selector(menuOuvrir))
        menu.addItem(.separator())
        ajouter("Ouvrir au démarrage du Mac", #selector(menuDemarrage), coche: Demarrage.actif)
        menu.addItem(.separator())
        ajouter("À propos de Mot du jour", #selector(menuAPropos))
        ajouter("Quitter Mot du jour", #selector(menuQuitter))
        return menu
    }

    private func montrerMenuSousIcone() {
        if popover.isShown { fermerPanneau() }
        element.menu = construireMenu()
        element.button?.performClick(nil)
        element.menu = nil
    }

    private func montrerMenuDansPanneau() {
        guard let v = vueDuPanneau else { return }
        let point = NSPoint(x: v.bounds.maxX - 30, y: v.isFlipped ? v.bounds.maxY - 8 : 8)
        construireMenu().popUp(positioning: nil, at: point, in: v)
    }

    @objc private func menuOuvrir() { ouvrirPanneau() }

    @objc private func menuDemarrage() {
        do {
            try Demarrage.activer(!Demarrage.actif)
        } catch {
            alerte("Le réglage du démarrage n'a pas pu être changé", detail: error.localizedDescription)
        }
    }

    @objc private func menuAPropos() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Le mot du jour de TokenBar, pour le Mac.\nMots : Lexique 3.83 (CC BY-SA 4.0) et Grammalecte (MPL 2.0) — voir CREDITS.md dans l'appli.",
            attributes: [.font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func menuQuitter() { NSApp.terminate(nil) }

    private func alerte(_ titre: String, detail: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = titre
        a.informativeText = detail
        a.runModal()
    }

    // MARK: - Minuit, le réveil

    private func tic() {
        modele.verifierJour()
        majIcone()
    }

    @objc private func reveil(_ n: Notification) { tic() }
    @objc private func minute(_ t: Timer) { tic() }
}

/// La racine SwiftUI du panneau : suit le modèle, et — pour la famille « mac »
/// — le réglage clair / sombre du Mac.
struct PanneauRacine: View {
    @ObservedObject var modele: Modele
    let theme: Theme
    let ouvrirMenu: () -> Void
    // Pas « private » : une propriété privée rendrait privé l'initialiseur
    // de la structure, et Delegue ne pourrait plus la construire.
    @Environment(\.colorScheme) var schema

    var body: some View {
        let t = theme.famille == .mac ? Theme.de(.mac, clair: schema == .light, clavier: theme.clavier) : theme
        PanneauVue(etat: modele.etat, theme: t, secousse: modele.secousse, actions: Actions(
            precedent: modele.precedent,
            suivant: modele.suivant,
            basculerStats: modele.basculerStats,
            clicCase: modele.clicCase,
            touche: modele.touche,
            menu: ouvrirMenu))
    }
}
