extends Node
## Central place for reading move/aim/fire input from either keyboard+mouse
## or a gamepad, so gameplay code never has to care which device is active.

var active_device: String = "keyboard" # "keyboard" or "gamepad"
var gamepad_device_id: int = 0

const STICK_DEADZONE := 0.2

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and abs(event.axis_value) < STICK_DEADZONE:
			return
		active_device = "gamepad"
		gamepad_device_id = event.device
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		active_device = "keyboard"

## Returns a normalized movement vector from WASD/left stick.
func get_move_vector() -> Vector2:
	var v := Vector2.ZERO
	v.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	v.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if v.length() > 1.0:
		v = v.normalized()
	return v

## Returns a normalized aim direction. On keyboard this comes from the mouse
## position relative to the tank; on gamepad from the right stick.
func get_aim_vector(tank_global_position: Vector2, viewport: Viewport) -> Vector2:
	if active_device == "gamepad":
		var v := Vector2.ZERO
		v.x = Input.get_joy_axis(gamepad_device_id, JOY_AXIS_RIGHT_X)
		v.y = Input.get_joy_axis(gamepad_device_id, JOY_AXIS_RIGHT_Y)
		if v.length() < STICK_DEADZONE:
			return Vector2.ZERO
		return v.normalized()
	else:
		var mouse_pos := viewport.get_camera_2d().get_global_mouse_position() if viewport.get_camera_2d() else viewport.get_mouse_position()
		return (mouse_pos - tank_global_position).normalized()

func is_firing_primary() -> bool:
	if active_device == "gamepad":
		return Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.3
	return Input.is_action_pressed("fire_primary")

func is_firing_secondary() -> bool:
	if active_device == "gamepad":
		return Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_LEFT) > 0.3
	return Input.is_action_pressed("fire_secondary")
