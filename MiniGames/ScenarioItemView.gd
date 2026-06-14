extends Control

signal item_pressed

const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const TextureLoader = preload("res://UI/TextureLoader.gd")
const LocalizationLoader = preload("res://UI/LocalizationLoader.gd")
const ASSET_DIR := "res://Assets/Objects"
const SCENARIO_DATA := {
	"card_flip": {
		"title_key": "scenario_item.card_flip",
		"asset": "obj_card_flip.png",
		"size": Vector2(640, 320)
	},
	"hungry_croc": {
		"title_key": "scenario_item.hungry_croc",
		"asset": "obj_hungry_croc.png",
		"size": Vector2(170, 170)
	},
	"war": {
		"title_key": "scenario_item.war",
		"asset": "obj_war.png",
		"size": Vector2(80, 80)
	}
}

@onready var content: Control = $Content
@onready var title_label: Label = $Content/TitleLabel
@onready var item_button: TextureButton = $Content/ItemButton

var scenario_id := "card_flip"
var texts: Dictionary = {}
var title_label_base_offsets := Vector4.ZERO
var item_button_base_center := Vector2.ZERO


func _ready() -> void:
	item_button.pressed.connect(_on_item_pressed)
	if texts.is_empty():
		texts = LocalizationLoader.load_default()
	_capture_layout_baseline()
	apply_responsive_layout()
	get_viewport().size_changed.connect(apply_responsive_layout)
	_refresh_view()


func apply_responsive_layout() -> void:
	ResponsiveScale.set_scaled_offsets(title_label, title_label_base_offsets)
	title_label.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 24))
	_refresh_item_size()


func _capture_layout_baseline() -> void:
	title_label_base_offsets = ResponsiveScale.offsets(title_label)
	var item_offsets := ResponsiveScale.offsets(item_button)
	item_button_base_center = Vector2(
		(item_offsets.x + item_offsets.z) * 0.5,
		(item_offsets.y + item_offsets.w) * 0.5
	)


func setup(new_scenario_id: String, new_texts: Dictionary) -> void:
	scenario_id = new_scenario_id
	texts = new_texts.duplicate(true)
	if is_inside_tree():
		_refresh_view()


func set_texts(new_texts: Dictionary) -> void:
	texts = new_texts.duplicate(true)
	if is_inside_tree():
		_refresh_view()


func _refresh_view() -> void:
	var scenario_data: Dictionary = SCENARIO_DATA.get(scenario_id, SCENARIO_DATA["card_flip"])
	title_label.text = _txt(str(scenario_data["title_key"]))
	var texture: Texture2D = TextureLoader.load_from_dir(ASSET_DIR, str(scenario_data["asset"]))
	item_button.texture_normal = texture
	item_button.texture_hover = texture
	item_button.texture_pressed = texture
	item_button.texture_focused = texture
	_refresh_item_size()


func _refresh_item_size() -> void:
	if item_button == null:
		return
	var scenario_data: Dictionary = SCENARIO_DATA.get(scenario_id, SCENARIO_DATA["card_flip"])
	var scaled_size := ResponsiveScale.size(self, scenario_data["size"] as Vector2)
	var scaled_center := item_button_base_center * ResponsiveScale.factor(self)
	item_button.custom_minimum_size = scaled_size
	item_button.offset_left = scaled_center.x - scaled_size.x * 0.5
	item_button.offset_top = scaled_center.y - scaled_size.y * 0.5
	item_button.offset_right = scaled_center.x + scaled_size.x * 0.5
	item_button.offset_bottom = scaled_center.y + scaled_size.y * 0.5


func _on_item_pressed() -> void:
	item_pressed.emit()


func _txt(key: String) -> String:
	return str(texts.get(key, key))
