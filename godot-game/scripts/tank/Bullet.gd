extends RigidBody2D
## Generic projectile used by every weapon class (bullets, shotgun pellets,
## machinegun rounds, rockets, drone/turret shots). Behaviour differences
## between classes come from the parameters passed in `setup()`, not from
## separate scripts, since a "bullet" is fundamentally the same object.

var damage: float = 10.0
var owner_tank: Node = null
var lifetime: float = 1.4
var homing_target: Node = null
var homing_strength: float = 0.0
var _age: float = 0.0

@onready var polygon: Polygon2D = $Polygon2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func setup(p: Dictionary) -> void:
	owner_tank = p.get("owner", null)
	damage = p.get("damage", 10.0)
	var speed: float = p.get("speed", 900.0)
	var direction: Vector2 = p.get("direction", Vector2.RIGHT)
	var size: float = p.get("size", 10.0)
	var color: Color = p.get("color", GameConfig.COLOR_BULLET)
	lifetime = p.get("lifetime", 1.4)
	homing_strength = p.get("homing_strength", 0.0)

	gravity_scale = 0
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	mass = max(0.05, pow(size / 10.0, 2.0) * 0.3)

	var shape := CircleShape2D.new()
	shape.radius = size
	collision.shape = shape
	polygon.polygon = _circle_points(size, 12)
	polygon.color = color

	linear_velocity = direction.normalized() * speed
	rotation = direction.angle()

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if homing_strength > 0.0 and homing_target != null and is_instance_valid(homing_target):
		var desired := (homing_target.global_position - global_position).normalized()
		var current := linear_velocity.normalized()
		var blended := current.lerp(desired, homing_strength * delta * 2.0).normalized()
		linear_velocity = blended * linear_velocity.length()

func _on_body_entered(body: Node) -> void:
	if body == owner_tank:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
	queue_free()
