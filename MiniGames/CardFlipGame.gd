extends Control

signal game_won
signal game_lost(reason)

const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const TextureLoader = preload("res://UI/TextureLoader.gd")
const ASSET_DIR := "res://Assets/Cards"
const CARD_BUTTON_BASE_SIZE := Vector2(130, 82)
const CARD_BACK_ASSET := "card_back.png"
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

@onready var root: CenterContainer = $CardGridRoot
@onready var grid: GridContainer = $CardGridRoot/CardGrid

var root_base_offsets := Vector4.ZERO
var grid_base_h_separation := 0
var grid_base_v_separation := 0


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
	_capture_layout_baseline()
	apply_responsive_layout()
	get_viewport().size_changed.connect(apply_responsive_layout)
	_setup_debug_run_if_needed()
	if not layout_data.is_empty():
		_build_cards()


func setup_game(seed_data: Dictionary, _context: Dictionary = {}, _new_texts: Dictionary = {}) -> void:
	var new_layout: Array = seed_data.get("layout", [])
	setup(new_layout)


func setup(new_layout: Array) -> void:
	layout_data = new_layout.duplicate()
	if is_inside_tree():
		_build_cards()


func _setup_debug_run_if_needed() -> void:
	if get_tree().current_scene != self or not layout_data.is_empty():
		return
	var debug_rng := RandomNumberGenerator.new()
	debug_rng.randomize()
	var seed_data := make_seed_data(debug_rng)
	layout_data = (seed_data["layout"] as Array).duplicate()


func apply_responsive_layout() -> void:
	if root == null or grid == null:
		return
	ResponsiveScale.set_scaled_offsets(root, root_base_offsets)
	grid.add_theme_constant_override("h_separation", maxi(1, roundi(ResponsiveScale.length(self, grid_base_h_separation))))
	grid.add_theme_constant_override("v_separation", maxi(1, roundi(ResponsiveScale.length(self, grid_base_v_separation))))
	for button in card_buttons:
		button.custom_minimum_size = ResponsiveScale.size(self, CARD_BUTTON_BASE_SIZE)


func _capture_layout_baseline() -> void:
	root_base_offsets = ResponsiveScale.offsets(root)
	grid_base_h_separation = grid.get_theme_constant("h_separation")
	grid_base_v_separation = grid.get_theme_constant("v_separation")


func _build_cards() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
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
	button.custom_minimum_size = ResponsiveScale.size(self, CARD_BUTTON_BASE_SIZE)
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
		texture = TextureLoader.load_from_dir(ASSET_DIR, str(CARD_FACE_ASSETS.get(face_value, "")))
	else:
		texture = TextureLoader.load_from_dir(ASSET_DIR, CARD_BACK_ASSET)
	asset_texture.texture = texture
