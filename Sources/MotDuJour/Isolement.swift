import Foundation

// ===========================================================================
//  L'« isolement » de macOS (App Translocation) : une appli marquée
//  « téléchargée » peut être lancée depuis une copie cachée en lecture seule
//  (…/AppTranslocation/…) au lieu de son vrai emplacement. Ainsi lancée, elle
//  ne peut ni se mettre à jour ni s'inscrire au démarrage du Mac : l'icône ne
//  reviendrait pas après un redémarrage.
//
//  Mesuré le 06/10 sur les Mac de GitHub : glissée par le Finder depuis un
//  .dmg marqué par Safari dans /Applications, puis marquée « autorisée »,
//  l'appli était quand même isolée. Que la vraie validation (« Ouvrir quand
//  même ») fasse pareil ou non chez elle, la parade est la même : si son vrai
//  emplacement est dans Applications, on retire la marque « téléchargée » de
//  CE dossier (elle l'a déjà autorisée) et on relance depuis là — ensuite,
//  plus jamais d'isolement. C'est la méthode des outils comme LetsMove.
//  Le vrai emplacement se demande à Security (fonction non publiée, présente
//  depuis macOS 10.12) ; si elle manque un jour, on ne fait rien et le panneau
//  rappelle « Range-moi dans Applications ».
// ===========================================================================

enum Isolement {
    /// Ajouté aux arguments de la relance : une appli relancée qui serait
    /// ENCORE isolée n'insiste pas. Une seule tentative, jamais de boucle.
    static let marqueRelance = "--sortie-isolement"

    static var estIsolee: Bool { Bundle.main.bundlePath.contains("/AppTranslocation/") }

    /// Le vrai emplacement d'une appli isolée, ou nil.
    static func cheminDOrigine() -> URL? {
        typealias Fonction = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let bibliotheque = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbole = dlsym(bibliotheque, "SecTranslocateCreateOriginalPathForURL") else { return nil }
        let fonction = unsafeBitCast(symbole, to: Fonction.self)
        guard let resultat = fonction(Bundle.main.bundleURL as CFURL, nil) else { return nil }
        return resultat.takeRetainedValue() as URL
    }

    /// Si l'appli est isolée alors que son vrai emplacement est dans
    /// Applications : retire la marque de téléchargement de ce dossier et
    /// relance l'appli depuis là, avec les mêmes arguments. Renvoie true si la
    /// relance est partie — l'appelant doit alors quitter tout de suite.
    static func sortirSiPossible(journal: Journal) -> Bool {
        let relancee = CommandLine.arguments.contains(marqueRelance)
        guard estIsolee else {
            if relancee { journal.noter("isolement : sortie réussie, l'appli tourne depuis \(Bundle.main.bundlePath)") }
            return false
        }
        if relancee {
            journal.noter("isolement : toujours isolée après la relance (\(Bundle.main.bundlePath)) — on n'insiste pas")
            return false
        }
        guard let origine = cheminDOrigine() else {
            journal.noter("isolement : l'appli tourne depuis une copie isolée par macOS, vrai emplacement inconnu")
            return false
        }
        guard Demarrage.estDansApplications(origine.path) else {
            journal.noter("isolement : lancée depuis \(origine.path), hors d'Applications — rien à faire, le panneau le rappelle")
            return false
        }
        // Le code de retour de xattr ne dit pas tout (un fichier du paquet sans
        // marque le fait échouer) : on constate l'effet sur le paquet lui-même.
        var detail = ""
        do {
            try MiseAJour.executer("/usr/bin/xattr", ["-d", "-r", "com.apple.quarantine", origine.path])
        } catch {
            detail = " — \(error.localizedDescription)"
        }
        guard getxattr(origine.path, "com.apple.quarantine", nil, 0, 0, 0) < 0 else {
            journal.noter("isolement : la marque de téléchargement est restée sur \(origine.path)\(detail)")
            return false
        }
        // La relance attend que CET exemplaire soit parti : sinon elle
        // trouverait l'appli déjà en route et s'effacerait devant lui.
        let relance = Process()
        relance.executableURL = URL(fileURLWithPath: "/bin/sh")
        let script = "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; shift; exec /usr/bin/open \"$0\" --args \"$@\""
        relance.arguments = ["-c", script, origine.path, String(ProcessInfo.processInfo.processIdentifier)]
            + CommandLine.arguments.dropFirst() + [marqueRelance]
        do {
            try relance.run()
        } catch {
            journal.noter("isolement : relance impossible — \(error.localizedDescription)")
            return false
        }
        journal.noter("isolement : lancée depuis une copie isolée par macOS ; marque retirée de \(origine.path), relance depuis là")
        return true
    }
}
