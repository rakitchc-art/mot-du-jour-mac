import AppKit
import Combine
import SwiftUI
import MotDuJourCore

/// L'appli : l'icône en haut à droite, le panneau qui tombe dessous, le menu
/// du clic droit, le clavier, le passage de minuit, la mise à jour.
@MainActor
final class Delegue: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    enum Mode {
        /// L'appli de tous les jours. `auDemarrage` : lancée par l'agent de
        /// lancement de macOS 12 à l'ouverture de session.
        case normal(auDemarrage: Bool)
        case apercu(URL)
        case icone(URL)
        case fondDmg(URL)
        case autotest(URL)
        /// L'épreuve de la mise à jour : le chemin de TOUS LES JOURS (dossiers,
        /// minuterie, pose, relance sans argument), seules l'adresse des
        /// publications et la clé changent. Le dossier reçoit le résultat si
        /// rien n'est posé.
        case epreuveMaj(URL, URL, String)
        /// Le contrôle d'une publication par l'appli elle-même (script de
        /// publication) ; l'adresse, si elle est donnée, remplace celle d'Info.plist.
        case controlePublication(URL, URL?)
        /// L'épreuve d'« Ouvrir au démarrage du Mac » : inscrire, constater, défaire.
        case epreuveDemarrage(URL)
        /// L'épreuve du vrai clavier : l'appli ordinaire, carnet dans un bac à sable.
        case epreuveClavier(URL)
        /// Une photo du vrai panneau ouvert (le mode sombre, par exemple), puis sortie.
        case montrerPanneau(URL)
    }

    static let notificationOuvrir = Notification.Name("fr.dova.motdujour.ouvrir")

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

    // MARK: - Le lancement

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Lue ICI, pendant le traitement de l'ouverture : lancée par macOS à
        // l'ouverture de session (élément d'ouverture), ou par elle ?
        let lanceeALouverture: Bool = {
            guard let ev = NSAppleEventManager.shared().currentAppleEvent,
                  ev.eventID == AEEventID(kAEOpenApplication) else { return false }
            return ev.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        }()

        switch mode {
        case .apercu(let dossier):
            exit(Apercu.planches(dans: dossier) ? 0 : 1)
        case .icone(let dossier):
            exit(Apercu.iconesAppli(dans: dossier) ? 0 : 1)
        case .fondDmg(let dossier):
            exit(Apercu.fondDmg(dans: dossier) ? 0 : 1)
        case .controlePublication(let dossier, let adresse):
            controlerPublication(dossier, adresse: adresse)
            return
        case .epreuveDemarrage(let dossier):
            eprouverDemarrage(dossier)
        case .normal, .autotest, .epreuveMaj, .epreuveClavier, .montrerPanneau:
            break
        }

        // Un seul exemplaire à la fois (deux écriraient le même carnet). Le
        // second demande au premier d'ouvrir son panneau, puis s'en va.
        if case .normal = mode, autreExemplaireEnRoute() {
            DistributedNotificationCenter.default().postNotificationName(Self.notificationOuvrir, object: nil,
                                                                         userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }

        // Isolée par macOS (voir Isolement.swift) : on se relance depuis le
        // vrai emplacement, avant de toucher à quoi que ce soit. Et une copie
        // ouverte hors d'Applications cède la place à celle d'Applications.
        switch mode {
        case .normal:
            if Isolement.sortirSiPossible(journal: journal) || Isolement.cederSiPossible(journal: journal) { exit(0) }
        case .epreuveMaj:
            if Isolement.sortirSiPossible(journal: journal) { exit(0) }
        default:
            break
        }

        let dossierCarnet: URL
        switch mode {
        case .autotest(let d), .epreuveClavier(let d), .montrerPanneau(let d):
            // Les bacs à sable : jamais le vrai carnet.
            dossierCarnet = d.appendingPathComponent("carnet-essai", isDirectory: true)
            try? FileManager.default.removeItem(at: dossierCarnet)
        default:
            dossierCarnet = Depot.dossierParDefaut()
        }
        modele = Modele(depot: Depot(dossier: dossierCarnet))
        switch mode {
        // Par le VRAI emplacement : rangée mais restée isolée, « Range-moi »
        // serait faux (le journal dit pourquoi).
        case .normal, .montrerPanneau: modele.rappelerRangement = Isolement.estRangee != true
        default: break   // les épreuves tournent hors d'Applications exprès
        }
        let bilan = installerMiseAJour(dossierCarnet: dossierCarnet)

        installerElement()
        installerPanneau()
        abonnement = modele.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.majIcone() }
        }
        minuterie = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(minute(_:)),
                                         userInfo: nil, repeats: true)
        let centre = NSWorkspace.shared.notificationCenter
        centre.addObserver(self, selector: #selector(reveil(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        // Un voyage : le fuseau du Mac change, le jour civil avec lui.
        NotificationCenter.default.addObserver(self, selector: #selector(fuseauChange(_:)),
                                               name: .NSSystemTimeZoneDidChange, object: nil)

        switch mode {
        case .autotest(let d):
            Autotest(delegue: self, dossier: d).lancer()
        case .montrerPanneau(let d):
            // Deux photos : à l'ouverture (avec le rappel « Range-moi… » si
            // l'appli n'est pas dans Applications), puis une fois le rappel parti.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.ouvrirPanneau()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    Autotest.photographier(self.vueDuPanneau, vers: d.appendingPathComponent("panneau-ouverture.png"))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                        Autotest.photographier(self.vueDuPanneau, vers: d.appendingPathComponent("panneau.png"))
                        exit(0)
                    }
                }
            }
        case .normal(let auDemarrage):
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(ouvrirDemande(_:)),
                                                                name: Self.notificationOuvrir, object: nil)
            Demarrage.assurer(journal: journal)
            // Le panneau s'ouvre quand ELLE lance l'appli (un double-clic après
            // l'avoir quittée, ou si l'icône est cachée par l'encoche) — pas au
            // démarrage du Mac, pas à la relance qui suit une mise à jour.
            let relanceDeMiseAJour = (bilan != .rien)
            if !(lanceeALouverture || auDemarrage || relanceDeMiseAJour) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.ouvrirPanneau() }
            }
        case .epreuveClavier:
            break   // le script de l'épreuve clique lui-même sur l'icône
        default:
            break
        }
    }

    private func autreExemplaireEnRoute() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let moi = NSRunningApplication.current.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != moi && !$0.isTerminated }
    }

    /// Un double-clic sur l'appli alors qu'elle tourne déjà : le panneau s'ouvre.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        cederOuOuvrir()
        return false
    }

    @objc private func ouvrirDemande(_ n: Notification) { cederOuOuvrir() }

    /// On la rappelle (double-clic, autre exemplaire) : une copie qui tourne
    /// hors d'Applications cède la place à celle qu'elle vient d'y ranger.
    private func cederOuOuvrir() {
        if case .normal = mode, Isolement.cederSiPossible(journal: journal) {
            NSApp.terminate(nil)
            return
        }
        ouvrirPanneau()
    }

    // MARK: - La mise à jour

    /// Installe la mise à jour selon le mode, et rend le bilan de la pose
    /// précédente (s'il y en avait une).
    private func installerMiseAJour(dossierCarnet: URL) -> BilanPose {
        let memoire = MemoireMiseAJour(dossier: dossierCarnet)
        let reglages: MiseAJour.Reglages
        switch mode {
        case .normal:
            guard let r = MiseAJour.reglagesLivres(memoire: memoire) else {
                journal.noter("mise à jour : cette fabrication n'a pas de clé, pas de mise à jour automatique")
                return .rien
            }
            reglages = r
        case .epreuveMaj(_, let adresse, let cle):
            reglages = MiseAJour.Reglages(adresse: adresse, clePublique: cle, travail: MiseAJour.dossierDeTravail(),
                                          memoire: memoire, accepteLocal: true)
        default:
            return .rien   // les bacs à sable ne touchent pas aux mises à jour
        }
        let maj = MiseAJour(reglages: reglages, journal: journal)
        maj.peutPoser = { [weak self] in
            guard let self = self else { return false }
            return !self.popover.isShown && NSApp.modalWindow == nil
        }
        let bilan = maj.bilanAuDemarrage()
        if case .epreuveMaj(let d, _, _) = mode {
            // Si la pose part, l'appli se ferme d'elle-même ; sinon on dit pourquoi.
            maj.apresPremiereVerification = { issue in
                Self.ecrireResultat(Self.texte(issue), dans: d)
                exit(0)
            }
            maj.demarrer(premiereDans: 2)
        } else {
            maj.demarrer()
        }
        miseAJour = maj
        return bilan
    }

    static func texte(_ issue: MiseAJour.Issue) -> String {
        switch issue {
        case .echec(let m): return "ECHEC \(m)"
        case .rienAPoser(let i, let p): return "RIEN installée \(i), publiée \(p)"
        case .prete(let v): return "PRETE \(v) mais pas posée"
        case .acceptee(let v): return "ACCEPTEE \(v)"
        case .occupee: return "OCCUPEE"
        }
    }

    static func ecrireResultat(_ texte: String, dans d: URL) {
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        try? (texte + "\n").write(to: d.appendingPathComponent("resultat.txt"), atomically: true, encoding: .utf8)
    }

    private func controlerPublication(_ dossier: URL, adresse: URL?) {
        journal = Journal(dossier: dossier)
        let memoire = MemoireMiseAJour(dossier: dossier.appendingPathComponent("etat"))
        guard let r = MiseAJour.reglagesLivres(memoire: memoire) else {
            Self.ecrireResultat("ECHEC cette fabrication n'a pas de clé de mise à jour", dans: dossier)
            exit(1)
        }
        let reglages = MiseAJour.Reglages(adresse: adresse ?? r.adresse, clePublique: r.clePublique,
                                          travail: dossier.appendingPathComponent("travail"), memoire: memoire,
                                          accepteLocal: false)
        let maj = MiseAJour(reglages: reglages, journal: journal)
        Task {
            let issue = await maj.controler()
            Self.ecrireResultat(Self.texte(issue), dans: dossier)
            if case .acceptee = issue { exit(0) } else { exit(1) }
        }
    }

    private func eprouverDemarrage(_ dossier: URL) -> Never {
        // Inscrire comme au premier lancement, constater, puis tout défaire.
        var lignes = ["rangée dans Applications : \(Demarrage.dansApplications)", "avant : \(Demarrage.etatLisible)"]
        var ok = true
        // Déjà active, l'inscription ne prouverait rien (relecture du 06/10).
        if Demarrage.actif { ok = false; lignes.append("ÉCHEC : déjà active avant l'épreuve — rien ne serait prouvé") }
        do {
            try Demarrage.inscrire(true)
            lignes.append("après inscription : \(Demarrage.etatLisible)")
            if !Demarrage.actif { ok = false; lignes.append("ÉCHEC : pas active après inscription") }
            try Demarrage.inscrire(false)
            lignes.append("après désinscription : \(Demarrage.etatLisible)")
            if Demarrage.actif { ok = false; lignes.append("ÉCHEC : toujours active après désinscription") }
        } catch {
            ok = false
            lignes.append("ÉCHEC : \(error.localizedDescription) [\((error as NSError).domain) \((error as NSError).code)]")
        }
        Self.ecrireResultat((ok ? "REUSSI" : "ECHEC") + "\n" + lignes.joined(separator: "\n"), dans: dossier)
        exit(ok ? 0 : 1)
    }

    // MARK: - L'icône

    private func installerElement() {
        element = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let b = element.button else { return }
        b.imagePosition = .imageOnly
        b.toolTip = "Mot du jour"
        b.setAccessibilityLabel("Mot du jour")
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
            guard let self = self else { return ev }
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

    /// Le vrai clavier du Mac. Renvoie true si la touche a été prise. Seules
    /// les frappes destinées AU PANNEAU sont prises : une alerte ouverte depuis
    /// son menu garde les siennes (tour de code du 06/10 : Entrée partait au
    /// jeu, Échap fermait le panneau sous l'alerte).
    func traiterTouche(_ ev: NSEvent) -> Bool {
        guard popover.isShown, NSApp.modalWindow == nil,
              let fenetre = popover.contentViewController?.view.window, ev.window === fenetre else { return false }
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
            case .rienAPoser(let installee, _):
                alerte("Pas de nouvelle version à installer", detail: "Mot du jour \(installee) est installée.")
            case .prete(let v):
                alerte("La version \(v) est prête",
                       detail: "Elle s'installera toute seule dès que le panneau sera fermé, puis l'appli se relancera.")
            case .occupee:
                alerte("Une recherche est déjà en cours", detail: "Réessaie dans un instant.")
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
            try Demarrage.basculer()
            journal.noter("démarrage automatique : \(Demarrage.etatLisible) (choix dans le menu)")
        } catch {
            alerte("Le réglage du démarrage n'a pas pu être changé", detail: error.localizedDescription)
        }
    }

    @objc private func menuAPropos() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Le mot du jour de TokenBar, pour le Mac.\nMots : Lexique 3.83 (CC BY-SA 4.0) et Grammalecte (MPL 2.0) — sources : github.com/rakitchc-art/mot-du-jour-mac",
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

    // MARK: - Minuit, le réveil, le voyage

    /// La minuterie (toutes les 20 s) et la sortie de veille : minuit est-il passé ?
    func tic() {
        modele.verifierJour()
        majIcone()
    }

    /// La pastille telle qu'elle est posée dans la barre (pour l'autotest).
    var pastilleDansLaBarre: Bool? { pastilleAffichee }

    @objc private func reveil(_ n: Notification) { tic() }
    @objc private func minute(_ t: Timer) { tic() }
    @objc private func fuseauChange(_ n: Notification) {
        NSTimeZone.resetSystemTimeZone()
        tic()
    }
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
