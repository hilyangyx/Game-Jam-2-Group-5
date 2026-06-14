extends Control

const CARD_FLIP_SCENE = preload("res://MiniGames/CardFlipGame.tscn")
const HUNGRY_CROC_SCENE = preload("res://MiniGames/HungryCrocGame.tscn")
const WAR_SCENE = preload("res://MiniGames/WarGame.tscn")
const CARD_FLIP_SCRIPT = preload("res://MiniGames/CardFlipGame.gd")
const HUNGRY_CROC_SCRIPT = preload("res://MiniGames/HungryCrocGame.gd")
const WAR_SCRIPT = preload("res://MiniGames/WarGame.gd")
const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const TextureLoader = preload("res://UI/TextureLoader.gd")
const LocalizationLoader = preload("res://UI/LocalizationLoader.gd")
const LOCALIZATION_DIR := "res://Localization"
const ASSET_DIR := "res://Assets"
const SCENARIOS: Array[String] = ["card_flip", "hungry_croc", "war"]
const LANGUAGES: Array[String] = ["en", "ja", "zh"]
const DEFAULT_LANGUAGE := "en"
const LANGUAGE_BUTTON_BASE_SIZE := Vector2(58, 34)
const BACKGROUND_ASSET := "casino_office_base.png"
const PINBOARD_LABEL_BASE_FONT_SIZE := 14
const DEALER_ASSETS := {
	"idle": "Dealer/dealer_idle.png",
	"smirk": "Dealer/dealer_smirk.png",
	"suspicious": "Dealer/dealer_suspicious.png",
	"shocked": "Dealer/dealer_shocked.png",
	"composed": "Dealer/dealer_composed.png",
	"laughing": "Dealer/dealer_laughing.png"
}

enum GameState {
	TITLE,
	OPENING_DIALOGUE,
	LOOP_START,
	SCENARIO_INTRO,
	WAITING_FOR_ITEM_CLICK,
	MINI_GAME_ACTIVE,
	DEATH_DIALOGUE,
	DEATH_TRANSITION,
	FINAL_DIALOGUE,
	FINAL_SHOOT,
	END_SCREEN
}

@onready var background: TextureRect = $Background
@onready var dealer: TextureRect = $Dealer
@onready var table_panel: Panel = $TablePanel
@onready var mini_game_container: Control = $TablePanel/MiniGameContainer
@onready var scenario_item_view: Control = $ScenarioItemView
@onready var dialogue_box = $DialogueBox
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var title_screen: Panel = $TitleScreen
@onready var final_shoot_screen: Panel = $FinalShootScreen
@onready var end_screen: Panel = $EndScreen
@onready var language_panel: Panel = $LanguagePanel
@onready var language_row: HBoxContainer = $LanguagePanel/LanguageRow
@onready var language_label: Label = $LanguagePanel/LanguageRow/LanguageLabel
@onready var fullscreen_mini_game_container: Control = $FullscreenMiniGameContainer
@onready var developer_button: Button = $DeveloperButton
@onready var pinboard: Control = $Pinboard
@onready var pinboard_label: Label = $Pinboard/LoopCountLabel

var state: GameState = GameState.TITLE
var rng := RandomNumberGenerator.new()
var language_buttons: Array[Button] = []
var loop_count := 0
var has_failed_this_run := false
var scenario_order: Array = []
var current_scenario_index := 0
var completed_scenarios_this_loop: Array = []
var mini_game_seed_data: Dictionary = {}
var has_seen_war_round_3 := false
var correct_dialogue_counter := 0
var death_dialogue_counter := 0
var current_language := DEFAULT_LANGUAGE
var translations: Dictionary = {}
var current_dealer_state := "idle"
var current_mini_game: Node
var language_panel_base_offsets := Vector4.ZERO
var language_row_base_offsets := Vector4.ZERO
var mini_game_container_base_offsets := Vector4.ZERO
var developer_button_base_offsets := Vector4.ZERO
var title_screen_base_offsets := Vector4.ZERO
var final_shoot_screen_base_offsets := Vector4.ZERO
var end_screen_base_offsets := Vector4.ZERO
var language_label_base_minimum_size := Vector2.ZERO
var developer_button_base_minimum_size := Vector2.ZERO
var language_row_base_separation := 0
var pinboard_base_background_rect := Rect2()
var pinboard_base_rect := Rect2()
var pinboard_background_ratio_rect := Rect2()


