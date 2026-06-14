extends Panel

signal begin_pressed

const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const LocalizationLoader = preload("res://UI/LocalizationLoader.gd")

@onready var content: VBoxContainer = $Content
@onready var title_label: Label = $Content/TitleLabel
@onready var begin_button: Button = $Content/BeginButton

var texts: Dictionary = {}
var content_base_offsets := Vector4.ZERO
var content_base_separation := 0
var begin_button_base_minimum_size := Vector2.ZERO


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)
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
	title_label.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 32))
	begin_button.custom_minimum_size = ResponsiveScale.size(self, begin_button_base_minimum_size)
	begin_button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 22))
	_apply_style()


func _capture_layout_baseline() -> void:
	content_base_offsets = ResponsiveScale.offsets(content)
	content_base_separation = content.get_theme_constant("separation")
	begin_button_base_minimum_size = begin_button.custom_minimum_size


func set_texts(new_texts: Dictionary) -> void:
	texts = new_texts.duplicate(true)
	if is_inside_tree():
		_refresh_texts()


func _refresh_texts() -> void:
	title_label.text = _txt("title.name")
	begin_button.text = _txt("ui.start")


func _on_begin_pressed() -> void:
	begin_pressed.emit()


func _txt(key: String) -> String:
	return str(texts.get(key, key))


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.025, 0.03, 0.98)
	style.border_color = Color(0.64, 0.06, 0.05, 1.0)
	style.set_border_width_all(maxi(1, roundi(ResponsiveScale.length(self, 2))))
	var radius := maxi(1, roundi(ResponsiveScale.length(self, 6)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	add_theme_stylebox_override("panel", style)
