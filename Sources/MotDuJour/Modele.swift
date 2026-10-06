import Foundation
import MotDuJourCore

/// L'état vivant du panneau : le jeu, le jour affiché, la ligne en cours de
/// frappe, le message passager. Toutes les règles sont dans le cœur ; ici,
/// seulement les gestes et l'enregistrement.
final class Modele: ObservableObject {
    @Published private(set) var jeu: Jeu
    @Published private(set) var aujourdhui: String
    @Published private(set) var jourAffiche: String
    @Published private(set) var saisie = Saisie()
    @Published private(set) var vueStats = false
    @Published private(set) var message: MessagePassager?
    /// Chaque refus la fait monter : la ligne en cours tremble.
    @Published private(set) var secousse = 0

    let depot: Depot?
    /// Le premier lancement (le carnet n'existait pas encore).
    let premierLancement: Bool
    /// L'appli ne tourne pas depuis Applications : chaque ouverture le rappelle
    /// (sans cela, elle ne se met jamais à jour ni ne démarre avec le Mac).
    var rappelerRangement = false
    private var avertissement: String?
    private var effacement: DispatchWorkItem?
    /// Le jour courant. Remplaçable par l'autotest seulement, pour faire passer
    /// minuit sans attendre minuit.
    var horloge: () -> String

    init(depot: Depot?, dico: Dictionnaire = .livre, horloge: @escaping () -> String = { jourLocal() }) {
        self.depot = depot
        self.horloge = horloge
        let auj = horloge()
        var carnet = Carnet(premierJour: auj)
        var premier = true
        if let d = depot {
            premier = !FileManager.default.fileExists(atPath: d.fichier.path)
            let lu = d.charger(aujourdhui: auj)
            carnet = lu.carnet
            avertissement = lu.avertissement
        }
        var j = Jeu(dico: dico, carnet: carnet)
        let recale = j.recalerPremierJour(aujourdhui: auj)
        jeu = j
        aujourdhui = auj
        jourAffiche = auj
        premierLancement = premier
        // Écrire tout de suite au premier lancement : c'est ce qui fixe le
        // premier jour (les flèches ne remonteront pas avant).
        if premier || recale || avertissement != nil { enregistrer() }
    }

    var etat: VueEtat {
        presenter(jeu: jeu, jour: jourAffiche, aujourdhui: aujourdhui, saisie: saisie,
                  message: message, vueStats: vueStats)
    }

    /// Un mot attend : aujourd'hui n'est pas fini.
    var pastille: Bool { !(jeu.grille(aujourdhui)?.fini ?? false) }

    private var jouable: Bool { jeu.jouable(jourAffiche, aujourdhui: aujourdhui) }

    // MARK: - Les gestes

    func touche(_ t: ToucheClavier) {
        switch t {
        case .lettre(let l): taper(l)
        case .entree: valider()
        case .effacer: effacer()
        }
    }

    func taper(_ l: Character) {
        // Les stats affichées n'acceptent pas de lettres (comme TokenBar,
        // Integration-TokenBar.ps1) : on revient à la grille par le bouton.
        guard !vueStats else { return }
        guard jouable else { return grilleFinie() }
        if message?.erreur == true { message = nil }
        saisie.taper(l)
    }

    func effacer() {
        guard jouable, !vueStats else { return }
        if message?.erreur == true { message = nil }
        saisie.effacer()
    }

    func deplacer(_ pas: Int) {
        guard jouable, !vueStats else { return }
        saisie.deplacer(pas)
    }

    func clicCase(_ index: Int) {
        guard jouable else { return }
        saisie.placer(index)
    }

    func valider() {
        guard !vueStats else { return }
        guard jouable else { return grilleFinie() }
        guard saisie.prete else { return refuser("Il faut cinq lettres") }
        switch jeu.proposer(saisie.mot, jour: jourAffiche, aujourdhui: aujourdhui) {
        case .joue:
            saisie.vider()
            message = nil
            enregistrer()
        case .inconnu:
            refuser("Mot inconnu")
        case .malforme:
            refuser("Il faut cinq lettres")
        case .dejaFini:
            grilleFinie()
        case .horsBornes:
            passager(MessagePassager("Ce jour ne se joue pas", erreur: true), duree: 2)
        }
    }

    func precedent() {
        guard let n = numeroDeJour(jourAffiche), let p = numeroDeJour(jeu.carnet.premierJour), n > p else { return }
        allerAu(jourDeNumero(n - 1))
    }

    func suivant() {
        guard let n = numeroDeJour(jourAffiche), let a = numeroDeJour(aujourdhui), n < a else { return }
        allerAu(jourDeNumero(n + 1))
    }

    func basculerStats() {
        vueStats.toggle()
        message = nil
    }

    /// À chaque ouverture du panneau : toujours le jour courant, ligne vide
    /// (comme TokenBar, Mot-Barre.ps1 Reset-NavigationMot) — sinon, après
    /// minuit, une ligne commencée la veille partirait sur « Hier ».
    func ouverture() {
        verifierJour()
        if jourAffiche != aujourdhui { allerAu(aujourdhui) }
        vueStats = false
        if let a = avertissement {
            avertissement = nil
            passager(MessagePassager(a, erreur: true), duree: 6)
        } else if rappelerRangement {
            passager(MessagePassager("Range-moi dans Applications pour que je reste", erreur: true), duree: 6)
        }
    }

    /// Minuit est-il passé ? Renvoie true si la page a tourné. Le panneau
    /// ouvert ne saute PAS au jour neuf sous ses yeux : le jour affiché reste
    /// jouable (il devient « hier », qui se rattrape, et le titre le dit) ;
    /// l'ouverture suivante ramène au jour courant.
    @discardableResult
    func verifierJour() -> Bool {
        let j = horloge()
        guard j != aujourdhui else { return false }
        aujourdhui = j
        if jeu.recalerPremierJour(aujourdhui: j) { enregistrer() }
        // L'horloge a reculé : le jour affiché ne peut pas être dans le futur.
        if let n = numeroDeJour(jourAffiche), let a = numeroDeJour(j), n > a { allerAu(j) }
        return true
    }

    // MARK: - En interne

    private func allerAu(_ jour: String) {
        jourAffiche = jour
        saisie.vider()
        vueStats = false
        message = nil
    }

    private func refuser(_ texte: String) {
        secousse += 1
        passager(MessagePassager(texte, erreur: true), duree: 2)
    }

    /// Une frappe sur une grille finie produit un signe visible, sinon elle
    /// passerait pour une panne (Règle 15 du CDC).
    private func grilleFinie() {
        passager(MessagePassager("Cette grille est finie", erreur: false), duree: 1.6)
    }

    private func passager(_ m: MessagePassager, duree: Double) {
        message = m
        effacement?.cancel()
        let tache = DispatchWorkItem { [weak self] in
            if self?.message == m { self?.message = nil }
        }
        effacement = tache
        DispatchQueue.main.asyncAfter(deadline: .now() + duree, execute: tache)
    }

    private func enregistrer() {
        guard let d = depot else { return }
        do {
            try d.enregistrer(jeu.carnet)
        } catch {
            passager(MessagePassager("Impossible d'enregistrer : \(error.localizedDescription)", erreur: true), duree: 6)
        }
    }
}