func _ready() -> void:
	rng.randomize()
	_load_translations()
	_capture_layout_baseline()
	_apply_visual_style()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_connect_screen_signals()
	_build_language_selector()
	dialogue_box.line_started.connect(_on_dialogue_line_started)
	dialogue_box.set_continue_text(_t("ui.continue"))
	developer_button.pressed.connect(_on_developer_skip_pressed)
	transition_overlay.visible = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_title()
	_set_dealer_state("idle")


func _connect_screen_signals() -> void:
	title_screen.begin_pressed.connect(_on_begin_pressed)
	scenario_item_view.item_pressed.connect(_on_scenario_item_pressed)
	final_shoot_screen.shoot_pressed.connect(_on_shoot_pressed)
	end_screen.restart_pressed.connect(_on_restart_pressed)


func _apply_visual_style() -> void:
	background.texture = TextureLoader.load_from_dir(ASSET_DIR, BACKGROUND_ASSET)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dealer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dealer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dealer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_panel_style(table_panel, Color(0.035, 0.18, 0.11, 0.98), Color(0.33, 0.17, 0.06, 1.0), maxi(1, roundi(ResponsiveScale.length(self, 3))))
	_set_panel_style(dialogue_box, Color(0.025, 0.023, 0.028, 0.98), Color(0.6, 0.45, 0.18, 1.0), maxi(1, roundi(ResponsiveScale.length(self, 2))))


func _apply_responsive_layout() -> void:
	if developer_button == null or language_row == null or mini_game_container == null:
		return
	_apply_visual_style()
	_apply_pinboard_layout()
	_resize_language_panel()
	ResponsiveScale.set_scaled_offsets(language_row, language_row_base_offsets)
	ResponsiveScale.set_scaled_offsets(mini_game_container, mini_game_container_base_offsets)
	ResponsiveScale.set_scaled_offsets(title_screen, title_screen_base_offsets)
	ResponsiveScale.set_scaled_offsets(final_shoot_screen, final_shoot_screen_base_offsets)
	ResponsiveScale.set_scaled_offsets(end_screen, end_screen_base_offsets)
	if fullscreen_mini_game_container != null:
		fullscreen_mini_game_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		ResponsiveScale.set_scaled_offsets(fullscreen_mini_game_container, Vector4.ZERO)
	developer_button.custom_minimum_size = ResponsiveScale.size(self, developer_button_base_minimum_size)
	developer_button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 14))
	ResponsiveScale.set_scaled_offsets(developer_button, developer_button_base_offsets)
	if dialogue_box.has_method("apply_responsive_layout"):
		dialogue_box.call("apply_responsive_layout")


