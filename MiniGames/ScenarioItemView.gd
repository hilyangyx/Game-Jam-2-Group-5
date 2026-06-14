extends Control

signal item_pressed

const ASSET_DIR := "res://Assets/Objects"
const LOCALIZATION_PATH := "res://Localization/en.json"
const SCENARIO_DATA := {
	"card_flip": {
		"title_key": "scenario_item.card_flip",
		"asset": "obj_card_flip.png",
		"size": Vector2(360, 170)
	},
	"hungry_croc": {
		"title_key": "scenario_item.hungry_croc",
		"asset": "obj_hungry_croc.png",
		"size": Vector2(360, 170)
	},
	"war": {
		"title_key": "scenario_item.war",
		"asset": "obj_war.png",
		"size": Vector2(240, 160)
	}
}

@onready var title_label: Label = $Content/TitleLabel
@onready var item_button: TextureButton = $Content/ItemButton

var scenario_id := "card_flip"
var texts: Dictionary = {}


func _ready() -> void:
	item_button.pressed.connect(_on_item_pressed)
	if texts.is_empty():
		texts = _load_default_texts()
	_refresh_view()


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
	var texture: Texture2D = _load_texture(str(scenario_data["asset"]))
	item_button.texture_normal = texture
	item_button.texture_hover = texture
	item_button.texture_pressed = texture
	item_button.texture_focused = texture
	item_button.custom_minimum_size = scenario_data["size"] as Vector2


func _on_item_pressed() -> void:
	item_pressed.emit()


func _txt(key: String) -> String:
	return str(texts.get(key, key))


func _load_texture(file_name: String) -> Texture2D:
	var path: String = "%s/%s" % [ASSET_DIR, file_name]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


func _load_default_texts() -> Dictionary:
	if not FileAccess.file_exists(LOCALIZATION_PATH):
		return {}
	var file := FileAccess.open(LOCALIZATION_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
