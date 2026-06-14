extends Control

signal game_won
signal game_lost(reason)
signal war_round_3_seen

const ResponsiveScale = preload("res://UI/ResponsiveScale.gd")
const TextureLoader = preload("res://UI/TextureLoader.gd")
const ASSET_DIR := "res://Assets/Cards"
const OPTION_BUTTON_BASE_SIZE := Vector2(150, 48)
const CARD_VIEW_BASE_SIZE := Vector2(116, 88)
const CARD_BACK_ASSET := "card_back.png"
const DEBUG_TEXTS := {
	"war.option_higher": "Higher",
	"war.option_lower": "Lower",
	"war.option_equal": "Equal"
}

var rounds: Array = []
var has_seen_round_3_before := false
var emitted_round_3_seen := false
var current_round := 0
var locked := false
var texts: Dictionary = {}
var dealer_revealed := false

@onready var root: Control = $Root
@onready var card_area: VBoxContainer = $Root/CardArea
@onready var options_bar: CenterContainer = $Root/OptionsBar
@onready var player_hand_area: VBoxContainer = $Root/CardArea/PlayerHandArea
@onready var dealer_hand_area: VBoxContainer = $Root/CardArea/DealerHandArea
@onready var player_cards_box: HBoxContainer = $Root/CardArea/PlayerHandArea/CardsBox
@onready var dealer_cards_box: HBoxContainer = $Root/CardArea/DealerHandArea/CardsBox
@onready var options_box: HBoxContainer = $Root/OptionsBar/OptionsBox

var card_area_base_offsets := Vector4.ZERO
var options_bar_base_offsets := Vector4.ZERO
var card_area_base_separation := 0
var options_box_base_separation := 0
var root_base_offsets := Vector4.ZERO
var player_hand_base_minimum_size := Vector2.ZERO
var dealer_hand_base_minimum_size := Vector2.ZERO
var player_hand_base_separation := 0
var dealer_hand_base_separation := 0
var player_cards_base_separation := 0
var dealer_cards_base_separation := 0


static func make_seed_data(rng: RandomNumberGenerator) -> Dictionary:
	var new_rounds: Array = []
	for _round_index in range(2):
		var player_cards: Array = []
		var dealer_cards: Array = []
		while true:
			player_cards = [rng.randi_range(1, 13), rng.randi_range(1, 13)]
			dealer_cards = [rng.randi_range(1, 13), rng.randi_range(1, 13)]
			if _seed_total(player_cards) != _seed_total(dealer_cards):
				break
		new_rounds.append({"player": player_cards, "dealer": dealer_cards})

	var final_player: Array = [rng.randi_range(1, 13), rng.randi_range(1, 13)]
	var target_total: int = _seed_total(final_player)
	var min_first: int = maxi(1, target_total - 13)
	var max_first: int = mini(13, target_total - 1)
	var dealer_first: int = rng.randi_range(min_first, max_first)
	var final_dealer: Array = [dealer_first, target_total - dealer_first]
	new_rounds.append({"player": final_player, "dealer": final_dealer})
	return {"rounds": new_rounds}


static func _seed_total(cards: Array) -> int:
	var total := 0
	for card in cards:
		total += int(card)
	return total


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_layout_baseline()
	apply_responsive_layout()
	get_viewport().size_changed.connect(apply_responsive_layout)
	_setup_debug_run_if_needed()
	if not rounds.is_empty():
		_show_round()


func setup_game(seed_data: Dictionary, context: Dictionary = {}, new_texts: Dictionary = {}) -> void:
	var new_rounds: Array = seed_data.get("rounds", [])
	var new_has_seen_round_3_before: bool = bool(context.get("has_seen_war_round_3", false))
	setup(new_rounds, new_has_seen_round_3_before, new_texts)