func _set_panel_style(panel: Control, fill: Color, border: Color, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	var radius := maxi(1, roundi(ResponsiveScale.length(panel, 6)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	panel.add_theme_stylebox_override("panel", style)


func _capture_layout_baseline() -> void:
	language_panel_base_offsets = ResponsiveScale.offsets(language_panel)
	language_row_base_offsets = ResponsiveScale.offsets(language_row)
	mini_game_container_base_offsets = ResponsiveScale.offsets(mini_game_container)
	developer_button_base_offsets = ResponsiveScale.offsets(developer_button)
	title_screen_base_offsets = ResponsiveScale.offsets(title_screen)
	final_shoot_screen_base_offsets = ResponsiveScale.offsets(final_shoot_screen)
	end_screen_base_offsets = ResponsiveScale.offsets(end_screen)
	language_label_base_minimum_size = language_label.custom_minimum_size
	developer_button_base_minimum_size = developer_button.custom_minimum_size
	language_row_base_separation = language_row.get_theme_constant("separation")
	_capture_pinboard_baseline()


func _capture_pinboard_baseline() -> void:
	pinboard_base_background_rect = _background_content_rect()
	pinboard_base_rect = Rect2(pinboard.position, pinboard.size)
	if pinboard_base_background_rect.size.x <= 0.0 or pinboard_base_background_rect.size.y <= 0.0:
		pinboard_background_ratio_rect = Rect2()
		return
	pinboard_background_ratio_rect = Rect2(
		Vector2(
			(pinboard_base_rect.position.x - pinboard_base_background_rect.position.x) / pinboard_base_background_rect.size.x,
			(pinboard_base_rect.position.y - pinboard_base_background_rect.position.y) / pinboard_base_background_rect.size.y
		),
		Vector2(
			pinboard_base_rect.size.x / pinboard_base_background_rect.size.x,
			pinboard_base_rect.size.y / pinboard_base_background_rect.size.y
		)
	)


func _background_content_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var texture := background.texture
	if texture == null:
		return Rect2(Vector2.ZERO, viewport_size)
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var scale := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	var content_size := texture_size * scale
	return Rect2((viewport_size - content_size) * 0.5, content_size)


func _apply_pinboard_layout() -> void:
	if pinboard == null or pinboard_label == null:
		return
	var background_rect := _background_content_rect()
	var pinboard_rect := Rect2(
		background_rect.position + pinboard_background_ratio_rect.position * background_rect.size,
		pinboard_background_ratio_rect.size * background_rect.size
	)
	pinboard.anchor_left = 0.0
	pinboard.anchor_top = 0.0
	pinboard.anchor_right = 0.0
	pinboard.anchor_bottom = 0.0
	pinboard.offset_left = pinboard_rect.position.x
	pinboard.offset_top = pinboard_rect.position.y
	pinboard.offset_right = pinboard_rect.position.x + pinboard_rect.size.x
	pinboard.offset_bottom = pinboard_rect.position.y + pinboard_rect.size.y
	pinboard_label.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, PINBOARD_LABEL_BASE_FONT_SIZE))


func _refresh_pinboard() -> void:
	if pinboard == null or pinboard_label == null:
		return
	pinboard.visible = has_failed_this_run and loop_count > 1
	pinboard_label.text = "%d" % (loop_count - 1)
	_apply_pinboard_layout()


func _hide_pinboard() -> void:
	if pinboard != null:
		pinboard.visible = false


func _load_translations() -> void:
	translations.clear()
	for language_code in LANGUAGES:
		translations[language_code] = LocalizationLoader.load_language(LOCALIZATION_DIR, language_code)


func _t(key: String, values: Array = []) -> String:
	var text := key
	var language_data: Dictionary = translations.get(current_language, {})
	var fallback_data: Dictionary = translations.get(DEFAULT_LANGUAGE, {})
	if language_data.has(key):
		text = str(language_data[key])
	elif fallback_data.has(key):
		text = str(fallback_data[key])
	if not values.is_empty():
		text = text % values
	return text


func _language_texts() -> Dictionary:
	return translations.get(current_language, {})


func _build_language_selector() -> void:
	_set_panel_style(language_panel, Color(0.045, 0.043, 0.05, 0.94), Color(0.55, 0.42, 0.16, 1.0), maxi(1, roundi(ResponsiveScale.length(self, 1))))
	language_row.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, language_row_base_separation))))
	language_label.custom_minimum_size = ResponsiveScale.size(self, language_label_base_minimum_size)
	language_label.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 14))
	language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	for child in language_row.get_children():
		if child != language_label:
			language_row.remove_child(child)
			child.queue_free()
	language_buttons.clear()
	for language_code in LANGUAGES:
		var button := Button.new()
		button.custom_minimum_size = ResponsiveScale.size(self, LANGUAGE_BUTTON_BASE_SIZE)
		button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 14))
		button.pressed.connect(_on_language_button_pressed.bind(language_code))
		language_row.add_child(button)
		language_buttons.append(button)
	_refresh_language_selector()


