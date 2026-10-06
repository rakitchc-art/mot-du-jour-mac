import Foundation
import ServiceManagement

/// « Ouvrir au démarrage du Mac » : sans lui, l'icône disparaît au premier
/// redémarrage, et le mot du jour avec.
///
/// La règle (tour de code du 06/10) : à CHAQUE lancement depuis Applications,
/// si elle ne l'a pas coupé elle-même et que macOS ne la tient pas pour
/// inscrite, on l'inscrit — et le journal dit ce qu'il en est. Ainsi un échec
/// se retente au lancement suivant au lieu de se taire pour toujours, et une
/// appli lancée d'abord depuis le .dmg s'inscrit dès qu'elle est rangée.
/// Coupé dans le menu = jamais réactivé dans son dos.
enum Demarrage {
    private static let cleCoupe = "demarrageCoupeParElle"
    static let etiquette = "fr.dova.motdujour"

    /// Rangée dans un dossier Applications ? Hors de là (le .dmg, les
    /// Téléchargements, une copie « isolée » par macOS dont le chemin change à
    /// chaque lancement), rien de durable ne peut s'y accrocher : ni le
    /// démarrage automatique, ni la mise à jour.
    static var dansApplications: Bool {
        let chemin = Bundle.main.bundlePath
        let maison = FileManager.default.homeDirectoryForCurrentUser.path
        return chemin.hasPrefix("/Applications/") || chemin.hasPrefix(maison + "/Applications/")
    }

    static var actif: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentDeLancement.path)
    }

    /// L'état tel que macOS le rapporte, en clair (épreuves et journal).
    static var etatLisible: String {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .notRegistered: return "non inscrite"
            case .enabled: return "active"
            case .requiresApproval: return "en attente d'autorisation (Réglages Système > Général > Ouverture)"
            case .notFound: return "introuvable"
            @unknown default: return "état inconnu (\(SMAppService.mainApp.status.rawValue))"
            }
        }
        return FileManager.default.fileExists(atPath: agentDeLancement.path) ? "agent de lancement présent" : "pas d'agent de lancement"
    }

    /// Inscrit ou désinscrit, sans toucher à son choix.
    static func inscrire(_ oui: Bool) throws {
        if #available(macOS 13.0, *) {
            if oui { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return
        }
        if oui {
            try ecrireAgent()
        } else if FileManager.default.fileExists(atPath: agentDeLancement.path) {
            try FileManager.default.removeItem(at: agentDeLancement)
        }
    }

    /// Le menu : elle choisit. Son choix est gardé (couper = ne plus jamais
    /// réinscrire d'office).
    static func basculer() throws {
        let oui = !actif
        try inscrire(oui)
        UserDefaults.standard.set(!oui, forKey: cleCoupe)
    }

    /// À chaque lancement ordinaire : inscrire si besoin, et le dire au journal.
    static func assurer(journal: Journal) {
        guard dansApplications else {
            journal.noter("démarrage automatique : pas inscrit, l'appli ne tourne pas depuis Applications (\(Bundle.main.bundlePath))")
            return
        }
        if UserDefaults.standard.bool(forKey: cleCoupe) { return }
        if actif { return }
        do {
            try inscrire(true)
            journal.noter("démarrage automatique : inscrit (\(etatLisible))")
        } catch {
            journal.noter("démarrage automatique : l'inscription a échoué (\(etatLisible)) — \(error.localizedDescription) ; nouvel essai au prochain lancement")
        }
    }

    // macOS 12 : un agent de lancement dans ~/Library/LaunchAgents. Il passe
    // « --au-demarrage » à l'appli : lancée ainsi, elle n'ouvre pas son panneau.
    static var agentDeLancement: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(etiquette).plist")
    }

    private static func ecrireAgent() throws {
        let contenu: [String: Any] = [
            "Label": etiquette,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath, "--args", "--au-demarrage"],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: contenu, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: agentDeLancement.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: agentDeLancement, options: .atomic)
    }
}
