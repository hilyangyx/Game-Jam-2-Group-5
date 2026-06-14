extends Control

signal game_won
signal game_lost(reason)

const ASSET_DIR := "res://Assets/Cards"
const CARD_FACE_ASSETS := {
	"chips": "card_chips.png",
	"dice": "card_dices.png",
	"poker": "card_poker.png",
	"slot": "card_slotmachine.png"
}

var layout_data: Array = []
var card_buttons: Array[Button] = []
var matched: Array[bool] = []
var selected: Array[int] = []
var locked := false
var matched_pairs := 0
var texts: Dictionary = {}

var grid: GridContainer


static func make_seed_data(rng: RandomNumberGenerator) -> Dictionary:
	var new_layout: Array = ["chips", "chips", "dice", "dice", "poker", "poker", "slot", "slot"]
	_shuffle_seed_array(new_layout, rng)
	return {"layout": new_layout}


static func _shuffle_seed_array(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = array[i]
		array[i] = array[j]
		array[j] = temp


func _ready() -> void:
	_build_ui()
	if not layout_data.is_empty():
		_build_cards()


func setup_game(seed_data: Dictionary, _context: Dictionary = {}, new_texts: Dictionary = {}) -> void:
	var new_layout: Array = seed_data.get("layout", [])
	setup(new_layout, new_texts)


func setup(new_layout: Array, new_texts: Dictionary = {}) -> void:
	layout_data = new_layout.duplicate()
	texts = new_texts.duplicate(true)
	if is_inside_tree():
		_build_cards()


func set_texts(new_texts: Dictionary) -> void:
	texts = new_texts.duplicate(true)
	_refresh_texts()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 20.0
	root.offset_top = 12.0
	root.offset_right = -20.0
	root.offset_bottom = -12.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(grid)
	_refresh_texts()


func _build_cards() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	card_buttons.clear()
	matched.clear()
	selected.clear()
	locked = false
	matched_pairs = 0

	for i in range(layout_data.size()):
		var button := _make_card_button(i)
		button.pressed.connect(_on_card_pressed.bind(i))
		grid.add_child(button)
		card_buttons.append(button)
		matched.append(false)


func _on_card_pressed(index: int) -> void:
	if locked or matched[index] or selected.has(index):
		return

	_set_card_visual(index, true)
	selected.append(index)

	if selected.size() == 2:
		locked = true
		_check_pair()


func _check_pair() -> void:
	var first: int = int(selected[0])
	var second: int = int(selected[1])
	if layout_data[first] == layout_data[second]:
		matched[first] = true
		matched[second] = true
		card_buttons[first].disabled = true
		card_buttons[second].disabled = true
		matched_pairs += 1
		selected.clear()
		locked = false
		if matched_pairs >= 4:
			await get_tree().create_timer(0.4).timeout
			game_won.emit()
	else:
		await get_tree().create_timer(0.75).timeout
		if is_instance_valid(card_buttons[first]):
			_set_card_visual(first, false)
		if is_instance_valid(card_buttons[second]):
			_set_card_visual(second, false)
		await get_tree().create_timer(0.2).timeout
		game_lost.emit("card_mismatch")


func _make_card_button(index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(130, 82)
	button.clip_contents = true

	var asset_texture := TextureRect.new()
	asset_texture.name = "AssetTexture"
	asset_texture.anchor_left = 0.08
	asset_texture.anchor_top = 0.10
	asset_texture.anchor_right = 0.92
	asset_texture.anchor_bottom = 0.90
	asset_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	asset_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	asset_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(asset_texture)

	_set_card_button_visual(button, str(layout_data[index]), false)
	return button


func _set_card_visual(index: int, face_up: bool) -> void:
	if index < 0 or index >= card_buttons.size():
		return
	_set_card_button_visual(card_buttons[index], str(layout_data[index]), face_up)


func _set_card_button_visual(button: Button, face_value: String, face_up: bool) -> void:
	var asset_texture: TextureRect = button.get_node("AssetTexture") as TextureRect
	var texture: Texture2D
	if face_up:
		texture = _load_texture(str(CARD_FACE_ASSETS.get(face_value, "")))
	else:
		texture = _load_texture("card_back.png")
	asset_texture.texture = texture


func _refresh_texts() -> void:
	for i in range(card_buttons.size()):
		var face_up: bool = matched[i] or selected.has(i)
		_set_card_visual(i, face_up)


func _txt(key: String) -> String:
	return str(texts.get(key, key))


func _load_texture(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	var path: String = "%s/%s" % [ASSET_DIR, file_name]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