func _refresh_language_selector() -> void:
	if language_label != null:
		language_label.text = _t("ui.language")
	for i in range(language_buttons.size()):
		var language_code: String = LANGUAGES[i]
		language_buttons[i].text = _t("language.%s" % language_code)
		language_buttons[i].disabled = language_code == current_language
	developer_button.text = _t("ui.dev_skip")
	_resize_language_panel()


func _resize_language_panel() -> void:
	if language_panel == null or language_row == null or language_label == null:
		return
	var scale := ResponsiveScale.factor(self)
	var margin := -language_panel_base_offsets.z * scale
	var panel_height := (language_panel_base_offsets.w - language_panel_base_offsets.y) * scale
	var padding_x := language_row_base_offsets.x * scale
	var label_width := language_label_base_minimum_size.x * scale
	var row_separation := float(language_row_base_separation) * scale
	_set_panel_style(language_panel, Color(0.045, 0.043, 0.05, 0.94), Color(0.55, 0.42, 0.16, 1.0), maxi(1, roundi(ResponsiveScale.length(self, 1))))
	language_row.add_theme_constant_override("separation", maxi(1, roundi(row_separation)))
	language_label.custom_minimum_size = Vector2(label_width, 0)
	language_label.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 14))
	var button_width_total := 0.0
	for i in range(language_buttons.size()):
		var button := language_buttons[i]
		var button_size := LANGUAGE_BUTTON_BASE_SIZE * scale
		button_width_total += button_size.x
		button.custom_minimum_size = button_size
		button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 14))
	var button_count: int = language_buttons.size()
	var visible_child_count: int = button_count + 1
	var separation_total: float = float(maxi(0, visible_child_count - 1)) * row_separation
	var panel_width: float = (padding_x * 2.0) + label_width + button_width_total + separation_total
	language_panel.anchor_left = 1.0
	language_panel.anchor_right = 1.0
	language_panel.anchor_top = 0.0
	language_panel.anchor_bottom = 0.0
	language_panel.offset_left = -margin - panel_width
	language_panel.offset_right = -margin
	language_panel.offset_top = margin
	language_panel.offset_bottom = margin + panel_height


func _on_language_button_pressed(language_code: String) -> void:
	if current_language == language_code:
		return
	current_language = language_code
	dialogue_box.set_continue_text(_t("ui.continue"))
	_refresh_language_selector()
	_refresh_dialogue_language()
	_set_dealer_state(current_dealer_state)
	_refresh_current_view_language()


func _refresh_dialogue_language() -> void:
	if not dialogue_box.active:
		return
	for i in range(dialogue_box.lines.size()):
		var line_data: Dictionary = dialogue_box.lines[i]
		if line_data.has("speaker_key"):
			line_data["speaker"] = _t(str(line_data["speaker_key"]))
		if line_data.has("text_key"):
			line_data["text"] = _t(str(line_data["text_key"]))
		var state_key: String = str(line_data.get("state", "idle"))
		line_data["state_text"] = _t("dealer_state.%s" % state_key)
		dialogue_box.lines[i] = line_data
	dialogue_box.refresh_current_line()


func _refresh_current_view_language() -> void:
	match state:
		GameState.TITLE:
			title_screen.call("set_texts", _language_texts())
		GameState.WAITING_FOR_ITEM_CLICK:
			scenario_item_view.call("setup", _current_scenario(), _language_texts())
		GameState.MINI_GAME_ACTIVE:
			if current_mini_game != null and is_instance_valid(current_mini_game) and current_mini_game.has_method("set_texts"):
				current_mini_game.call("set_texts", _language_texts())
		GameState.FINAL_SHOOT:
			final_shoot_screen.call("set_texts", _language_texts())
		GameState.END_SCREEN:
			end_screen.call("set_texts", _language_texts())


