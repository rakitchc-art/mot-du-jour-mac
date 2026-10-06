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
        /// L'épreuve de la mise à jour (fabrication) : dossier, adresse des
        /// publications servies en local, clé publique d'épreuve.
        case epreuveMaj(URL, URL, String)
        /// La relance après une pose, pendant l'épreuve : écrit le bilan.
        case apresMaj(URL)
        /// Le contrôle d'une publication par l'appli elle-même (script de publication).
        case controlePublication(URL)
        /// L'épreuve d'« Ouvrir au démarrage du Mac » : activer, constater, désactiver.
        case epreuveDemarrage(URL)
        /// Le fond de la fenêtre du .dmg (fabrication).
        case fondDmg(URL)
    }

    let mode: Mode
    private(set) var modele: Modele!
    private(set) var miseAJour: MiseAJour?
    private var journal = Journal.parDefaut()
    private var element: NSStatusItem!
    let popover = NSPopover()
    private var moniteurClavier: Any?
    private var minuterie: Timer?
    private var abonnement: AnyCancellable?
    private var pastilleAffichee: Bool?

    // Le choix de Dova sur les planches (06/10/2026) : look B « façon Mac »
    // (clair ou sombre selon le Mac, résolu par PanneauRacine), sans clavier à
    // l'écran, l'icône grille en noir et blanc. Voir DECISIONS.md.
    var theme = Theme.de(.mac, clair: true, clavier: false)
    var varianteIcone: VarianteIcone = .grille

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
        case .fondDmg(let dossier):
            exit(Apercu.fondDmg(dans: dossier) ? 0 : 1)
        case .apresMaj(let dossier):
            // Relancée par le script de pose pendant l'épreuve : le bilan, et c'est tout.
            journal = Journal(dossier: dossier)
            let maj = MiseAJour(reglages: Self.reglagesEpreuve(dossier, adresse: dossier, cle: ""), journal: journal)
            let resultat: String
            switch maj.bilanAuDemarrage() {
            case .reussie(let v): resultat = "REUSSI \(v)"
            case .ratee(let v): resultat = "RATE \(v)"
            case .rien: resultat = "RIEN"
            }
            Self.ecrireResultat(resultat + " — sauvegarde " + (FileManager.default.fileExists(atPath: maj.sauvegarde.path) ? "présente" : "effacée"), dans: dossier)
            exit(0)
        case .controlePublication(let dossier):
            journal = Journal(dossier: dossier)
            guard let r = MiseAJour.reglagesLivres(memoire: MemoireMiseAJour(dossier: dossier.appendingPathComponent("etat"))) else {
                Self.ecrireResultat("ECHEC cette fabrication n'a pas de clé de mise à jour", dans: dossier)
                exit(1)
            }
            let reglages = MiseAJour.Reglages(adresse: r.adresse, clePublique: r.clePublique,
                                              travail: dossier.appendingPathComponent("travail"), memoire: r.memoire,
                                              accepteLocal: false, relance: [])
            let maj = MiseAJour(reglages: reglages, journal: journal)
            Task {
                switch await maj.controler() {
                case .acceptee(let v): Self.ecrireResultat("ACCEPTEE \(v)", dans: dossier); exit(0)
                case .echec(let m): Self.ecrireResultat("ECHEC \(m)", dans: dossier); exit(1)
                default: Self.ecrireResultat("ECHEC réponse inattendue", dans: dossier); exit(1)
                }
            }
            return
        case .epreuveDemarrage(let dossier):
            // Activer comme au premier lancement, constater, puis tout défaire.
            var lignes = ["avant : \(Demarrage.etatLisible)"]
            var ok = true
            do {
                try Demarrage.activer(true)
                lignes.append("après activation : \(Demarrage.etatLisible)")
                if !Demarrage.actif { ok = false; lignes.append("ÉCHEC : pas actif après activation") }
                try Demarrage.activer(false)
                lignes.append("après désactivation : \(Demarrage.etatLisible)")
                if Demarrage.actif { ok = false; lignes.append("ÉCHEC : toujours actif après désactivation") }
            } catch {
                ok = false
                lignes.append("ÉCHEC : \(error.localizedDescription) [\((error as NSError).domain) \((error as NSError).code)]")
            }
            UserDefaults.standard.removeObject(forKey: "demarrageDejaDecide")
            Self.ecrireResultat((ok ? "REUSSI" : "ECHEC") + "\n" + lignes.joined(separator: "\n"), dans: dossier)
            exit(ok ? 0 : 1)
        case .normal, .autotest, .epreuveMaj:
            break
        }

        let dossier: URL
        switch mode {
        case .autotest(let d):
            // Le bac à sable de l'autotest : jamais le vrai carnet.
            dossier = d.appendingPathComponent("carnet-autotest", isDirectory: true)
            try? FileManager.default.removeItem(at: dossier)
        case .epreuveMaj(let d, _, _):
            journal = Journal(dossier: d)
            dossier = d.appendingPathComponent("carnet", isDirectory: true)
        default:
            dossier = Depot.dossierParDefaut()
        }
        modele = Modele(depot: Depot(dossier: dossier))
        installerMiseAJour(dossierCarnet: dossier)

        installerElement()
        installerPanneau()
        abonnement = modele.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.majIcone() }
        }
        minuterie = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(minute(_:)),
                                         userInfo: nil, repeats: true)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reveil(_:)),
                                                          name: NSWorkspace.didWakeNotification, object: nil)

        switch mode {
        case .autotest(let d):
            Autotest(delegue: self, dossier: d).lancer()
        case .epreuveMaj(let d, _, _):
            // L'épreuve : chercher tout de suite. Si la pose part, l'appli se
            // ferme d'elle-même et la suivante écrit le bilan ; sinon on dit pourquoi.
            Task {
                let issue = await self.miseAJour?.verifier() ?? .echec("pas de mise à jour installée")
                switch issue {
                case .echec(let m): Self.ecrireResultat("ECHEC \(m)", dans: d)
                case .aJour(let v): Self.ecrireResultat("AJOUR \(v)", dans: d)
                case .prete(let v): Self.ecrireResultat("PRETE \(v) mais pas posée", dans: d)
                case .acceptee(let v): Self.ecrireResultat("ACCEPTEE \(v)", dans: d)
                }
                exit(0)
            }
        default:
            Demarrage.activerAuPremierLancement()
            if modele.premierLancement {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.ouvrirPanneau() }
            }
        }
    }

    // MARK: - La mise à jour

    private func installerMiseAJour(dossierCarnet: URL) {
        switch mode {
        case .autotest:
            return   // le bac à sable de l'autotest ne touche pas aux mises à jour
        case .epreuveMaj(let d, let adresse, let cle):
            let maj = MiseAJour(reglages: Self.reglagesEpreuve(d, adresse: adresse, cle: cle), journal: journal)
            maj.bilanAuDemarrage()
            miseAJour = maj
        default:
            guard let r = MiseAJour.reglagesLivres(memoire: MemoireMiseAJour(dossier: dossierCarnet)) else {
                journal.noter("mise à jour : cette fabrication n'a pas de clé, pas de mise à jour automatique")
                return
            }
            let maj = MiseAJour(reglages: r, journal: journal)
            maj.peutPoser = { [weak self] in !(self?.popover.isShown ?? false) }
            maj.bilanAuDemarrage()
            maj.demarrer()
            miseAJour = maj
        }
    }

    static func reglagesEpreuve(_ d: URL, adresse: URL, cle: String) -> MiseAJour.Reglages {
        MiseAJour.Reglages(adresse: adresse, clePublique: cle,
                           travail: d.appendingPathComponent("travail", isDirectory: true),
                           memoire: MemoireMiseAJour(dossier: d.appendingPathComponent("etat", isDirectory: true)),
                           accepteLocal: true, relance: ["--apres-maj", d.path])
    }

    static func ecrireResultat(_ texte: String, dans d: URL) {
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        try? (texte + "\n").write(to: d.appendingPathComponent("resultat-maj.txt"), atomically: true, encoding: .utf8)
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
        // Une version prête attendait que le panneau se ferme.
        miseAJour?.poserSiPossible()
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
        if miseAJour != nil { ajouter("Rechercher une mise à jour", #selector(menuMiseAJour)) }
        menu.addItem(.separator())
        ajouter("À propos de Mot du jour", #selector(menuAPropos))
        ajouter("Quitter Mot du jour", #selector(menuQuitter))
        let version = NSMenuItem(title: "Version \(versionDeLAppli())", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        return menu
    }

    @objc private func menuMiseAJour() {
        guard let maj = miseAJour else { return }
        Task {
            // Si une version est prête et le panneau fermé, elle se pose tout de
            // suite et l'appli se relance : la phrase ci-dessous ne s'affiche pas.
            switch await maj.verifier() {
            case .aJour(let v):
                alerte("Mot du jour est à jour", detail: "C'est la version \(v), la dernière publiée.")
            case .prete(let v):
                alerte("La version \(v) est prête",
                       detail: "Elle s'installera toute seule dès que le panneau sera fermé, puis l'appli se relancera.")
            case .acceptee:
                break
            case .echec(let m):
                alerte("La recherche de mise à jour n'a pas abouti", detail: m)
            }
        }
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

    /// La minuterie (toutes les 20 s) et la sortie de veille : minuit est-il passé ?
    func tic() {
        modele.verifierJour()
        majIcone()
    }

    /// La pastille telle qu'elle est posée dans la barre (pour l'autotest).
    var pastilleDansLaBarre: Bool? { pastilleAffichee }

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
