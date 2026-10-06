// Un VRAI clic de souris à un point de l'écran (en points, origine en haut à
// gauche) : un appui et un relâchement du bouton gauche, déposés là où macOS
// dépose ceux de la vraie souris. Sert à l'épreuve du vrai clavier.
//   swift scripts/cliquer.swift <x> <y>
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3, let x = Double(arguments[1]), let y = Double(arguments[2]) else {
    print("usage : swift scripts/cliquer.swift <x> <y>")
    exit(2)
}
let point = CGPoint(x: x, y: y)
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(150_000)
for type in [CGEventType.leftMouseDown, .leftMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(90_000)
}
print("clic en \(Int(x)), \(Int(y))")
