import Foundation
import MotDuJourCore

/// « Dire à Dova quand j'ai joué » — voulu par Dova le 07/10/2026, avec
/// l'accord de Kelly : savoir SI elle se sert de l'appli.
///
/// Une fois par jour joué, l'appli envoie `{"jour": "AAAA-MM-JJ", "version":
/// "x.y.z"}` au registre (serveur-activite/serveur.mjs, sur le VPS) — jamais
/// le mot, ni ses essais, ni rien d'autre de son Mac. Les jours à signaler se
/// tirent du carnet (joursASignaler) : un jour joué hors connexion part plus
/// tard. Elle peut le couper dans le menu, et ce choix est gardé.
@MainActor
final class Signalement {
    private static let cleCoupe = "activiteCoupeeParElle"
    private static let cleSignales = "activiteJoursSignales"

    /// Coché tant qu'elle ne l'a pas décoché elle-même.
    static var actif: Bool { !UserDefaults.standard.bool(forKey: cleCoupe) }

    static func basculer() {
        UserDefaults.standard.set(actif, forKey: cleCoupe)
    }

    let adresse: URL
    let journal: Journal
    private var enVol = false
    private var prochaineTentative = Date.distantPast
    private var echecDejaDit: String?
    private let session = URLSession(configuration: .ephemeral)

    /// L'adresse d'Info.plist (MDJActiviteURL). `epreuve` : les épreuves des
    /// Mac de GitHub n'écrivent JAMAIS dans le vrai registre — seule une
    /// adresse locale (http://127.0.0.1) y est acceptée ; ailleurs, https.
    init?(journal: Journal, epreuve: Bool) {
        guard let a = Bundle.main.object(forInfoDictionaryKey: "MDJActiviteURL") as? String,
              let url = URL(string: a) else { return nil }
        if epreuve {
            guard url.scheme == "http", url.host == "127.0.0.1" else { return nil }
        } else {
            guard url.scheme == "https", url.host != nil else { return nil }
        }
        adresse = url
        self.journal = journal
    }

    /// Appelée au lancement puis à chaque tic (20 s) : envoie le plus ancien
    /// jour qui reste (le suivant au tic d'après). Un jour REFUSÉ par le
    /// registre (hors de ses dates, par exemple) est abandonné — sinon il
    /// bloquerait tous les suivants ; un échec passager (réseau, serveur) se
    /// retente au bout de 10 minutes, avec une seule ligne au journal.
    func signaler(carnet: Carnet) {
        guard Self.actif, !enVol, Date() >= prochaineTentative else { return }
        let deja = Set(UserDefaults.standard.stringArray(forKey: Self.cleSignales) ?? [])
        guard let jour = joursASignaler(joues: joursJoues(carnet), deja: deja, aujourdhui: jourLocal()).first else { return }
        enVol = true
        Task {
            defer { enVol = false }
            do {
                let code = try await envoyer(jour)
                // 201 : noté ; 200 : déjà noté (un envoi dont la réponse s'est
                // perdue) ; 400-499 sauf 429 : refusé pour de bon.
                if code == 200 || code == 201 {
                    journal.noter("activité : \(jour) signalé à Dova")
                } else if (400...499).contains(code) && code != 429 {
                    journal.noter("activité : \(jour) refusé par le registre (\(code)), abandonné")
                } else {
                    throw ErreurMaj("le registre a répondu \(code)")
                }
                // Les 30 derniers suffisent : la fenêtre n'en regarde que 7.
                let garde = Array((deja.union([jour])).sorted().suffix(30))
                UserDefaults.standard.set(garde, forKey: Self.cleSignales)
                echecDejaDit = nil
            } catch {
                prochaineTentative = Date().addingTimeInterval(600)
                if echecDejaDit != jour {
                    echecDejaDit = jour
                    journal.noter("activité : \(jour) pas encore signalé — \(error.localizedDescription) ; nouvel essai dans 10 minutes")
                }
            }
        }
    }

    private func envoyer(_ jour: String) async throws -> Int {
        var requete = URLRequest(url: adresse, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        requete.httpMethod = "POST"
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.setValue("MotDuJour/\(versionDeLAppli())", forHTTPHeaderField: "User-Agent")
        requete.httpBody = try JSONSerialization.data(withJSONObject: ["jour": jour, "version": versionDeLAppli()])
        let (_, reponse) = try await session.data(for: requete)
        return (reponse as? HTTPURLResponse)?.statusCode ?? 0
    }
}
