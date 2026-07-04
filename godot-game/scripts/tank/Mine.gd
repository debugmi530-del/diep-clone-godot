extends Area2D
## Stationary mine dropped by the mine-layer class. Arms after a short delay
## (so the layer can move away) then detonates on contact.

var damage: float = 20.0
var owner_tank: Node = null
var armed: bool = false
var lifetime: float = 14.0

@onready var polygon: Polygon2D = $Polygon2D

func setup(p: Dictionary) -> void:
	owner_tank = p.get("owner", null)
	damage = p.get("damage", 20.0)
	var pts := PackedVector2Array()
	for i in range(6):
		var a := TAU * i / 6
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	polygon.polygon = pts
	polygon.color = Color("444444")
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	$CollisionShape2D.shape = shape
	await get_tree().create_timer(0.6).timeout
	armed = true
	polygon.color = Color("222222")

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not armed or body == owner_tank:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
	_explode()

func _explode() -> void:
	for body in get_tree().get_nodes_in_group("tanks"):
		if body == owner_tank:
			continue
		if body.global_position.distance_to(global_position) < 70.0 and body.has_method("take_damage"):
			body.take_damage(damage * 0.5, self)
	queue_free()
