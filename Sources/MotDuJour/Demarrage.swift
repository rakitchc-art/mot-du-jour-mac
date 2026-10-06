import Foundation
import ServiceManagement

/// « Ouvrir au démarrage du Mac » : sans lui, l'icône disparaît au premier
/// redémarrage et le mot du jour avec. Activé tout seul au TOUT PREMIER
/// lancement (comme la barre de Dova sous Windows), débrayable dans le menu —
/// et jamais réactivé dans son dos une fois qu'elle l'a coupé.
enum Demarrage {
    private static let cleDecide = "demarrageDejaDecide"
    static let etiquette = "fr.dova.motdujour"

    /// Lancée depuis une copie « isolée » par macOS (ouverte directement dans
    /// Téléchargements ou dans le .dmg) : son chemin change à chaque lancement,
    /// rien de durable ne peut s'y accrocher.
    static var appliIsolee: Bool { Bundle.main.bundlePath.contains("/AppTranslocation/") }

    static var actif: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentDeLancement.path)
    }

    static func activer(_ oui: Bool) throws {
        UserDefaults.standard.set(true, forKey: cleDecide)
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

    static func activerAuPremierLancement() {
        guard !UserDefaults.standard.bool(forKey: cleDecide), !appliIsolee else { return }
        try? activer(true)
    }

    // macOS 12 : un agent de lancement dans ~/Library/LaunchAgents.
    static var agentDeLancement: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(etiquette).plist")
    }

    private static func ecrireAgent() throws {
        let contenu: [String: Any] = [
            "Label": etiquette,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: contenu, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: agentDeLancement.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: agentDeLancement, options: .atomic)
    }
}
