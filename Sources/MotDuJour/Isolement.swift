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

    /// Rangée dans un dossier Applications — par son VRAI emplacement, isolée
    /// ou non. nil : isolée, vrai emplacement inconnu.
    static var estRangee: Bool? {
        let reel = estIsolee ? cheminDOrigine() : Bundle.main.bundleURL
        return reel.map { Demarrage.estDansApplications($0.path) }
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
        guard relancer(origine, arguments: Array(CommandLine.arguments.dropFirst()) + [marqueRelance], journal: journal) else {
            return false
        }
        journal.noter("isolement : lancée depuis une copie isolée par macOS ; marque retirée de \(origine.path), relance depuis là")
        return true
    }

    // MARK: - Céder la place

    // Ouverte d'abord depuis le .dmg (l'erreur facile), puis rangée et rouverte
    // depuis Applications : sans cette règle, c'est la copie du .dmg — déjà en
    // route — qui rouvrait son panneau (« Range-moi… » sans fin), et celle
    // d'Applications ne s'inscrivait jamais au démarrage (relecture du 06/10).
    // Donc une copie HORS d'Applications cède toujours la place à celle
    // d'Applications, dès qu'il y en a une.

    /// La copie rangée dans un dossier Applications (même identifiant), s'il y en a une.
    static func copieRangee() -> URL? {
        let nom = Bundle.main.bundleURL.lastPathComponent
        let dossiers = [URL(fileURLWithPath: "/Applications", isDirectory: true),
                        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
        return dossiers.map { $0.appendingPathComponent(nom, isDirectory: true) }
            .first { Bundle(url: $0)?.bundleIdentifier == Bundle.main.bundleIdentifier }
    }

    /// Hors d'Applications (et SÛREMENT hors : un vrai emplacement inconnu ne
    /// cède jamais, sinon une appli isolée se relancerait elle-même sans fin)
    /// avec une copie rangée : la lance une fois celle-ci partie. Renvoie true
    /// si la relance est partie — l'appelant doit alors quitter.
    static func cederSiPossible(journal: Journal) -> Bool {
        guard estRangee == false, let copie = copieRangee() else { return false }
        guard relancer(copie, arguments: [], journal: journal) else { return false }
        journal.noter("rangement : ouverte hors d'Applications (\(Bundle.main.bundlePath)) — cède la place à \(copie.path)")
        return true
    }

    // MARK: - Relancer

    /// Lance l'appli rangée à `emplacement` dès que CET exemplaire est parti
    /// (sinon elle le trouverait en route et s'effacerait devant lui) — une
    /// minute d'attente au plus. Un lancement raté s'écrit au journal.
    static func relancer(_ emplacement: URL, arguments: [String], journal: Journal) -> Bool {
        let relance = Process()
        relance.executableURL = URL(fileURLWithPath: "/bin/sh")
        let script = """
            n=0
            while kill -0 "$1" 2>/dev/null && [ "$n" -lt 300 ]; do n=$((n + 1)); sleep 0.2; done
            j="$2"; shift 2
            if [ "$#" -gt 0 ]; then /usr/bin/open "$0" --args "$@"; else /usr/bin/open "$0"; fi \
              || echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)  relance : macOS n'a pas lancé $0" >> "$j"
            """
        relance.arguments = ["-c", script, emplacement.path, String(ProcessInfo.processInfo.processIdentifier),
                             journal.fichier.path] + arguments
        do {
            try relance.run()
            return true
        } catch {
            journal.noter("relance impossible — \(error.localizedDescription)")
            return false
        }
    }
}
