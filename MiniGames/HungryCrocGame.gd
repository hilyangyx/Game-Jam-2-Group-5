extends Control

signal game_won
signal game_lost(reason)

const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const TextureLoader = preload("res://UI/TextureLoader.gd")
const ASSET_DIR := "res://Assets/Croc"
const TOOTH_BUTTON_BASE_SIZE := Vector2(50, 70)
const TOOTH_IDLE_ASSET := "tooth_idle.png"
const TOOTH_SAFE_ASSET := "tooth_safe.png"
const TOOTH_LETHAL_ASSET := "tooth_lethal.png"

var safe_tooth_index := 0
var locked := false
var teeth: Array[Button] = []
@onready var root: VBoxContainer = $Root
@onready var mouth_panel: Control = $Root/MouthPanel
@onready var mouth_art: TextureRect = $Root/MouthPanel/MouthArt
@onready var tooth_row: HBoxContainer = $Root/MouthPanel/ToothRow

var root_base_offsets := Vector4.ZERO
var root_base_separation := 0
var mouth_panel_base_minimum_size := Vector2.ZERO
var mouth_art_base_offsets := Vector4.ZERO
var tooth_row_base_offsets := Vector4.ZERO
var tooth_row_base_separation := 0


static func make_seed_data(rng: RandomNumberGenerator) -> Dictionary:
	return {"safe_tooth_index": rng.randi_range(0, 7)}


func _ready() -> void:
	_capture_layout_baseline()
	_build_teeth()
	apply_responsive_layout()
	get_viewport().size_changed.connect(apply_responsive_layout)


func setup_game(seed_data: Dictionary, _context: Dictionary = {}, _new_texts: Dictionary = {}) -> void:
	setup(int(seed_data.get("safe_tooth_index", 0)))


func setup(new_safe_tooth_index: int) -> void:
	safe_tooth_index = new_safe_tooth_index


func _build_teeth() -> void:
	for child in tooth_row.get_children():
		tooth_row.remove_child(child)
		child.queue_free()
	teeth.clear()
	for i in range(8):
		var button := _make_tooth_button(i)
		button.pressed.connect(_on_tooth_pressed.bind(i))
		tooth_row.add_child(button)
		teeth.append(button)


func apply_responsive_layout() -> void:
	if root == null or mouth_panel == null or tooth_row == null:
		return
	ResponsiveScale.set_scaled_offsets(root, root_base_offsets)
	root.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, root_base_separation))))
	mouth_panel.custom_minimum_size = ResponsiveScale.size(self, mouth_panel_base_minimum_size)
	ResponsiveScale.set_scaled_offsets(mouth_art, mouth_art_base_offsets)
	ResponsiveScale.set_scaled_offsets(tooth_row, tooth_row_base_offsets)
	tooth_row.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, tooth_row_base_separation))))
	for tooth in teeth:
		tooth.custom_minimum_size = ResponsiveScale.size(self, TOOTH_BUTTON_BASE_SIZE)


func _capture_layout_baseline() -> void:
	root_base_offsets = ResponsiveScale.offsets(root)
	root_base_separation = root.get_theme_constant("separation")
	mouth_panel_base_minimum_size = mouth_panel.custom_minimum_size
	mouth_art_base_offsets = ResponsiveScale.offsets(mouth_art)
	tooth_row_base_offsets = ResponsiveScale.offsets(tooth_row)
	tooth_row_base_separation = tooth_row.get_theme_constant("separation")


func _on_tooth_pressed(index: int) -> void:
	if locked:
		return
	locked = true
	for tooth in teeth:
		tooth.disabled = true
	if index == safe_tooth_index:
		_set_tooth_visual(index, TOOTH_SAFE_ASSET)
		await get_tree().create_timer(0.45).timeout
		game_won.emit()
	else:
		_set_tooth_visual(index, TOOTH_LETHAL_ASSET)
		await get_tree().create_timer(0.45).timeout
		game_lost.emit("croc_tooth")


func _make_tooth_button(_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = ResponsiveScale.size(self, TOOTH_BUTTON_BASE_SIZE)
	button.clip_contents = true

	var asset_texture := TextureRect.new()
	asset_texture.name = "AssetTexture"
	asset_texture.anchor_right = 1.0
	asset_texture.anchor_bottom = 1.0
	asset_texture.texture = TextureLoader.load_from_dir(ASSET_DIR, TOOTH_IDLE_ASSET)
	asset_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	asset_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	asset_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(asset_texture)

	return button


func _set_tooth_visual(index: int, asset_name: String) -> void:
	if index < 0 or index >= teeth.size():
		return
	var asset_texture: TextureRect = teeth[index].get_node("AssetTexture") as TextureRect
	var texture: Texture2D = TextureLoader.load_from_dir(ASSET_DIR, asset_name)
	asset_texture.texture = texture
