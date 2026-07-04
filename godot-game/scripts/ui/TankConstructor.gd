extends Control
## Full tank constructor: create a brand new tank from scratch or load and
## edit any existing tank (built-in or custom) as a starting point, then
## configure its tier, parent, weapon class, barrel count/size, body size,
## name and every base stat before saving it into the tree.

@onready var id_list: ItemList = $HSplit/LeftPanel/ExistingList
@onready var new_button: Button = $HSplit/LeftPanel/NewButton
@onready var name_field: LineEdit = $HSplit/RightPanel/NameField
@onready var tier_spin: SpinBox = $HSplit/RightPanel/TierRow/TierSpin
@onready var parent_option: OptionButton = $HSplit/RightPanel/ParentRow/ParentOption
@onready var class_option: OptionButton = $HSplit/RightPanel/ClassRow/ClassOption
@onready var barrel_count_spin: SpinBox = $HSplit/RightPanel/BarrelRow/BarrelCountSpin
@onready var barrel_size_slider: HSlider = $HSplit/RightPanel/BarrelSizeRow/BarrelSizeSlider
@onready var body_size_slider: HSlider = $HSplit/RightPanel/BodySizeRow/BodySizeSlider
@onready var stat_sliders: Dictionary = {}
@onready var stats_box: VBoxContainer = $HSplit/RightPanel/StatsBox
@onready var save_button: Button = $HSplit/RightPanel/ButtonRow/SaveButton
@onready var delete_button: Button = $HSplit/RightPanel/ButtonRow/DeleteButton
@onready var back_button: Button = $HSplit/RightPanel/ButtonRow/BackButton
@onready var preview: Polygon2D = $HSplit/RightPanel/PreviewViewport/SubViewport/PreviewBody

const STAT_FIELDS := [
	{"key": "base_health", "label": "Здоровье"},
	{"key": "base_health_regen", "label": "Реген. здоровья"},
	{"key": "base_movement_speed", "label": "Скорость"},
	{"key": "base_reload", "label": "Скорость перезарядки"},
	{"key": "base_bullet_speed", "label": "Скорость снаряда"},
	{"key": "base_bullet_damage", "label": "Урон снаряда"},
	{"key": "base_body_damage", "label": "Урон корпуса"},
]

var editing_id: String = ""
var is_new: bool = true
var all_ids: Array = []

func _ready() -> void:
	new_button.pressed.connect(_on_new_pressed)
	id_list.item_selected.connect(_on_item_selected)
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	class_option.item_selected.connect(func(_i): _update_preview())
	body_size_slider.value_changed.connect(func(_v): _update_preview())

	for class_key in TankDatabase.CLASS_KEYS:
		class_option.add_item(TankDatabase.CLASS_DISPLAY.get(class_key, class_key))

	_build_stat_sliders()
	_refresh_list()
	_load_into_form(TankDatabase.get_tank("root"))

func _build_stat_sliders() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	stat_sliders.clear()
	for field in STAT_FIELDS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = field["label"]
		label.custom_minimum_size = Vector2(180, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.2
		slider.max_value = 3.0
		slider.step = 0.05
		slider.value = 1.0
		slider.custom_minimum_size = Vector2(200, 0)
		row.add_child(slider)
		stats_box.add_child(row)
		stat_sliders[field["key"]] = slider

func _refresh_list() -> void:
	id_list.clear()
	all_ids = TankDatabase.all_tank_ids()
	all_ids.sort()
	parent_option.clear()
	parent_option.add_item("Нет (корень)", 0)
	var idx := 1
	for id in all_ids:
		var t: TankDef = TankDatabase.get_tank(id)
		id_list.add_item("%s (%s)" % [t.display_name, id])
		parent_option.add_item(t.display_name, idx)
		parent_option.set_item_metadata(idx, id)
		idx += 1

func _on_new_pressed() -> void:
	is_new = true
	editing_id = ""
	var blank := TankDef.new()
	blank.display_name = "Новый танк"
	_load_into_form(blank)

func _on_item_selected(index: int) -> void:
	var id: String = all_ids[index]
	is_new = false
	editing_id = id
	_load_into_form(TankDatabase.get_tank(id))

func _load_into_form(t: TankDef) -> void:
	name_field.text = t.display_name
	tier_spin.value = t.tier
	class_option.select(TankDatabase.CLASS_KEYS.find(t.weapon_class) if TankDatabase.CLASS_KEYS.has(t.weapon_class) else 0)
	barrel_count_spin.value = t.barrel_count
	barrel_size_slider.value = t.barrel_size
	body_size_slider.value = t.body_size
	for key in stat_sliders.keys():
		stat_sliders[key].value = t.get(key)
	_select_parent_in_option(t.parent_id)
	_update_preview()

func _select_parent_in_option(parent_id: String) -> void:
	for i in range(parent_option.item_count):
		if parent_option.get_item_metadata(i) == parent_id:
			parent_option.select(i)
			return
	parent_option.select(0)

func _update_preview() -> void:
	if preview == null:
		return
	var n := 12
	var pts := PackedVector2Array()
	var r := 40.0 * body_size_slider.value
	for i in range(n):
		var ang := TAU * i / n
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	preview.polygon = pts
	var class_key: String = TankDatabase.CLASS_KEYS[class_option.selected] if class_option.selected >= 0 else "normal"
	preview.color = GameConfig.TIER_COLORS.get(int(tier_spin.value), GameConfig.COLOR_PLAYER_BLUE)

func _on_save_pressed() -> void:
	var t := TankDef.new()
	t.id = editing_id if not is_new else ""
	t.display_name = name_field.text.strip_edges() if not name_field.text.strip_edges().is_empty() else "Танк"
	t.tier = int(tier_spin.value)
	var parent_meta = parent_option.get_item_metadata(parent_option.selected)
	t.parent_id = "" if parent_meta == 0 or parent_meta == null else str(parent_meta)
	t.weapon_class = TankDatabase.CLASS_KEYS[class_option.selected]
	t.barrel_count = int(barrel_count_spin.value)
	t.barrel_size = barrel_size_slider.value
	t.body_size = body_size_slider.value
	t.color = GameConfig.TIER_COLORS.get(t.tier, GameConfig.COLOR_PLAYER_BLUE)
	t.is_custom = true
	for key in stat_sliders.keys():
		t.set(key, stat_sliders[key].value)
	t.extra_params = {
		"ram_immune": t.weapon_class == "rammer",
		"drone_count": 3 if t.weapon_class == "drone" else 0,
		"turret_count": 1 if t.weapon_class == "turret" else 0,
		"mine_count": 3 if t.weapon_class == "mine_layer" else 0,
		"homing_strength": 0.35 if t.weapon_class == "rocket" else 0.0,
	}
	if not is_new and editing_id.begins_with("custom_"):
		TankDatabase.tanks[editing_id] = null
		SaveSystem.remove_custom_tank(editing_id)
		t.id = editing_id
	TankDatabase.register_custom_tank(t)
	is_new = false
	editing_id = t.id
	_refresh_list()

func _on_delete_pressed() -> void:
	if editing_id.is_empty() or not editing_id.begins_with("custom_"):
		return
	SaveSystem.remove_custom_tank(editing_id)
	TankDatabase.tanks.erase(editing_id)
	_on_new_pressed()
	_refresh_list()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
