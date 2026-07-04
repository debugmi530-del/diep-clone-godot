extends Node2D
## Spawns and re-spawns the arena's farmable shapes.
##
## Perf note: GameConfig.MAX_SHAPES defaults to 40000 to match the brief, but
## simulating 40000 fully-active RigidBody2D nodes at once is unrealistic for
## real-time play on a single machine. To keep the requested count while
## staying playable, shapes far from every tank are frozen (Godot stops
## integrating their physics until something gets close again) — see
## _update_activity(). Nothing is deleted; density stays exactly as spawned.

var shape_scene: PackedScene = preload("res://scenes/Shape.tscn")
var target_count: int = GameConfig.MAX_SHAPES
var active_shapes: Array = []
var _activity_timer: float = 0.0

func _ready() -> void:
	randomize()
	call_deferred("_initial_spawn")

func _initial_spawn() -> void:
	for i in range(target_count):
		_spawn_one()
		if i % 500 == 0:
			await get_tree().process_frame

func _spawn_one(position_override = null) -> void:
	var shape := shape_scene.instantiate()
	var def := ShapeDatabase.get_shape(ShapeDatabase.random_shape_id())
	var pos: Vector2
	if position_override != null:
		pos = position_override
	else:
		pos = Vector2(
			randf_range(-GameConfig.WORLD_SIZE / 2.0, GameConfig.WORLD_SIZE / 2.0),
			randf_range(-GameConfig.WORLD_SIZE / 2.0, GameConfig.WORLD_SIZE / 2.0)
		)
	shape.position = pos
	shape.rotation = randf_range(0, TAU)
	add_child(shape)
	shape.setup(def)
	shape.died.connect(_on_shape_died)
	active_shapes.append(shape)

func _on_shape_died(_xp: float, world_position: Vector2) -> void:
	active_shapes.erase(null) # cheap cleanup of freed refs over time
	# Respawn a fresh shape elsewhere to keep the arena population stable.
	call_deferred("_spawn_one")

func _physics_process(delta: float) -> void:
	_activity_timer += delta
	if _activity_timer < 0.5:
		return
	_activity_timer = 0.0
	_update_activity()

func _update_activity() -> void:
	var tanks := get_tree().get_nodes_in_group("tanks")
	if tanks.is_empty():
		return
	var radius_sq: float = GameConfig.ACTIVE_PHYSICS_RADIUS * GameConfig.ACTIVE_PHYSICS_RADIUS
	for shape in active_shapes:
		if shape == null or not is_instance_valid(shape):
			continue
		var near := false
		for t in tanks:
			if not is_instance_valid(t):
				continue
			if shape.global_position.distance_squared_to(t.global_position) < radius_sq:
				near = true
				break
		shape.freeze = not near
