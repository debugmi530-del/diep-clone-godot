extends RigidBody2D
class_name TankController
## Shared brain for both the player's tank and every bot tank. Movement uses
## Godot's RigidBody2D physics so pushing/being pushed by shapes and other
## tanks is fully physical (mass-based knockback, angular impulses on glancing
## hits, etc). Player input comes from InputManager; bot input comes from a
## child BotBrain node that writes into the same `move_vector` / `aim_vector`
## / firing flags each frame, so both cases run through identical code below.

signal died(killer: Node)
signal leveled_up(new_level: int)
signal tier_changed(new_tier: int)

@export var is_player: bool = false
@export var tank_def_id: String = "root"
@export var nickname: String = "Tank"

# --- Runtime input state (set by _process_player_input or BotBrain) ---
var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.RIGHT
var firing_primary: bool = false
var firing_secondary: bool = false

# --- Progression ---
var level: int = 1
var xp: float = 0.0
var xp_to_next: float = 10.0
var score: int = 0
var stat_points_available: int = 0
var stat_levels: Dictionary = {}
var tier: int = 1
var def: TankDef

# --- Live combat stats (derived each time stats/tier change) ---
var max_health: float = 100.0
var health: float = 100.0
var health_regen: float = 1.0
var body_damage: float = 10.0
var movement_speed: float = 300.0
var bullet_speed: float = 900.0
var bullet_damage: float = 10.0
var reload_time: float = 0.5

var _reload_timers: Dictionary = {} # barrel index -> time remaining
var _regen_accumulator: float = 0.0
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

# --- Contact/ram damage (RigidBody2D collisions with other tanks/shapes) ---
var _touching_bodies: Array = []

@onready var body_polygon: Polygon2D = $BodyPolygon
@onready var barrels_node: Node2D = $Barrels
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var weapon_system

func _ready() -> void:
        add_to_group("tanks")
        weapon_system = load("res://scripts/tank/WeaponSystem.gd").new(self)
        set_tank_def(TankDatabase.get_tank(tank_def_id))
        for s in GameConfig.stat_names():
                stat_levels[s] = 0
        name_label.text = nickname
        gravity_scale = 0
        linear_damp = GameConfig.TANK_LINEAR_DAMP
        angular_damp = GameConfig.TANK_ANGULAR_DAMP
        contact_monitor = true
        max_contacts_reported = 8
        _recalculate_stats()
        health = max_health
        body_entered.connect(_on_body_entered)
        body_exited.connect(_on_body_exited)

func set_tank_def(new_def: TankDef) -> void:
        def = new_def
        tier = def.tier
        _build_body_visual()
        weapon_system.build_for_def(def)
        _recalculate_stats()
        tier_changed.emit(tier)

func _build_body_visual() -> void:
        var radius: float = 24.0 * def.body_size
        var pts := PackedVector2Array()
        for i in range(16):
                var a := TAU * i / 16
                pts.append(Vector2(cos(a), sin(a)) * radius)
        body_polygon.polygon = pts
        body_polygon.color = def.color
        var shape := CircleShape2D.new()
        shape.radius = radius
        $CollisionShape2D.shape = shape
        health_bar.position = Vector2(-radius, -radius - 16)
        health_bar.size = Vector2(radius * 2, 8)

func _physics_process(delta: float) -> void:
        if is_player:
                _process_player_input()
        _apply_movement(delta)
        _process_regen(delta)
        _process_firing(delta)
        _process_contact_damage(delta)
        _orient_barrels()
        health_bar.value = health
        health_bar.max_value = max_health

func _on_body_entered(body: Node) -> void:
        if body == self:
                return
        if body.is_in_group("tanks") or body.is_in_group("shapes"):
                _touching_bodies.append(body)

func _on_body_exited(body: Node) -> void:
        _touching_bodies.erase(body)

func _process_contact_damage(delta: float) -> void:
        # Diep.io-style body collision: both sides deal their body-damage stat per
        # second while overlapping, plus a physics knockback impulse scaled by
        # relative mass so heavier tanks/shapes push lighter ones around.
        for body in _touching_bodies.duplicate():
                if not is_instance_valid(body):
                        _touching_bodies.erase(body)
                        continue
                var other_damage: float = 0.0
                if body is TankController:
                        if def.extra_params.get("ram_immune", false) and body.def.extra_params.get("ram_immune", false):
                                other_damage = body.body_damage * 0.3
                        else:
                                other_damage = body.body_damage
                elif "def" in body and body.def is ShapeDef:
                        other_damage = body.def.body_damage
                if other_damage > 0.0:
                        take_damage(other_damage * delta, body)
                if not def.extra_params.get("ram_immune", false):
                        var away := (global_position - body.global_position)
                        if away.length() > 0.01 and body is RigidBody2D:
                                var impulse := away.normalized() * GameConfig.KNOCKBACK_FORCE_SCALE * delta
                                apply_central_impulse(impulse)
                                body.apply_central_impulse(-impulse)

