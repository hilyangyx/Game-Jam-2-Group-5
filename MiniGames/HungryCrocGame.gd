extends Control

signal game_won
signal game_lost(reason)

const ASSET_DIR := "res://Assets/Croc"

var safe_tooth_index := 0
var locked := false
var teeth: Array[Button] = []
var texts: Dictionary = {}
var mouth_panel: Panel
var mouth_art: TextureRect


static func make_seed_data(rng: RandomNumberGenerator) -> Dictionary:
	return {"safe_tooth_index": rng.randi_range(0, 7)}


func _ready() -> void:
	_build_ui()


func setup_game(seed_data: Dictionary, _context: Dictionary = {}, new_texts: Dictionary = {}) -> void:
	setup(int(seed_data.get("safe_tooth_index", 0)), new_texts)


func setup(new_safe_tooth_index: int, new_texts: Dictionary = {}) -> void:
	safe_tooth_index = new_safe_tooth_index
	texts = new_texts.duplicate(true)


func set_texts(new_texts: Dictionary) -> void:
	texts = new_texts.duplicate(true)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 24.0
	root.offset_top = 14.0
	root.offset_right = -24.0
	root.offset_bottom = -18.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	mouth_panel = Panel.new()
	mouth_panel.custom_minimum_size = Vector2(760, 210)
	mouth_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(mouth_panel)

	mouth_art = TextureRect.new()
	mouth_art.texture = _load_texture("croc_mouth.png")
	mouth_art.anchor_left = 0.04
	mouth_art.anchor_top = 0.02
	mouth_art.anchor_right = 0.96
	mouth_art.anchor_bottom = 0.98
	mouth_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouth_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouth_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth_panel.add_child(mouth_art)

	var tooth_grid := GridContainer.new()
	tooth_grid.columns = 4
	tooth_grid.anchor_left = 0.12
	tooth_grid.anchor_top = 0.36
	tooth_grid.anchor_right = 0.88
	tooth_grid.anchor_bottom = 0.92
	tooth_grid.add_theme_constant_override("h_separation", 12)
	tooth_grid.add_theme_constant_override("v_separation", 10)
	mouth_panel.add_child(tooth_grid)

	teeth.clear()
	for i in range(8):
		var button := _make_tooth_button(i)
		button.pressed.connect(_on_tooth_pressed.bind(i))
		tooth_grid.add_child(button)
		teeth.append(button)


func _on_tooth_pressed(index: int) -> void:
	if locked:
		return
	locked = true
	for tooth in teeth:
		tooth.disabled = true
	if index == safe_tooth_index:
		_set_tooth_visual(index, "tooth_safe.png")
		await get_tree().create_timer(0.45).timeout
		game_won.emit()
	else:
		_set_tooth_visual(index, "tooth_lethal.png")
		await get_tree().create_timer(0.45).timeout
		game_lost.emit("croc_tooth")


func _make_tooth_button(_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(82, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true

	var asset_texture := TextureRect.new()
	asset_texture.name = "AssetTexture"
	asset_texture.anchor_left = 0.12
	asset_texture.anchor_top = 0.10
	asset_texture.anchor_right = 0.88
	asset_texture.anchor_bottom = 0.90
	asset_texture.texture = _load_texture("tooth_idle.png")
	asset_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	asset_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	asset_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(asset_texture)

	return button


func _set_tooth_visual(index: int, asset_name: String) -> void:
	if index < 0 or index >= teeth.size():
		return
	var asset_texture: TextureRect = teeth[index].get_node("AssetTexture") as TextureRect
	var texture: Texture2D = _load_texture(asset_name)
	asset_texture.texture = texture


func _txt(key: String) -> String:
	return str(texts.get(key, key))


func _load_texture(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	var path: String = "%s/%s" % [ASSET_DIR, file_name]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
