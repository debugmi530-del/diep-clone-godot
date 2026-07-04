extends Control
## Rebinding screen: lists each remappable action and lets the player click a
## button, then press any key/mouse button/gamepad button to bind it. Works
## for keyboard+mouse AND gamepad, satisfying "можно изменить кнопки на
## геймпада/клавиатуре и мышке".

const ACTIONS := [
	{"key": "move_up", "label": "Движение — вверх"},
	{"key": "move_down", "label": "Движение — вниз"},
	{"key": "move_left", "label": "Движение — влево"},
	{"key": "move_right", "label": "Движение — вправо"},
	{"key": "fire_primary", "label": "Стрельба (осн.)"},
	{"key": "fire_secondary", "label": "Стрельба (доп.)"},
	{"key": "pause_menu", "label": "Пауза / меню"},
]

@onready var bind_box: VBoxContainer = $Panel/ScrollContainer/BindBox
@onready var back_button: Button = $BackButton
@onready var hint_label: Label = $HintLabel

var listening_for_action: String = ""
var action_buttons: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_rows()

func _build_rows() -> void:
	for c in bind_box.get_children():
		c.queue_free()
	for entry in ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = entry["label"]
		label.custom_minimum_size = Vector2(240, 0)
		row.add_child(label)

		var btn := Button.new()
		btn.text = _current_binding_text(entry["key"])
		btn.pressed.connect(_on_rebind_pressed.bind(entry["key"], btn))
		row.add_child(btn)
		action_buttons[entry["key"]] = btn
		bind_box.add_child(row)

func _current_binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	return events[0].as_text()

func _on_rebind_pressed(action: String, btn: Button) -> void:
	listening_for_action = action
	btn.text = "Нажмите любую кнопку..."
	hint_label.text = "Ожидание ввода для: %s" % action

func _unhandled_input(event: InputEvent) -> void:
	if listening_for_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		SaveSystem.rebind_action(listening_for_action, event)
		_finish_rebind()
	elif event is InputEventMouseButton and event.pressed:
		SaveSystem.rebind_action(listening_for_action, event)
		_finish_rebind()
	elif event is InputEventJoypadButton and event.pressed:
		SaveSystem.rebind_action(listening_for_action, event)
		_finish_rebind()
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.6:
		SaveSystem.rebind_action(listening_for_action, event)
		_finish_rebind()

func _finish_rebind() -> void:
	var action := listening_for_action
	listening_for_action = ""
	hint_label.text = "Выберите кнопку, чтобы переназначить её"
	if action_buttons.has(action):
		action_buttons[action].text = _current_binding_text(action)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