func _process_player_input() -> void:
        move_vector = InputManager.get_move_vector()
        var viewport := get_viewport()
        aim_vector = InputManager.get_aim_vector(global_position, viewport)
        firing_primary = InputManager.is_firing_primary()
        firing_secondary = InputManager.is_firing_secondary()

func _apply_movement(delta: float) -> void:
        var target_velocity := move_vector * movement_speed
        # Physics-based acceleration toward target velocity (not an instant snap),
        # so momentum from knockback still visibly affects the tank for a moment.
        linear_velocity = linear_velocity.lerp(target_velocity, clamp(delta * 6.0, 0.0, 1.0))
        if aim_vector.length() > 0.01:
                var target_angle := aim_vector.angle()
                rotation = lerp_angle(rotation, target_angle, clamp(delta * 10.0, 0.0, 1.0))

func _process_regen(delta: float) -> void:
        if health < max_health:
                health = min(max_health, health + health_regen * delta)

func _process_firing(delta: float) -> void:
        weapon_system.process(delta, firing_primary, firing_secondary)

func _orient_barrels() -> void:
        barrels_node.rotation = 0.0 # barrels are children in tank-local space; body already rotated

func spawn_bullet(local_offset: Vector2, direction: Vector2, params_override: Dictionary = {}) -> void:
        var b := bullet_scene.instantiate()
        get_tree().current_scene.add_child(b)
        b.global_position = to_global(local_offset)
        var p := {
                "owner": self,
                "damage": bullet_damage,
                "speed": bullet_speed,
                "direction": direction,
                "size": 10.0 * def.barrel_size,
                "color": def.color.lightened(0.2),
        }
        for k in params_override.keys():
                p[k] = params_override[k]
        b.setup(p)

func take_damage(amount: float, source = null) -> void:
        health -= amount
        if health <= 0:
                _die(source)

func _die(source = null) -> void:
        # `source` may be the bullet/mine/drone that landed the killing blow (which
        # knows which tank fired it) or another tank directly (body-damage ram).
        var killer_tank = null
        if source != null and "owner_tank" in source and is_instance_valid(source.owner_tank):
                killer_tank = source.owner_tank
        elif source is TankController:
                killer_tank = source
        if killer_tank != null and is_instance_valid(killer_tank) and killer_tank != self:
                killer_tank.gain_xp(max_health * 0.5 + level * 5.0)
        died.emit(killer_tank)
        queue_free()

func gain_xp(amount: float) -> void:
        xp += amount
        while xp >= xp_to_next and level < GameConfig.MAX_LEVEL:
                xp -= xp_to_next
                level += 1
                stat_points_available += 1
                xp_to_next = _xp_needed_for(level + 1)
                leveled_up.emit(level)
                _check_tier_up()
        score = int(xp) + level * 25

func _xp_needed_for(next_level: int) -> float:
        return 10.0 * pow(next_level, 1.6)

func _check_tier_up() -> void:
        for t in [5, 4, 3, 2]:
                if level >= GameConfig.TIER_LEVEL_THRESHOLDS[t] and tier < t:
                        _advance_tier(t)
                        return

func _advance_tier(new_tier: int) -> void:
        # Resetting upgrades on tier change per the design brief.
        for s in stat_levels.keys():
                stat_points_available += stat_levels[s]
                stat_levels[s] = 0
        tier = new_tier

func upgrade_stat(stat_key: String) -> bool:
        if stat_points_available <= 0:
                return false
        if stat_levels.get(stat_key, 0) >= GameConfig.STAT_MAX_POINTS:
                return false
        stat_levels[stat_key] += 1
        stat_points_available -= 1
        _recalculate_stats()
        return true

func evolve_to(new_tank_id: String) -> void:
        var candidates := TankDatabase.get_children(def.id)
        if candidates.has(new_tank_id):
                set_tank_def(TankDatabase.get_tank(new_tank_id))

func _recalculate_stats() -> void:
        var lvl := func(key): return float(stat_levels.get(key, 0))
        max_health = 100.0 * def.base_health * (1.0 + lvl.call("health") * 0.16)
        health_regen = 1.0 * def.base_health_regen * (1.0 + lvl.call("health_regen") * 0.35)
        body_damage = 10.0 * def.base_body_damage * (1.0 + lvl.call("body_damage") * 0.22)
        movement_speed = 300.0 * def.base_movement_speed * (1.0 + lvl.call("movement_speed") * 0.08)
        bullet_speed = 900.0 * def.base_bullet_speed * (1.0 + lvl.call("bullet_speed") * 0.10)
        bullet_damage = 10.0 * def.base_bullet_damage * (1.0 + lvl.call("bullet_damage") * 0.22)
        reload_time = (0.5 * def.base_reload) / (1.0 + lvl.call("reload") * 0.18)
        health = min(health, max_health)
