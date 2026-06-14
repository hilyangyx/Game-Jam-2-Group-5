extends Panel

signal restart_pressed

const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const LocalizationLoader = preload("res://UI/LocalizationLoader.gd")

@onready var content: VBoxContainer = $Content
@onready var ending_label: Label = $Content/EndingLabel
@onready var restart_button: Button = $Content/RestartButton

var texts: Dictionary = {}
var content_base_offsets := Vector4.ZERO
var content_base_separation := 0
var restart_button_base_minimum_size := Vector2.ZERO


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	if texts.is_empty():
		texts = LocalizationLoader.load_default()
	_capture_layout_baseline()
	_apply_style()
	apply_responsive_layout()
	get_viewport().size_changed.connect(apply_responsive_layout)
	_refresh_texts()


func apply_responsive_layout() -> void:
	ResponsiveScale.set_scaled_offsets(content, content_base_offsets)
	content.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, content_base_separation))))
	ending_label.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 16))
	restart_button.custom_minimum_size = ResponsiveScale.size(self, restart_button_base_minimum_size)
	restart_button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 22))
	_apply_style()


func _capture_layout_baseline() -> void:
	content_base_offsets = ResponsiveScale.offsets(content)
	content_base_separation = content.get_theme_constant("separation")
	restart_button_base_minimum_size = restart_button.custom_minimum_size


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


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.023, 0.028, 0.98)
	style.border_color = Color(0.74, 0.08, 0.06, 1.0)
	style.set_border_width_all(maxi(1, roundi(ResponsiveScale.length(self, 2))))
	var radius := maxi(1, roundi(ResponsiveScale.length(self, 6)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	add_theme_stylebox_override("panel", style)
