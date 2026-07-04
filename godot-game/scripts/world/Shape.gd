extends RigidBody2D
## A single farmable shape (square/triangle/polygon). Uses Godot's built-in
## rigid body physics so contact between shapes and tanks is fully physical:
## mass, momentum and restitution all come from the engine, not hand-rolled
## collision math.

signal died(xp_reward: float, world_position: Vector2)

var def: ShapeDef
var health: float = 10.0
var max_health: float = 10.0

@onready var polygon: Polygon2D = $Polygon2D
@onready var outline: Line2D = $Outline
@onready var health_bar: ProgressBar = $HealthBar

func setup(shape_def: ShapeDef) -> void:
        def = shape_def
        health = def.health
        max_health = def.health
        mass = def.mass
        gravity_scale = 0
        linear_damp = GameConfig.SHAPE_LINEAR_DAMP
        angular_damp = GameConfig.SHAPE_ANGULAR_DAMP
        contact_monitor = true
        max_contacts_reported = 8
        add_to_group("shapes")
        _build_visual()
        angular_velocity = randf_range(-def.spin_speed, def.spin_speed)

func _build_visual() -> void:
        var points := PackedVector2Array()
        var n: int = max(def.sides, 3)
        for i in range(n):
                var angle := TAU * i / n - PI / 2.0
                points.append(Vector2(cos(angle), sin(angle)) * def.size)
        polygon.polygon = points
        polygon.color = def.color
        outline.points = points
        outline.add_point(points[0])
        outline.default_color = def.color.darkened(0.35)
        outline.width = 4.0

        var shape := ConvexPolygonShape2D.new()
        shape.points = points
        $CollisionShape2D.shape = shape

        health_bar.max_value = max_health
        health_bar.value = health
        health_bar.visible = false
        health_bar.position = Vector2(-def.size, -def.size - 14)
        health_bar.size = Vector2(def.size * 2, 6)

func take_damage(amount: float, source = null) -> void:
        health -= amount
        health_bar.visible = true
        health_bar.value = health
        if health <= 0:
                _grant_xp_to_killer(source)
                died.emit(def.xp_reward, global_position)
                queue_free()

func _grant_xp_to_killer(source) -> void:
        # `source` may be the bullet/mine/drone that hit us (which knows which
        # tank fired it) or a tank directly (e.g. body-damage ramming a shape).
        var killer_tank = null
        if source != null and "owner_tank" in source and is_instance_valid(source.owner_tank):
                killer_tank = source.owner_tank
        elif source != null and source is TankController:
                killer_tank = source
        if killer_tank != null and is_instance_valid(killer_tank):
                killer_tank.gain_xp(def.xp_reward)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
        # Gentle idle rotation so the arena feels alive even for sleeping shapes.
        if state.get_contact_count() == 0 and linear_velocity.length() < 4.0:
                state.angular_velocity = def.spin_speed * 0.4
