extends Node2D
## Spawns and re-spawns the arena's farmable shapes.
##
## Perf note: shape count is capped by GameConfig.MAX_SHAPES (2000) to keep
## physics and rendering smooth on a single machine. Shapes far from every
## tank are additionally frozen (Godot stops integrating their physics until
## something gets close again) — see _update_activity(). Nothing is deleted;
## density stays exactly as spawned.

var shape_scene: PackedScene = preload("res://scenes/Shape.tscn")
var target_count: int = GameConfig.MAX_SHAPES
var active_shapes: Array = []
var _activity_timer: float = 0.0

# Spatial hash of occupied cells -> list of positions, used to reject spawn
# points that would land shapes on top of each other. Cell size matches the
# minimum spacing so a lookup only needs to check the 3x3 neighborhood.
var _cell_size: float = GameConfig.SHAPE_MIN_SPACING
var _occupied_cells: Dictionary = {}

func _cell_key(pos: Vector2) -> Vector2i:
        return Vector2i(floori(pos.x / _cell_size), floori(pos.y / _cell_size))

func _register_position(pos: Vector2) -> void:
        var key := _cell_key(pos)
        if not _occupied_cells.has(key):
                _occupied_cells[key] = []
        _occupied_cells[key].append(pos)

func _is_far_enough(pos: Vector2) -> bool:
        var base := _cell_key(pos)
        var min_dist_sq: float = GameConfig.SHAPE_MIN_SPACING * GameConfig.SHAPE_MIN_SPACING
        for dx in range(-1, 2):
                for dy in range(-1, 2):
                        var key := base + Vector2i(dx, dy)
                        if not _occupied_cells.has(key):
                                continue
                        for other_pos in _occupied_cells[key]:
                                if pos.distance_squared_to(other_pos) < min_dist_sq:
                                        return false
        return true

func _find_free_spot() -> Vector2:
        var half: float = GameConfig.WORLD_SIZE / 2.0
        var pos := Vector2(randf_range(-half, half), randf_range(-half, half))
        var attempts := 0
        while attempts < 12 and not _is_far_enough(pos):
                pos = Vector2(randf_range(-half, half), randf_range(-half, half))
                attempts += 1
        _register_position(pos)
        return pos

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
                pos = _find_free_spot()
        shape.position = pos
        shape.rotation = randf_range(0, TAU)
        shape.set_meta("spawn_cell_pos", pos)
        add_child(shape)
        shape.setup(def)
        shape.died.connect(_on_shape_died.bind(shape))
        active_shapes.append(shape)

func _on_shape_died(_xp: float, _world_position: Vector2, shape: Node) -> void:
        active_shapes.erase(null) # cheap cleanup of freed refs over time
        # Free this shape's reserved spot in the spacing grid so the cell can
        # be reused; otherwise long play sessions would leak grid entries
        # forever since shapes constantly die and respawn.
        if is_instance_valid(shape) and shape.has_meta("spawn_cell_pos"):
                var spawn_pos: Vector2 = shape.get_meta("spawn_cell_pos")
                var key := _cell_key(spawn_pos)
                if _occupied_cells.has(key):
                        _occupied_cells[key].erase(spawn_pos)
                        if _occupied_cells[key].is_empty():
                                _occupied_cells.erase(key)
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
