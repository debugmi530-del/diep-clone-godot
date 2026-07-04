extends RefCounted
class_name WeaponSystem
## Fires bullets/drones/mines/turrets on behalf of a TankController according
## to its TankDef.weapon_class. One object per tank; holds no visual nodes of
## its own except procedurally-placed barrel sprites under Barrels/.

var tank: TankController
var barrel_offsets: Array = [] # Array[Vector2] local offsets per barrel
var reload_timers: Array = []
var class_key: String = "normal"
var extra: Dictionary = {}
var drones: Array = []
var turret_nodes: Array = []
var mine_scene: PackedScene = preload("res://scenes/Mine.tscn")
var turret_scene: PackedScene = preload("res://scenes/Turret.tscn")
var drone_scene: PackedScene = preload("res://scenes/Drone.tscn")

func _init(owner_tank: TankController) -> void:
	tank = owner_tank

func build_for_def(def: TankDef) -> void:
	class_key = def.weapon_class
	extra = def.extra_params
	_clear_barrel_visuals()
	barrel_offsets.clear()
	reload_timers.clear()

	var count: int = max(def.barrel_count, 0)
	var radius: float = 24.0 * def.body_size
	for i in range(count):
		var spread: float = 0.0
		if class_key == "shotgun":
			spread = lerp(-0.5, 0.5, float(i) / max(1, count - 1)) if count > 1 else 0.0
		var offset := Vector2(radius + 18.0 * def.barrel_size, 0).rotated(spread)
		barrel_offsets.append(offset)
		reload_timers.append(0.0)
		_add_barrel_visual(offset, def, spread)

	_setup_class_extras()

func _add_barrel_visual(offset: Vector2, def: TankDef, spread: float) -> void:
	var barrel := ColorRect.new()
	var length: float = 34.0 * def.barrel_size
	var width: float = 16.0 * def.barrel_size
	barrel.size = Vector2(length, width)
	barrel.position = Vector2(0, -width / 2.0)
	barrel.color = Color("6b6b6b")
	var pivot := Node2D.new()
	pivot.position = Vector2(24.0 * def.body_size * cos(spread), 24.0 * def.body_size * sin(spread))
	pivot.rotation = spread
	pivot.add_child(barrel)
	tank.barrels_node.add_child(pivot)

func _clear_barrel_visuals() -> void:
	for c in tank.barrels_node.get_children():
		c.queue_free()

func _setup_class_extras() -> void:
	match class_key:
		"turret":
			pass # turrets are spawned lazily on first process() call
		"drone":
			pass
		_:
			pass

func process(delta: float, firing_primary: bool, firing_secondary: bool) -> void:
	match class_key:
		"rammer":
			return # no guns; damage comes entirely from body contact
		"mine_layer":
			_process_mine_layer(delta, firing_primary)
		"turret":
			_process_turret(delta)
		"drone":
			_process_drone(delta, firing_primary, firing_secondary)
		_:
			_process_standard_fire(delta, firing_primary)

func _process_standard_fire(delta: float, firing: bool) -> void:
	for i in range(barrel_offsets.size()):
		reload_timers[i] -= delta
	if not firing or barrel_offsets.is_empty():
		return
	for i in range(barrel_offsets.size()):
		if reload_timers[i] <= 0.0:
			_fire_barrel(i)
			reload_timers[i] = tank.reload_time * _reload_multiplier()

func _reload_multiplier() -> float:
	match class_key:
		"shotgun":
			return 1.3
		"machinegun":
			return 0.5
		"sniper":
			return 1.5
		"rocket":
			return 1.6
		_:
			return 1.0

func _fire_barrel(i: int) -> void:
	var offset: Vector2 = barrel_offsets[i]
	var dir: Vector2 = offset.rotated(tank.rotation).normalized()
	var params := {}
	if class_key == "shotgun":
		dir = dir.rotated(randf_range(-0.12, 0.12))
		params["damage"] = tank.bullet_damage * 0.55
	elif class_key == "sniper":
		params["speed"] = tank.bullet_speed * 1.3
		params["lifetime"] = 2.2
	elif class_key == "rocket":
		params["homing_strength"] = extra.get("homing_strength", 0.3)
		params["speed"] = tank.bullet_speed * 0.75
	tank.spawn_bullet(offset.rotated(tank.rotation - offset.angle() + dir.angle() - dir.angle()), dir, params)

func _process_mine_layer(delta: float, firing: bool) -> void:
	if reload_timers.is_empty():
		reload_timers = [0.0]
	reload_timers[0] -= delta
	if firing and reload_timers[0] <= 0.0:
		_drop_mine()
		reload_timers[0] = tank.reload_time * 2.2

func _drop_mine() -> void:
	var mine := mine_scene.instantiate()
	tank.get_tree().current_scene.add_child(mine)
	mine.global_position = tank.global_position - tank.transform.x * 40.0
	mine.setup({"owner": tank, "damage": tank.bullet_damage * 2.5})

func _process_turret(delta: float) -> void:
	if turret_nodes.is_empty():
		var count: int = max(1, int(extra.get("turret_count", 1)))
		for i in range(count):
			var t := turret_scene.instantiate()
			tank.get_tree().current_scene.add_child(t)
			t.setup(tank)
			turret_nodes.append(t)
	turret_nodes = turret_nodes.filter(func(n): return is_instance_valid(n))

func _process_drone(delta: float, firing_primary: bool, firing_secondary: bool) -> void:
	drones = drones.filter(func(n): return is_instance_valid(n))
	var desired: int = max(1, int(extra.get("drone_count", 3)))
	if firing_primary and drones.size() < desired:
		var d := drone_scene.instantiate()
		tank.get_tree().current_scene.add_child(d)
		d.global_position = tank.global_position
		d.setup(tank)
		drones.append(d)
	if firing_secondary:
		for d in drones:
			d.recall_to(tank.global_position)