func _show_title() -> void:
	state = GameState.TITLE
	_hide_game_surfaces()
	_clear_mini_game_containers()
	_hide_pinboard()
	title_screen.visible = true
	title_screen.call("set_texts", _language_texts())
	dialogue_box.visible = false
	_set_dealer_state("idle")


func _on_begin_pressed() -> void:
	_start_new_run()


func _start_new_run() -> void:
	dealer.visible = true
	state = GameState.OPENING_DIALOGUE
	_hide_game_surfaces()
	_clear_mini_game_containers()

	_generate_seed_data()
	loop_count = 0
	has_failed_this_run = false
	_refresh_pinboard()
	current_scenario_index = 0
	completed_scenarios_this_loop.clear()
	scenario_order.clear()
	has_seen_war_round_3 = false
	correct_dialogue_counter = 0
	death_dialogue_counter = 0

	await _start_new_loop(true)


func _generate_seed_data() -> void:
	mini_game_seed_data = {
		"card_flip": CARD_FLIP_SCRIPT.make_seed_data(rng),
		"hungry_croc": HUNGRY_CROC_SCRIPT.make_seed_data(rng),
		"war": WAR_SCRIPT.make_seed_data(rng)
	}


func _start_new_loop(play_opening_dialogue: bool = false) -> void:
	state = GameState.LOOP_START
	loop_count += 1
	_refresh_pinboard()
	current_scenario_index = 0
	completed_scenarios_this_loop.clear()
	scenario_order = SCENARIOS.duplicate()
	_shuffle_array(scenario_order)
	_clear_mini_game_containers()
	_hide_game_surfaces()
	if play_opening_dialogue:
		state = GameState.OPENING_DIALOGUE
		await _play_dialogue(_opening_dialogue())
	await _begin_current_scenario()


func _begin_current_scenario() -> void:
	state = GameState.SCENARIO_INTRO
	_clear_mini_game_containers()
	_hide_game_surfaces()

	var scenario := _current_scenario()
	await _play_dialogue(_scenario_intro_dialogue(scenario))
	_show_scenario_item(scenario)


func _show_scenario_item(scenario: String) -> void:
	state = GameState.WAITING_FOR_ITEM_CLICK
	_hide_game_surfaces()
	scenario_item_view.visible = true
	scenario_item_view.call("setup", scenario, _language_texts())


func _on_scenario_item_pressed() -> void:
	if state != GameState.WAITING_FOR_ITEM_CLICK:
		return
	_start_current_mini_game()


func _start_current_mini_game() -> void:
	state = GameState.MINI_GAME_ACTIVE
	_clear_mini_game_containers()
	_hide_game_surfaces()
	table_panel.visible = true

	var scenario := _current_scenario()
	var game: Node = _create_mini_game(scenario)
	if game == null:
		return
	if scenario == "war":
		fullscreen_mini_game_container.visible = true
		fullscreen_mini_game_container.add_child(game)
	else:
		mini_game_container.visible = true
		mini_game_container.add_child(game)
	current_mini_game = game

	var seed_data: Dictionary = mini_game_seed_data.get(scenario, {})
	var context := {"has_seen_war_round_3": has_seen_war_round_3}
	game.call("setup_game", seed_data, context, _language_texts())
	if scenario == "war":
		game.connect("war_round_3_seen", Callable(self, "_on_war_round_3_seen"))
	game.connect("game_won", Callable(self, "_on_mini_game_won"))
	game.connect("game_lost", Callable(self, "_on_mini_game_lost"))


func _create_mini_game(scenario: String) -> Node:
	match scenario:
		"card_flip":
			return CARD_FLIP_SCENE.instantiate()
		"hungry_croc":
			return HUNGRY_CROC_SCENE.instantiate()
		"war":
			return WAR_SCENE.instantiate()
	return null


