extends RefCounted


static func load_from_dir(asset_dir: String, file_name: String) -> Texture2D:
	if asset_dir.is_empty() or file_name.is_empty():
		return null
	var path := "%s/%s" % [asset_dir, file_name]
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
