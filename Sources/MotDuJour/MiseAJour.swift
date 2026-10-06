import AppKit
import MotDuJourCore

// ===========================================================================
//  La mise à jour automatique (décision de Dova, 06/10/2026) — le GESTE :
//  demander, télécharger, vérifier, poser, relancer. Ce qui se décide est dans
//  le cœur (MiseAJourCoeur.swift), testé seul.
//
//  1. Toutes les 6 heures (la première fois une minute après le lancement),
//     l'API publique de GitHub donne la dernière publication du dépôt.
//  2. Plus récente, pas déjà refusée, avec son archive ET sa signature : on
//     télécharge. La signature Ed25519 doit être valide pour la clé publique
//     livrée dans l'appli (Info.plist) — sinon rien n'est posé.
//  3. L'archive est ouverte à part et vérifiée : la même appli (identifiant),
//     le bon numéro, une signature de code intacte.
//  4. Dès que le panneau est fermé (et qu'aucune alerte n'est ouverte) :
//     l'annonce est écrite sur le disque, un petit script attend que l'appli se
//     ferme, met l'ancienne de côté, pose la neuve et la relance — puis
//     SURVEILLE : si la neuve n'a pas fait son bilan en deux minutes (elle ne
//     démarre pas), l'ancienne revient et se relance.
//  5. Au démarrage, le bilan relit l'annonce : la neuve tourne → réussi ;
//     c'est toujours l'ancienne → cette version est refusée pour toujours
//     (leçon de TokenBar : jamais de boucle).
// ===========================================================================

struct ErreurMaj: LocalizedError {
    let texte: String
    init(_ texte: String) { self.texte = texte }
    var errorDescription: String? { texte }
}

@MainActor
final class MiseAJour: NSObject {
    struct Reglages {
        let adresse: URL
        let clePublique: String
        /// Les téléchargements (des Caches : rien d'irremplaçable).
        let travail: URL
        /// L'annonce, les refus, la sauvegarde de l'ancienne (Application Support).
        let memoire: MemoireMiseAJour
        /// L'épreuve de la fabrication seulement (versions servies en local).
        let accepteLocal: Bool
    }

    enum Issue: Equatable {
        /// Rien à poser : la version installée, et la dernière publiée.
        case rienAPoser(installee: String, publiee: String)
        case prete(String)
        case acceptee(String)
        case occupee
        case echec(String)
    }

    let reglages: Reglages
    let journal: Journal
    /// Peut-on poser maintenant ? Jamais sous ses yeux : panneau fermé, aucune alerte.
    var peutPoser: () -> Bool = { true }
    /// L'épreuve de la fabrication : ce qu'a donné la première vérification.
    var apresPremiereVerification: ((Issue) -> Void)?
    private(set) var prete: (version: String, app: URL)?
    private var enCours = false
    private var minuterie: Timer?
    private var dejaDit: Set<String> = []
    private let session = URLSession(configuration: .ephemeral)

    var sauvegarde: URL { reglages.memoire.sauvegarde }

    init(reglages: Reglages, journal: Journal) {
        self.reglages = reglages
        self.journal = journal
        super.init()
    }

    /// Les réglages livrés dans l'appli (Info.plist). nil : une fabrication
    /// sans clé — pas de mise à jour, et le journal le dit.
    static func reglagesLivres(memoire: MemoireMiseAJour) -> Reglages? {
        guard let a = Bundle.main.object(forInfoDictionaryKey: "MDJMiseAJourURL") as? String,
              let adresse = URL(string: a), adresse.scheme == "https",
              let cle = Bundle.main.object(forInfoDictionaryKey: "MDJMiseAJourCle") as? String, !cle.isEmpty else { return nil }
        return Reglages(adresse: adresse, clePublique: cle, travail: dossierDeTravail(),
                        memoire: memoire, accepteLocal: false)
    }

