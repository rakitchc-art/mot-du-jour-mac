import AppKit

// ===========================================================================
//  Mot du jour — l'appli de la barre des menus.
//
//  Lancée sans argument (double-clic, démarrage du Mac) : l'icône se pose en
//  haut à droite, un clic ouvre le panneau. Les arguments ne servent qu'à la
//  fabrication, sur les Mac de GitHub :
//    --version            écrit la version et s'arrête
//    --apercu <dossier>   dessine les planches (les looks possibles) en PNG
//    --icone <dossier>    dessine les icônes de l'appli (pour le .icns)
//    --autotest <dossier> joue une partie scriptée dans le vrai panneau
//    --epreuve-maj <dossier> <adresse> <clé>   l'épreuve de la mise à jour
//    --apres-maj <dossier>                     sa relance : écrit le bilan
//    --controle-publication <dossier>          l'appli juge la publication en ligne
// ===========================================================================

@main
struct Lanceur {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--version") {
            print(versionDeLAppli())
            return
        }
        func dossier(apres option: String) -> URL? {
            guard let i = arguments.firstIndex(of: option), i + 1 < arguments.count else { return nil }
            return URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
        }
        let mode: Delegue.Mode
        if let d = dossier(apres: "--apercu") { mode = .apercu(d) }
        else if let d = dossier(apres: "--icone") { mode = .icone(d) }
        else if let d = dossier(apres: "--autotest") { mode = .autotest(d) }
        else if let d = dossier(apres: "--apres-maj") { mode = .apresMaj(d) }
        else if let d = dossier(apres: "--controle-publication") { mode = .controlePublication(d) }
        else if let i = arguments.firstIndex(of: "--epreuve-maj"), i + 3 < arguments.count,
                let adresse = URL(string: arguments[i + 2]) {
            mode = .epreuveMaj(URL(fileURLWithPath: arguments[i + 1], isDirectory: true), adresse, arguments[i + 3])
        }
        else { mode = .normal }

        let application = NSApplication.shared
        let delegue = Delegue(mode: mode)
        application.delegate = delegue
        application.setActivationPolicy(.accessory)   // pas d'icône dans le Dock : elle vit en haut à droite
        application.run()
        withExtendedLifetime(delegue) {}
    }
}

func versionDeLAppli() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
}
