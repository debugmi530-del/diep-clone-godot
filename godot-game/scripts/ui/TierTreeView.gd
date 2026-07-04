extends Control
## Visual tree of all 364 built-in tanks (1 -> 3 -> 9 -> 27 -> 81 -> 243)
## plus any custom tanks, laid out tier-by-tier so the player can browse the
## whole evolution tree and jump straight into a match with a chosen tank.

@onready var columns: HBoxContainer = $ScrollContainer/Columns
@onready var back_button: Button = $BackButton
@onready var info_label: Label = $InfoLabel
@onready var play_as_button: Button = $PlayAsButton

var selected_id: String = "root"

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	play_as_button.pressed.connect(_on_play_as_pressed)
	_build_tree_view()
	_update_info()

func _build_tree_view() -> void:
	for c in columns.get_children():
		c.queue_free()

	var by_tier: Dictionary = {}
	for id in TankDatabase.all_tank_ids():
		var t: TankDef = TankDatabase.get_tank(id)
		if not by_tier.has(t.tier):
			by_tier[t.tier] = []
		by_tier[t.tier].append(id)

	var tiers := by_tier.keys()
	tiers.sort()
	for tier in tiers:
		var col := VBoxContainer.new()
		var header := Label.new()
		header.text = "Тир %d" % tier
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(header)
		var ids: Array = by_tier[tier]
		ids.sort()
		for id in ids:
			var t: TankDef = TankDatabase.get_tank(id)
			var btn := Button.new()
			btn.text = t.display_name
			btn.custom_minimum_size = Vector2(150, 0)
			btn.modulate = t.color
			btn.pressed.connect(_on_tank_pressed.bind(id))
			col.add_child(btn)
		columns.add_child(col)

func _on_tank_pressed(id: String) -> void:
	selected_id = id
	_update_info()

func _update_info() -> void:
	var t: TankDef = TankDatabase.get_tank(selected_id)
	info_label.text = "Выбран: %s (класс: %s, тир %d)" % [t.display_name, TankDatabase.CLASS_DISPLAY.get(t.weapon_class, t.weapon_class), t.tier]

func _on_play_as_pressed() -> void:
	RunState.player_start_tank_id = selected_id
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
