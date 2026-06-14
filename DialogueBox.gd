extends Panel

signal dialogue_finished
signal line_started(line_data)

@onready var speaker_label: Label = $SpeakerLabel
@onready var state_label: Label = $StateLabel
@onready var line_label: Label = $LineLabel
@onready var continue_button: Button = $ContinueButton

var lines: Array = []
var current_index := 0
var active := false


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	visible = false


func play_lines(new_lines: Array) -> void:
	lines = new_lines.duplicate(true)
	current_index = 0
	active = not lines.is_empty()
	visible = active
	if active:
		_show_current_line()
	else:
		dialogue_finished.emit()


func _show_current_line() -> void:
	var line_data: Dictionary = lines[current_index]
	speaker_label.text = str(line_data.get("speaker", ""))
	state_label.text = str(line_data.get("state_text", line_data.get("state", "")))
	line_label.text = str(line_data.get("text", ""))
	line_started.emit(line_data)


func refresh_current_line() -> void:
	if active and current_index < lines.size():
		_show_current_line()


func set_continue_text(new_text: String) -> void:
	continue_button.text = new_text


func _on_continue_pressed() -> void:
	if not active:
		return
	current_index += 1
	if current_index >= lines.size():
		active = false
		visible = false
		dialogue_finished.emit()
	else:
		_show_current_line()
