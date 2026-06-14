extends Panel

signal restart_pressed

const LOCALIZATION_PATH := "res://Localization/en.json"

@onready var ending_label: Label = $Content/EndingLabel
@onready var restart_button: Button = $Content/RestartButton

var texts: Dictionary = {}


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	if texts.is_empty():
		texts = _load_default_texts()
	_apply_style()
	_refresh_texts()


func set_texts(new_texts: Dictionary) -> void:
	texts = new_texts.duplicate(true)
	if is_inside_tree():
		_refresh_texts()


func _refresh_texts() -> void:
	ending_label.text = _txt("ending.text")
	restart_button.text = _txt("ui.restart")


func _on_restart_pressed() -> void:
	restart_pressed.emit()


func _txt(key: String) -> String:
	return str(texts.get(key, key))


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


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.023, 0.028, 0.98)
	style.border_color = Color(0.74, 0.08, 0.06, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)
