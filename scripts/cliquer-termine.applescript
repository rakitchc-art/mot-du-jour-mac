-- Ferme l'avertissement de Gatekeeper par son bouton « Terminé » (jamais
-- « Placer dans la corbeille ») : c'est après lui que Réglages Système montre
-- « Ouvrir quand même ». Sert aux photos de la notice, sur le Mac de GitHub.
tell application "System Events"
	set agent to first process whose name is "CoreServicesUIAgent"
	tell agent
		repeat with nom in {"Terminé", "Done", "OK"}
			try
				click button (nom as text) of window 1
				return "cliqué : " & (nom as text)
			end try
		end repeat
	end tell
end tell
return "aucun bouton « Terminé » trouvé"