func _on_war_round_3_seen() -> void:
	has_seen_war_round_3 = true


func _on_mini_game_won() -> void:
	if state != GameState.MINI_GAME_ACTIVE:
		return
	await _complete_current_scenario(true)


func _complete_current_scenario(play_success_dialogue: bool) -> void:
	var scenario := _current_scenario()
	if not completed_scenarios_this_loop.has(scenario):
		completed_scenarios_this_loop.append(scenario)
	_clear_mini_game_containers()
	current_mini_game = null
	_hide_game_surfaces()
	if play_success_dialogue:
		await _play_dialogue([_correct_dialogue()])

	if completed_scenarios_this_loop.size() >= SCENARIOS.size():
		await _start_final_dialogue()
	else:
		current_scenario_index += 1
		await _begin_current_scenario()


func _on_mini_game_lost(_reason: String) -> void:
	if state != GameState.MINI_GAME_ACTIVE:
		return
	state = GameState.DEATH_DIALOGUE
	await _play_dialogue([_death_dialogue()])
	_clear_mini_game_containers()
	current_mini_game = null
	_hide_game_surfaces()
	await _death_transition()
	has_failed_this_run = true
	await _start_new_loop(true)


func _start_final_dialogue() -> void:
	state = GameState.FINAL_DIALOGUE
	_clear_mini_game_containers()
	_hide_game_surfaces()
	await _play_dialogue([
		_dialogue("shocked", "dialogue.final.1"),
		_dialogue("shocked", "dialogue.final.2"),
		_dialogue("suspicious", "dialogue.final.3"),
		_dialogue("suspicious", "dialogue.final.4")
	])
	await get_tree().create_timer(0.65).timeout
	await _play_dialogue([
		_dialogue("composed", "dialogue.final.5")
	])
	_show_final_shoot_panel()


func _show_final_shoot_panel() -> void:
	state = GameState.FINAL_SHOOT
	_hide_game_surfaces()
	final_shoot_screen.visible = true
	final_shoot_screen.call("set_texts", _language_texts())
	_set_dealer_state("composed")


func _on_shoot_pressed() -> void:
	if state != GameState.FINAL_SHOOT:
		return
	_show_ending_after_shot()


func _show_ending_after_shot() -> void:
	await _shoot_flash()
	_show_ending_screen()


func _show_ending_screen() -> void:
	dealer.visible = false
	state = GameState.END_SCREEN
	_hide_game_surfaces()
	end_screen.visible = true
	end_screen.call("set_texts", _language_texts())
	_set_dealer_state("composed")


func _on_restart_pressed() -> void:
	_start_new_run()


func _on_developer_skip_pressed() -> void:
	match state:
		GameState.TITLE:
			_start_new_run()
		GameState.WAITING_FOR_ITEM_CLICK, GameState.MINI_GAME_ACTIVE:
			await _complete_current_scenario(false)
		GameState.FINAL_SHOOT:
			_show_ending_screen()
		GameState.END_SCREEN:
			_show_title()


func _death_transition() -> void:
	state = GameState.DEATH_TRANSITION
	transition_overlay.visible = true
	transition_overlay.color = Color(1, 1, 1, 0)
	var flash := create_tween()
	flash.tween_property(transition_overlay, "color", Color(1, 1, 1, 1), 0.08)
	flash.tween_interval(0.12)
	flash.tween_property(transition_overlay, "color", Color(0, 0, 0, 1), 0.18)
	flash.tween_interval(0.35)
	flash.tween_property(transition_overlay, "color", Color(0, 0, 0, 0), 0.45)
	await flash.finished
	transition_overlay.visible = false


func _shoot_flash() -> void:
	transition_overlay.visible = true
	transition_overlay.color = Color(1, 1, 1, 0)
	var flash := create_tween()
	flash.tween_property(transition_overlay, "color", Color(1, 1, 1, 1), 0.08)
	flash.tween_interval(0.25)
	flash.tween_property(transition_overlay, "color", Color(1, 1, 1, 0), 0.45)
	await flash.finished
	transition_overlay.visible = false


