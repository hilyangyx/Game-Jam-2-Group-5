extends Control

signal game_won
signal game_lost(reason)
signal war_round_3_seen

const ASSET_DIR := "res://Assets/Cards"

var rounds: Array = []
var has_seen_round_3_before := false
var emitted_round_3_seen := false
var current_round := 0
var locked := false
var texts: Dictionary = {}
var dealer_revealed := false

var player_cards_box: HBoxContainer
var dealer_cards_box: HBoxContainer
var options_box: HBoxContainer


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
	_build_ui()
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


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 32.0
	root.offset_top = 14.0
	root.offset_right = -32.0
	root.offset_bottom = -16.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var card_area := VBoxContainer.new()
	card_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_area.add_theme_constant_override("separation", 22)
	root.add_child(card_area)

	var dealer_area := _make_hand_area()
	card_area.add_child(dealer_area)
	dealer_cards_box = dealer_area.get_node("CardsBox") as HBoxContainer

	var player_area := _make_hand_area()
	card_area.add_child(player_area)
	player_cards_box = player_area.get_node("CardsBox") as HBoxContainer

	options_box = HBoxContainer.new()
	options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	options_box.add_theme_constant_override("separation", 14)
	root.add_child(options_box)


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
		child.queue_free()
	_add_option_button(_txt("war.option_higher"), "higher")
	_add_option_button(_txt("war.option_lower"), "lower")
	if current_round == 2 and has_seen_round_3_before:
		_add_option_button(_txt("war.option_push"), "push")


func _add_option_button(label_text: String, choice: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(150, 48)
	button.add_theme_font_size_override("font_size", 18)
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


func _make_hand_area() -> VBoxContainer:
	var hand_area := VBoxContainer.new()
	hand_area.custom_minimum_size = Vector2(380, 150)
	hand_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_area.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	hand_area.add_child(title)

	var cards_box := HBoxContainer.new()
	cards_box.name = "CardsBox"
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.add_theme_constant_override("separation", 12)
	hand_area.add_child(cards_box)

	var total_label := Label.new()
	total_label.name = "TotalLabel"
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 16)
	hand_area.add_child(total_label)
	return hand_area


func _render_hand(cards_box: HBoxContainer, cards: Array, face_up: bool) -> void:
	for child in cards_box.get_children():
		cards_box.remove_child(child)
		child.queue_free()
	for value in cards:
		cards_box.add_child(_make_card_view(int(value), face_up))


func _make_card_view(value: int, face_up: bool) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(116, 88)
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
		texture = _load_texture(_card_asset_name(value))
	else:
		texture = _load_texture("card_back.png")
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


func _load_texture(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	var path: String = "%s/%s" % [ASSET_DIR, file_name]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
