// swift-tools-version:5.9
import PackageDescription

// Mot du jour — le mot du jour de TokenBar, dans la barre des menus du Mac.
//
//   MotDuJourCore   les règles, sans interface (testées seules)
//   MotDuJour       l'appli : l'icône, le panneau, les planches, l'autotest
//
// L'appli se fabrique sur un Mac (les Mac de GitHub) : scripts/construire-app.sh.
let package = Package(
    name: "MotDuJour",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "MotDuJourCore", path: "Sources/MotDuJourCore"),
        .executableTarget(name: "MotDuJour", dependencies: ["MotDuJourCore"], path: "Sources/MotDuJour"),
        .testTarget(name: "MotDuJourCoreTests", dependencies: ["MotDuJourCore"], path: "Tests/MotDuJourCoreTests",
                    resources: [.copy("vecteurs.json")]),
    ]
)
