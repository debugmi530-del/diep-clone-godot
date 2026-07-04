extends Resource
class_name ShapeDef
## Definition of one shape variant (4 squares, 3 triangles, 9 polygons).

@export var id: String = ""
@export var display_name: String = ""
@export var sides: int = 4 # 4 = square, 3 = triangle, 5+ = polygon variants
@export var color: Color = Color.WHITE
@export var size: float = 40.0 # base radius in pixels
@export var mass: float = 1.0 # derived from size, affects physics knockback
@export var health: float = 10.0
@export var body_damage: float = 8.0 # contact damage dealt to tanks
@export var xp_reward: float = 10.0
@export var spin_speed: float = 0.3 # idle rotation, purely visual/flavor

static func make(id_: String, name_: String, sides_: int, color_: Color, size_: float, health_: float, dmg_: float, xp_: float) -> ShapeDef:
	var s := ShapeDef.new()
	s.id = id_
	s.display_name = name_
	s.sides = sides_
	s.color = color_
	s.size = size_
	s.health = health_
	s.body_damage = dmg_
	s.xp_reward = xp_
	# Mass scales with area (size^2), like diep.io.
	s.mass = pow(size_ / 40.0, 2.0)
	return s