func setup(new_rounds: Array, new_has_seen_round_3_before: bool, new_texts: Dictionary = {}) -> void:
	rounds = new_rounds.duplicate(true)
	has_seen_round_3_before = new_has_seen_round_3_before
	texts = new_texts.duplicate(true)
	current_round = 0
	locked = false
	emitted_round_3_seen = false
	if is_inside_tree():
		_show_round()


func set_texts(new_texts: Dictionary) -> void:
	texts = new_texts.duplicate(true)
	_refresh_texts()


func _setup_debug_run_if_needed() -> void:
	if get_tree().current_scene != self or not rounds.is_empty():
		return
	var debug_rng := RandomNumberGenerator.new()
	debug_rng.randomize()
	var seed_data := make_seed_data(debug_rng)
	rounds = (seed_data["rounds"] as Array).duplicate(true)
	texts = DEBUG_TEXTS.duplicate(true)


func apply_responsive_layout() -> void:
	if root == null or card_area == null or options_bar == null or options_box == null:
		return
	ResponsiveScale.set_scaled_offsets(root, root_base_offsets)
	ResponsiveScale.set_scaled_offsets(card_area, card_area_base_offsets)
	card_area.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, card_area_base_separation))))
	ResponsiveScale.set_scaled_offsets(options_bar, options_bar_base_offsets)
	options_box.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, options_box_base_separation))))
	_refresh_hand_area_layout(player_cards_box)
	_refresh_hand_area_layout(dealer_cards_box)
	for child in options_box.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = ResponsiveScale.size(self, OPTION_BUTTON_BASE_SIZE)
			button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 18))


func _capture_layout_baseline() -> void:
	root_base_offsets = ResponsiveScale.offsets(root)
	card_area_base_offsets = ResponsiveScale.offsets(card_area)
	options_bar_base_offsets = ResponsiveScale.offsets(options_bar)
	card_area_base_separation = card_area.get_theme_constant("separation")
	options_box_base_separation = options_box.get_theme_constant("separation")
	player_hand_base_minimum_size = player_hand_area.custom_minimum_size
	dealer_hand_base_minimum_size = dealer_hand_area.custom_minimum_size
	player_hand_base_separation = player_hand_area.get_theme_constant("separation")
	dealer_hand_base_separation = dealer_hand_area.get_theme_constant("separation")
	player_cards_base_separation = player_cards_box.get_theme_constant("separation")
	dealer_cards_base_separation = dealer_cards_box.get_theme_constant("separation")


func _show_round() -> void:
	if rounds.is_empty() or current_round >= rounds.size():
		return
	locked = false
	dealer_revealed = false
	var round_data: Dictionary = rounds[current_round]
	var player_cards: Array = round_data["player"]
	_render_hand(player_cards_box, player_cards, true)
	_render_hand(dealer_cards_box, [0, 0], false)
	_build_option_buttons()

	if current_round == 2 and not has_seen_round_3_before and not emitted_round_3_seen:
		emitted_round_3_seen = true
		war_round_3_seen.emit()


func _build_option_buttons() -> void:
	for child in options_box.get_children():
		options_box.remove_child(child)
		child.queue_free()
	_add_option_button(_txt("war.option_higher"), "higher")
	_add_option_button(_txt("war.option_lower"), "lower")
	if current_round == 2 and has_seen_round_3_before:
		_add_option_button(_txt("war.option_equal"), "push")


