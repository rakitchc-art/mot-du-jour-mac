import Foundation
import MotDuJourCore

/// Le journal de l'appli : ~/Library/Logs/Mot du jour/journal.txt.
///
/// Ce qui ne se voit pas à l'écran — les mises à jour surtout — s'y lit après
/// coup. C'est ce fichier qu'on demanderait à son amie si quelque chose
/// cloche (il s'ouvre dans la Console du Mac, ou d'un double-clic).
final class Journal {
    let fichier: URL

    init(dossier: URL) {
        fichier = dossier.appendingPathComponent("journal.txt")
    }

    static func parDefaut() -> Journal {
        let bibliotheque = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return Journal(dossier: bibliotheque.appendingPathComponent("Logs/Mot du jour", isDirectory: true))
    }

    func noter(_ ligne: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Il ne grossit pas sans fin : au-delà de 256 Ko, l'ancien passe en journal.1.txt.
        if let taille = (try? fm.attributesOfItem(atPath: fichier.path))?[.size] as? NSNumber, taille.intValue > 256_000 {
            let ancien = fichier.deletingLastPathComponent().appendingPathComponent("journal.1.txt")
            try? fm.removeItem(at: ancien)
            try? fm.moveItem(at: fichier, to: ancien)
        }
        let texte = horodatage(Date()) + "  " + ligne + "\n"
        if let h = try? FileHandle(forWritingTo: fichier) {
            h.seekToEndOfFile()
            h.write(Data(texte.utf8))
            h.closeFile()
        } else {
            try? Data(texte.utf8).write(to: fichier)
        }
    }
}
