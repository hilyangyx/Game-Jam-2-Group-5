extends RefCounted

const DEFAULT_LANGUAGE_PATH := "res://Localization/en.json"


static func load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func load_language(localization_dir: String, language_code: String) -> Dictionary:
	return load_json("%s/%s.json" % [localization_dir, language_code])


static func load_default() -> Dictionary:
	return load_json(DEFAULT_LANGUAGE_PATH)
