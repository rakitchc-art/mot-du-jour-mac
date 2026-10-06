-- Le centre de l'icône de Mot du jour dans la barre des menus, en points
-- d'écran (« x y »), lu par l'accessibilité de macOS. Sert à l'épreuve du vrai
-- clavier (epreuve-clavier.sh), qui clique ensuite à cet endroit.
on run argv
	set pid to (item 1 of argv) as integer
	tell application "System Events"
		set p to first process whose unix id is pid
		repeat with barre in (menu bars of p)
			try
				set icone to menu bar item 1 of barre
				set {x, y} to position of icone
				set {l, h} to size of icone
				return ((x + (l div 2)) as text) & " " & ((y + (h div 2)) as text)
			end try
		end repeat
	end tell
	return "introuvable"
end run
