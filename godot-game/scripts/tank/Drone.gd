extends RigidBody2D
## Controllable drone placed by the drone-class tank. Follows the tank's aim
## direction loosely and attacks the nearest enemy, or returns to orbit the
## owner when recalled.

var owner_tank: TankController
var health: float = 20.0
var recall_point = null

@onready var polygon: Polygon2D = $Polygon2D

func setup(tank: TankController) -> void:
	owner_tank = tank
	health = 15.0 * tank.def.base_health
	gravity_scale = 0
	linear_damp = 2.0
	var pts := PackedVector2Array()
	for i in range(3):
		var a := TAU * i / 3 - PI / 2
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	polygon.polygon = pts
	polygon.color = tank.def.color
	var shape := ConvexPolygonShape2D.new()
	shape.points = pts
	$CollisionShape2D.shape = shape

func recall_to(point: Vector2) -> void:
	recall_point = point

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_tank):
		queue_free()
		return
	var target := _find_target()
	var goal: Vector2
	if recall_point != null:
		goal = recall_point
	elif target:
		goal = target.global_position
	else:
		goal = owner_tank.global_position + owner_tank.aim_vector * 220.0

	var dir := (goal - global_position)
	if dir.length() > 6.0:
		linear_velocity = linear_velocity.lerp(dir.normalized() * 420.0, delta * 4.0)
		rotation = dir.angle()

	if target and global_position.distance_to(target.global_position) < 220.0 and target.has_method("take_damage"):
		target.take_damage(owner_tank.bullet_damage * 0.4 * delta * 4.0, self)

func _find_target() -> Node:
	var best: Node = null
	var best_dist := 380.0
	for t in get_tree().get_nodes_in_group("tanks"):
		if t == owner_tank or not is_instance_valid(t):
			continue
		var d := global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best

func take_damage(amount: float, source = null) -> void:
	health -= amount
	if health <= 0:
		queue_free()
