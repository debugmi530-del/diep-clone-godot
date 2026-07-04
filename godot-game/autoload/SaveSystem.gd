extends Node
## Persists nickname, keybindings and custom-built tanks to user:// so they
## survive between runs. Godot's user:// maps to a per-user app-data folder
## on Windows, so nothing else needs to be installed for this to work.

const SAVE_PATH := "user://save_data.json"

var nickname: String = "Player"
var custom_tanks: Array = [] # Array of Dictionary (see TankDef.to_dict())
var keybinds: Dictionary = {} # action_name -> array of serialized InputEvents

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	nickname = parsed.get("nickname", "Player")
	custom_tanks = parsed.get("custom_tanks", [])
	keybinds = parsed.get("keybinds", {})
	_apply_keybinds()

func save_data() -> void:
	var data := {
		"nickname": nickname,
		"custom_tanks": custom_tanks,
		"keybinds": _serialize_keybinds(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func set_nickname(new_name: String) -> void:
	nickname = new_name.strip_edges()
	if nickname.is_empty():
		nickname = "Player"
	save_data()

func add_custom_tank(tank_dict: Dictionary) -> void:
	custom_tanks.append(tank_dict)
	save_data()

func remove_custom_tank(tank_id: String) -> void:
	for i in range(custom_tanks.size() - 1, -1, -1):
		if custom_tanks[i].get("id", "") == tank_id:
			custom_tanks.remove_at(i)
	save_data()

func _serialize_keybinds() -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		if not action.begins_with("game_") and not ["move_up","move_down","move_left","move_right","fire_primary","fire_secondary","pause_menu"].has(action):
			continue
		var events := []
		for ev in InputMap.action_get_events(action):
			events.append(_event_to_dict(ev))
		out[action] = events
	return out

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "keycode": ev.physical_keycode}
	elif ev is InputEventMouseButton:
		return {"type": "mouse", "button_index": ev.button_index}
	elif ev is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": ev.button_index}
	elif ev is InputEventJoypadMotion:
		return {"type": "joy_motion", "axis": ev.axis, "axis_value": ev.axis_value}
	return {}

func _dict_to_event(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(d.get("keycode", 0))
			return ev
		"mouse":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(d.get("button_index", 1))
			return ev
		"joy_button":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(d.get("button_index", 0))
			return ev
		"joy_motion":
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(d.get("axis", 0))
			ev.axis_value = float(d.get("axis_value", 1.0))
			return ev
	return null

func _apply_keybinds() -> void:
	for action in keybinds.keys():
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for evd in keybinds[action]:
			var ev := _dict_to_event(evd)
			if ev != null:
				InputMap.action_add_event(action, ev)

func rebind_action(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_data()
