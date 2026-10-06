-- La fenêtre du .dmg, comme celle des applis du commerce : petite, l'appli à
-- gauche, le dossier Applications à droite, et un fond avec une flèche entre
-- les deux. Lancé par construire-app.sh sur le .dmg monté en écriture ; s'il
-- échoue, le .dmg reste utilisable (fenêtre simple) et le journal le dit.
on run argv
	set nomVolume to item 1 of argv
	tell application "Finder"
		tell disk nomVolume
			open
			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set the bounds of container window to {200, 120, 740, 460}
			set reglages to the icon view options of container window
			set arrangement of reglages to not arranged
			set icon size of reglages to 96
			set text size of reglages to 13
			set background picture of reglages to file ".fond:fond.tiff"
			set position of item "Mot du jour.app" of container window to {140, 150}
			set position of item "Applications" of container window to {400, 150}
			update without registering applications
			delay 2
			close
		end tell
	end tell
	return "mise en page posée"
end run