    static func dossierDeTravail() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches")
        return caches.appendingPathComponent("fr.dova.motdujour/maj", isDirectory: true)
    }

    func demarrer(premiereDans delai: TimeInterval = 60) {
        minuterie = Timer.scheduledTimer(timeInterval: 6 * 3600, target: self, selector: #selector(tic(_:)),
                                         userInfo: nil, repeats: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + delai) { [weak self] in
            Task {
                guard let self = self else { return }
                let issue = await self.verifier()
                self.apresPremiereVerification?(issue)
            }
        }
    }

    @objc private func tic(_ t: Timer) {
        Task { await verifier() }
    }

    var occupee: Bool { enCours }

    /// Au démarrage, AVANT tout : que dit la pose annoncée ?
    @discardableResult
    func bilanAuDemarrage() -> BilanPose {
        let bilan: BilanPose
        do {
            bilan = try reglages.memoire.bilan(versionCourante: versionDeLAppli())
        } catch {
            journal.noter("mise à jour : bilan illisible — \(error.localizedDescription)")
            return .rien
        }
        switch bilan {
        case .reussie(let v):
            journal.noter("mise à jour : \(v) posée et relancée")
            try? FileManager.default.removeItem(at: sauvegarde)
        case .ratee(let v):
            journal.noter("mise à jour : \(v) n'a pas pris, c'est toujours \(versionDeLAppli()) qui tourne — \(v) est refusée pour toujours")
            try? FileManager.default.removeItem(at: sauvegarde)
        case .rien:
            break
        }
        return bilan
    }

    /// Une phrase au journal, une seule fois par lancement (pas soixante fois).
    private func noterUneFois(_ cle: String, _ texte: String) {
        guard !dejaDit.contains(cle) else { return }
        dejaDit.insert(cle)
        journal.noter(texte)
    }

    // MARK: - Vérifier, télécharger, préparer

    @discardableResult
    func verifier() async -> Issue {
        if let p = prete {
            poserSiPossible()
            return .prete(p.version)
        }
        guard !enCours else { return .occupee }
        enCours = true
        defer { enCours = false }
        let courante = versionDeLAppli()
        do {
            let publication = try await lirePublication()
            guard let plan = planDeMiseAJour(publication, versionCourante: courante,
                                             refusees: reglages.memoire.refusees(),
                                             accepteLocal: reglages.accepteLocal) else {
                journal.noter("mise à jour : rien à poser (installée \(courante), publiée \(publication.tag_name))")
                return .rienAPoser(installee: courante, publiee: publication.tag_name)
            }
            journal.noter("mise à jour : \(plan.version) disponible, téléchargement")
            let archive = try await telecharger(plan.archive, maximum: 50_000_000)
            let signature = String(decoding: try await telecharger(plan.signature, maximum: 10_000), as: UTF8.self)
            guard signatureValide(archive, signatureBase64: signature, clePubliqueBase64: reglages.clePublique) else {
                journal.noter("mise à jour : signature INVALIDE pour \(plan.version) — rien n'est posé")
                return .echec("la signature de la version \(plan.version) ne correspond pas")
            }
            let app = try await preparer(archive, version: plan.version)
            prete = (plan.version, app)
            journal.noter("mise à jour : \(plan.version) téléchargée et vérifiée, prête à poser")
            poserSiPossible()
            return .prete(plan.version)
        } catch {
            let e = error as NSError
            journal.noter("mise à jour : échec — \(error.localizedDescription) [\(e.domain) \(e.code)]")
            return .echec(error.localizedDescription)
        }
    }

    /// Le contrôle d'une publication par l'appli elle-même, comme si elle
    /// était la plus vieille du monde : lisible, signée par la bonne clé,
    /// archive saine. Ne pose rien. Le script de publication s'en sert sur la
    /// publication encore en « préversion », avant de la rendre visible.
    func controler() async -> Issue {
        do {
            let publication = try await lirePublication()
            guard let plan = planDeMiseAJour(publication, versionCourante: "0.0.0", refusees: [],
                                             accepteLocal: reglages.accepteLocal, acceptePrepublication: true) else {
                return .echec("publication \(publication.tag_name) : archive ou signature absente")
            }
            let archive = try await telecharger(plan.archive, maximum: 50_000_000)
            let signature = String(decoding: try await telecharger(plan.signature, maximum: 10_000), as: UTF8.self)
            guard signatureValide(archive, signatureBase64: signature, clePubliqueBase64: reglages.clePublique) else {
                return .echec("la signature de la version \(plan.version) ne correspond pas à la clé de l'appli")
            }
            _ = try await preparer(archive, version: plan.version)
            return .acceptee(plan.version)
        } catch {
            return .echec(error.localizedDescription)
        }
    }

    private func lirePublication() async throws -> Publication {
        var requete = URLRequest(url: reglages.adresse, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        requete.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        requete.setValue("MotDuJour/\(versionDeLAppli())", forHTTPHeaderField: "User-Agent")
        let (data, reponse) = try await session.data(for: requete)
        guard let h = reponse as? HTTPURLResponse, h.statusCode == 200 else {
            throw ErreurMaj("les publications ont répondu \((reponse as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        return try JSONDecoder().decode(Publication.self, from: data)
    }

    private func telecharger(_ adresse: URL, maximum: Int) async throws -> Data {
        guard adresseAcceptable(adresse, accepteLocal: reglages.accepteLocal) else {
            throw ErreurMaj("adresse refusée : \(adresse.absoluteString)")
        }
        let requete = URLRequest(url: adresse, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        let (data, reponse) = try await session.data(for: requete)
        guard let h = reponse as? HTTPURLResponse, h.statusCode == 200 else {
            throw ErreurMaj("\(adresse.lastPathComponent) : réponse \((reponse as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        // GitHub redirige vers son stockage : l'adresse FINALE doit être sûre, elle aussi.
        if let finale = h.url, !adresseAcceptable(finale, accepteLocal: reglages.accepteLocal) {
            throw ErreurMaj("redirection refusée : \(finale.absoluteString)")
        }
        guard data.count <= maximum else { throw ErreurMaj("\(adresse.lastPathComponent) : trop gros (\(data.count) octets)") }
        return data
    }

    /// Ouvre l'archive à part et vérifie ce qu'elle contient — hors du fil de
    /// l'interface (ditto et codesign prennent quelques dixièmes de seconde).
    private func preparer(_ archive: Data, version: String) async throws -> URL {
        let travail = reglages.travail
        let identifiant = Bundle.main.bundleIdentifier ?? ""
        return try await Task.detached(priority: .utility) {
            try MiseAJour.ouvrirArchive(archive, version: version, travail: travail, identifiant: identifiant)
        }.value
    }

    nonisolated static func ouvrirArchive(_ archive: Data, version: String, travail: URL, identifiant: String) throws -> URL {
        let fm = FileManager.default
        let dossier = travail.appendingPathComponent("v\(version)", isDirectory: true)
        try? fm.removeItem(at: dossier)
        try fm.createDirectory(at: dossier, withIntermediateDirectories: true)
        let zip = dossier.appendingPathComponent("archive.zip")
        try archive.write(to: zip)
        let extrait = dossier.appendingPathComponent("extrait", isDirectory: true)
        try executer("/usr/bin/ditto", ["-x", "-k", zip.path, extrait.path])
        let app = extrait.appendingPathComponent("Mot du jour.app", isDirectory: true)
        guard let lu = versionDuPaquet(app) else { throw ErreurMaj("l'archive ne contient pas « Mot du jour.app »") }
        guard lu.identifiant == identifiant else {
            throw ErreurMaj("l'archive contient une autre appli (\(lu.identifiant))")
        }
        guard composantesVersion(lu.version) == composantesVersion(version) else {
            throw ErreurMaj("l'archive dit \(lu.version), la publication \(version)")
        }
        try executer("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        return app
    }

    @discardableResult
    nonisolated static func executer(_ outil: String, _ arguments: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: outil)
        p.arguments = arguments
        let tuyau = Pipe()
        p.standardOutput = tuyau
        p.standardError = tuyau
        try p.run()
        let sortie = String(decoding: tuyau.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw ErreurMaj("\((outil as NSString).lastPathComponent) a échoué (\(p.terminationStatus)) : \(sortie)")
        }
        return sortie
    }

    // MARK: - Poser

    /// Pose la version prête si le moment s'y prête : panneau fermé, aucune
    /// alerte, appli rangée là où elle peut être remplacée.
    func poserSiPossible() {
        guard let p = prete, peutPoser() else { return }
        let app = Bundle.main.bundleURL
        guard Demarrage.dansApplications else {
            noterUneFois("place", "mise à jour : l'appli ne tourne pas depuis Applications (\(app.path)) — il faut l'y ranger pour qu'elle se mette à jour")
            return
        }
        let parent = app.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            noterUneFois("droits", "mise à jour : pas le droit d'écrire dans \(parent.path), rien n'est posé")
            return
        }
        let script = reglages.travail.appendingPathComponent("poser.sh")
        let memoire = reglages.memoire
        do {
            try FileManager.default.createDirectory(at: reglages.travail, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: memoire.dossier, withIntermediateDirectories: true)
            try MiseAJour.scriptDePose.write(to: script, atomically: true, encoding: .utf8)
            try memoire.annoncer(PoseAttendue(version: p.version, depuis: versionDeLAppli(), utc: horodatage(Date())))
            let pose = Process()
            pose.executableURL = URL(fileURLWithPath: "/bin/sh")
            pose.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), app.path, p.app.path,
                              sauvegarde.path, memoire.fichierAttendue.path, journal.fichier.path]
            try pose.run()
            journal.noter("mise à jour : pose de \(p.version) lancée, l'appli se relance")
            NSApp.terminate(nil)
        } catch {
            memoire.oublierAnnonce()
            journal.noter("mise à jour : pose impossible — \(error.localizedDescription)")
        }
    }

    /// Le script de pose : il tourne APRÈS la fermeture de l'appli. Chaque
    /// échec remet l'ancienne en place ; chaque étape s'écrit au journal.
    static let scriptDePose = """
    #!/bin/sh
    # Pose la nouvelle version de Mot du jour, la relance, et la surveille.
    # $1 PID de l'appli qui se ferme   $2 l'appli en place   $3 la neuve
    # $4 où mettre l'ancienne de côté  $5 l'annonce (effacée par la neuve à son démarrage)
    # $6 le journal
    PID="$1"; APP="$2"; NEUVE="$3"; ANCIENNE="$4"; ANNONCE="$5"; JOURNAL="$6"
    note() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)  pose : $1" >> "$JOURNAL"; }
    # Trois essais : juste après une sortie, macOS refuse parfois de lancer
    # (mesuré le 06/10) — et une neuve jamais lancée serait jugée ratée.
    lancer() {
      for essai in 1 2 3; do
        sleep 0.5
        r=$(/usr/bin/open "$1" 2>&1) && return 0
        note "macOS n'a pas lancé $1 (essai $essai) — $r"
        sleep 1.5
      done
      return 1
    }
    n=0
    while kill -0 "$PID" 2>/dev/null; do
      n=$((n + 1))
      if [ "$n" -gt 150 ]; then note "l'appli ne s'est pas fermée en 30 s, rien n'est touché"; exit 1; fi
      sleep 0.2
    done
    rm -rf "$ANCIENNE"
    if ! mv "$APP" "$ANCIENNE"; then
      note "impossible de mettre l'ancienne de côté, rien n'est touché"
      lancer "$APP"
      exit 1
    fi
    if ! mv "$NEUVE" "$APP"; then
      note "impossible de poser la neuve : l'ancienne est remise"
      mv "$ANCIENNE" "$APP"
    fi
    /usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null
    lancer "$APP"
    note "relancée : $APP"
    # La surveillance : la neuve efface l'annonce en démarrant. Deux minutes
    # sans bilan = elle ne démarre pas : l'ancienne revient (et, en démarrant,
    # refuse pour toujours cette version — pas de boucle).
    n=0
    while [ -f "$ANNONCE" ]; do
      n=$((n + 1))
      if [ "$n" -gt 600 ]; then break; fi
      sleep 0.2
    done
    if [ -f "$ANNONCE" ]; then
      note "la neuve n'a pas fait son bilan en 2 minutes : l'ancienne revient"
      pkill -f "$APP/Contents/MacOS/" 2>/dev/null
      sleep 1
      if [ -f "$ANNONCE" ] && [ -d "$ANCIENNE" ]; then
        rm -rf "$APP.ratee"
        if ! mv "$APP" "$APP.ratee"; then
          note "le retour de l'ancienne a échoué : la neuve n'a pas pu être écartée"
        elif mv "$ANCIENNE" "$APP"; then
          rm -rf "$APP.ratee"
          note "ancienne remise"
        else
          # Dernier recours : jamais d'Applications sans l'appli.
          mv "$APP.ratee" "$APP"
          note "le retour de l'ancienne a échoué : la neuve reste en place"
        fi
      fi
      lancer "$APP"
    fi
    """
}
