extends Node2D
## Stationary turret placed by the turret-class tank. Auto-aims and fires at
## the nearest enemy within range; orbits gently around its owner.

var owner_tank: TankController
var range_radius: float = 500.0
var reload_timer: float = 0.0
var offset_angle: float = 0.0
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var polygon: Polygon2D = $Polygon2D
@onready var barrel: ColorRect = $Barrel

func setup(tank: TankController) -> void:
	owner_tank = tank
	offset_angle = randf_range(0, TAU)
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * i / 10
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	polygon.polygon = pts
	polygon.color = tank.def.color.darkened(0.1)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_tank):
		queue_free()
		return
	offset_angle += delta * 0.4
	global_position = owner_tank.global_position + Vector2(60, 0).rotated(offset_angle)

	var target := _find_target()
	reload_timer -= delta
	if target:
		rotation = (target.global_position - global_position).angle()
		if reload_timer <= 0.0:
			_fire(target)
			reload_timer = owner_tank.reload_time * 1.4

func _find_target() -> Node:
	var best: Node = null
	var best_dist := range_radius
	for t in get_tree().get_nodes_in_group("tanks"):
		if t == owner_tank or not is_instance_valid(t):
			continue
		var d := global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best

func _fire(target: Node) -> void:
	var b := bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	var dir := (target.global_position - global_position).normalized()
	b.setup({
		"owner": owner_tank,
		"damage": owner_tank.bullet_damage * 0.7,
		"speed": owner_tank.bullet_speed * 0.9,
		"direction": dir,
		"size": 7.0,
		"color": owner_tank.def.color,
	})
