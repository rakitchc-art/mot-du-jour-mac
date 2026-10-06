import AppKit

// ===========================================================================
//  Mot du jour — l'appli de la barre des menus.
//
//  Lancée sans argument (double-clic, démarrage du Mac) : l'icône se pose en
//  haut à droite, un clic ouvre le panneau. Les arguments ne servent qu'à la
//  fabrication et aux épreuves, sur les Mac de GitHub :
//    --version                                 écrit la version et s'arrête
//    --au-demarrage                            lancée par l'agent de macOS 12 (pas de panneau)
//    --sortie-isolement                        ajouté par l'appli à sa propre relance (Isolement.swift)
//    --apercu <dossier>                        dessine les planches (les looks) en PNG
//    --icone <dossier>                         dessine les icônes de l'appli (pour le .icns)
//    --fond-dmg <dossier>                      dessine le fond de la fenêtre du .dmg
//    --autotest <dossier>                      joue une partie scriptée dans le vrai panneau
//    --epreuve-maj <dossier> <adresse> <clé>   la mise à jour, par le chemin de tous les jours
//    --controle-publication <dossier> [adresse] l'appli juge une publication en ligne
//    --epreuve-demarrage <dossier>             « Ouvrir au démarrage » : inscrire, constater, défaire
//    --epreuve-clavier <dossier>               l'appli ordinaire, carnet dans un bac à sable
//    --montrer-panneau <dossier>               une photo du vrai panneau ouvert
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
        func valeur(apres option: String, rang: Int = 1) -> String? {
            guard let i = arguments.firstIndex(of: option), i + rang < arguments.count else { return nil }
            let v = arguments[i + rang]
            return v.hasPrefix("--") ? nil : v
        }
        func dossier(apres option: String) -> URL? {
            valeur(apres: option).map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
        let mode: Delegue.Mode
        if let d = dossier(apres: "--apercu") { mode = .apercu(d) }
        else if let d = dossier(apres: "--icone") { mode = .icone(d) }
        else if let d = dossier(apres: "--fond-dmg") { mode = .fondDmg(d) }
        else if let d = dossier(apres: "--autotest") { mode = .autotest(d) }
        else if let d = dossier(apres: "--controle-publication") {
            mode = .controlePublication(d, valeur(apres: "--controle-publication", rang: 2).flatMap(URL.init(string:)))
        }
        else if let d = dossier(apres: "--epreuve-demarrage") { mode = .epreuveDemarrage(d) }
        else if let d = dossier(apres: "--epreuve-clavier") { mode = .epreuveClavier(d) }
        else if let d = dossier(apres: "--montrer-panneau") { mode = .montrerPanneau(d) }
        else if let d = dossier(apres: "--epreuve-maj"),
                let a = valeur(apres: "--epreuve-maj", rang: 2), let adresse = URL(string: a),
                let cle = valeur(apres: "--epreuve-maj", rang: 3) {
            mode = .epreuveMaj(d, adresse, cle)
        }
        else { mode = .normal(auDemarrage: arguments.contains("--au-demarrage")) }

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