func _add_option_button(label_text: String, choice: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = ResponsiveScale.size(self, OPTION_BUTTON_BASE_SIZE)
	button.add_theme_font_size_override("font_size", ResponsiveScale.font_size(self, 18))
	button.pressed.connect(_on_option_pressed.bind(choice))
	options_box.add_child(button)


func _on_option_pressed(choice: String) -> void:
	if locked:
		return
	locked = true
	for child in options_box.get_children():
		if child is Button:
			child.disabled = true

	var round_data: Dictionary = rounds[current_round]
	var player_cards: Array = round_data["player"]
	var dealer_cards: Array = round_data["dealer"]
	var player_total: int = _total(player_cards)
	var dealer_total: int = _total(dealer_cards)
	dealer_revealed = true
	_render_hand(dealer_cards_box, dealer_cards, true)

	var correct_choice := ""
	if player_total > dealer_total:
		correct_choice = "higher"
	elif player_total < dealer_total:
		correct_choice = "lower"
	elif current_round == 2 and has_seen_round_3_before:
		correct_choice = "push"
	else:
		correct_choice = "dealer"

	if choice == correct_choice:
		await get_tree().create_timer(0.55).timeout
		current_round += 1
		if current_round >= rounds.size():
			game_won.emit()
		else:
			_show_round()
	else:
		await get_tree().create_timer(0.7).timeout
		game_lost.emit("war_call")


func _total(cards: Array) -> int:
	var total := 0
	for value in cards:
		total += int(value)
	return total


func _refresh_hand_area_layout(cards_box: HBoxContainer) -> void:
	if cards_box == null:
		return
	var hand_area := cards_box.get_parent() as VBoxContainer
	if hand_area == null:
		return
	hand_area.custom_minimum_size = ResponsiveScale.size(self, _hand_base_minimum_size(cards_box))
	hand_area.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, _hand_base_separation(cards_box)))))
	cards_box.add_theme_constant_override("separation", maxi(1, roundi(ResponsiveScale.length(self, _cards_base_separation(cards_box)))))
	for card in cards_box.get_children():
		if card is Control:
			(card as Control).custom_minimum_size = ResponsiveScale.size(self, CARD_VIEW_BASE_SIZE)


func _hand_base_minimum_size(cards_box: HBoxContainer) -> Vector2:
	if cards_box == player_cards_box:
		return player_hand_base_minimum_size
	return dealer_hand_base_minimum_size


func _hand_base_separation(cards_box: HBoxContainer) -> int:
	if cards_box == player_cards_box:
		return player_hand_base_separation
	return dealer_hand_base_separation


func _cards_base_separation(cards_box: HBoxContainer) -> int:
	if cards_box == player_cards_box:
		return player_cards_base_separation
	return dealer_cards_base_separation


func _render_hand(cards_box: HBoxContainer, cards: Array, face_up: bool) -> void:
	for child in cards_box.get_children():
		cards_box.remove_child(child)
		child.queue_free()
	for value in cards:
		cards_box.add_child(_make_card_view(int(value), face_up))
	_refresh_hand_area_layout(cards_box)


func _make_card_view(value: int, face_up: bool) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = ResponsiveScale.size(self, CARD_VIEW_BASE_SIZE)
	card.clip_contents = true

	var asset_texture := TextureRect.new()
	asset_texture.name = "AssetTexture"
	asset_texture.anchor_left = 0.08
	asset_texture.anchor_top = 0.10
	asset_texture.anchor_right = 0.92
	asset_texture.anchor_bottom = 0.90
	asset_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	asset_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	asset_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(asset_texture)

	var texture: Texture2D
	if face_up:
		texture = TextureLoader.load_from_dir(ASSET_DIR, _card_asset_name(value))
	else:
		texture = TextureLoader.load_from_dir(ASSET_DIR, CARD_BACK_ASSET)
	asset_texture.texture = texture
	return card


func _refresh_texts() -> void:
	if not rounds.is_empty() and current_round < rounds.size():
		var round_data: Dictionary = rounds[current_round]
		var player_cards: Array = round_data["player"]
		var dealer_cards: Array = round_data["dealer"]
		_render_hand(player_cards_box, player_cards, true)
		if dealer_revealed:
			_render_hand(dealer_cards_box, dealer_cards, true)
		else:
			_render_hand(dealer_cards_box, [0, 0], false)
		if not locked:
			_build_option_buttons()


func _txt(key: String) -> String:
	return str(texts.get(key, key))


func _card_asset_name(value: int) -> String:
	return "card_%d.png" % value