func _play_dialogue(lines: Array) -> void:
	dialogue_box.play_lines(lines)
	await dialogue_box.dialogue_finished


func _dialogue(dealer_state: String, text_key: String) -> Dictionary:
	return {
		"speaker": _t("speaker.dealer"),
		"speaker_key": "speaker.dealer",
		"state": dealer_state,
		"state_text": _t("dealer_state.%s" % dealer_state),
		"text": _t(text_key),
		"text_key": text_key
	}


func _opening_dialogue() -> Array:
	return [
		_dialogue("idle", "dialogue.opening.1"),
		_dialogue("smirk", "dialogue.opening.2"),
		_dialogue("idle", "dialogue.opening.3")
	]


func _scenario_intro_dialogue(scenario: String) -> Array:
	match scenario:
		"card_flip":
			return [_dialogue("idle", "dialogue.intro.card_flip")]
		"hungry_croc":
			return [_dialogue("smirk", "dialogue.intro.hungry_croc")]
		"war":
			return [_dialogue("composed", "dialogue.intro.war")]
	return []


func _correct_dialogue() -> Dictionary:
	var early: Array = [
		_dialogue("composed", "dialogue.correct.early.1"),
		_dialogue("composed", "dialogue.correct.early.2")
	]
	var mid: Array = [
		_dialogue("suspicious", "dialogue.correct.mid.1"),
		_dialogue("suspicious", "dialogue.correct.mid.2")
	]
	var late: Array = [
		_dialogue("suspicious", "dialogue.correct.late.1"),
		_dialogue("suspicious", "dialogue.correct.late.2")
	]
	var pool: Array = early
	if loop_count >= 6:
		pool = late
	elif loop_count >= 3:
		pool = mid
	var result: Dictionary = pool[correct_dialogue_counter % pool.size()]
	correct_dialogue_counter += 1
	return result


func _death_dialogue() -> Dictionary:
	var early: Array = [
		_dialogue("idle", "dialogue.death.early.1"),
		_dialogue("dile", "dialogue.death.early.2"),
	]
	var mid: Array = [
		_dialogue("smirk", "dialogue.death.mid.1"),
		_dialogue("smirk", "dialogue.death.mid.2"),
	]
	var late: Array = [
		_dialogue("laughing", "dialogue.death.late.1"),
	]
	var pool: Array = early
	if loop_count >= 6:
		pool = late
	elif loop_count >= 3:
		pool = mid
	var result: Dictionary = pool[death_dialogue_counter % pool.size()]
	death_dialogue_counter += 1
	return result


func _on_dialogue_line_started(line_data: Dictionary) -> void:
	_set_dealer_state(str(line_data.get("state", "idle")))


func _set_dealer_state(dealer_state: String) -> void:
	current_dealer_state = dealer_state
	var dealer_asset_name: String = str(DEALER_ASSETS.get(dealer_state, DEALER_ASSETS["idle"]))
	var dealer_texture: Texture2D = TextureLoader.load_from_dir(ASSET_DIR, dealer_asset_name)
	if dealer_texture != null:
		dealer.texture = dealer_texture


func _current_scenario() -> String:
	if scenario_order.is_empty() or current_scenario_index >= scenario_order.size():
		return ""
	return scenario_order[current_scenario_index]


func _shuffle_array(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = array[i]
		array[i] = array[j]
		array[j] = temp


func _hide_game_surfaces() -> void:
	title_screen.visible = false
	scenario_item_view.visible = false
	table_panel.visible = false
	mini_game_container.visible = false
	if fullscreen_mini_game_container != null:
		fullscreen_mini_game_container.visible = false
	final_shoot_screen.visible = false
	end_screen.visible = false


func _clear_mini_game_containers() -> void:
	_clear_container(mini_game_container)
	if fullscreen_mini_game_container != null:
		_clear_container(fullscreen_mini_game_container)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
