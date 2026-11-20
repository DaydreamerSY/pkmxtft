class_name L
extends RefCounted

## UI text in the chosen language: data/i18n/ui.json loaded into the TranslationServer
## by Settings. The key is the English text; a missing translation stays in English.
## Texts of the game data (synergies, items, statuses...) come from GameData.text.


static func t(s: String) -> String:
	return String(TranslationServer.translate(s))
