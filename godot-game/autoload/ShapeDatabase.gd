extends Node
## Defines the 4 square, 3 triangle and 9 polygon variants requested, each
## with its own damage/weight/hp/xp/size characteristics.

var shapes: Dictionary = {} # id -> ShapeDef
var square_ids: Array = []
var triangle_ids: Array = []
var polygon_ids: Array = []

func _ready() -> void:
	_build()

func _build() -> void:
	# --- Squares (4 variants): common farmable shape, low-mid everything. ---
	_add_square("square_small", "Малый квадрат", Color("fbc02d"), 26.0, 8.0, 6.0, 6.0)
	_add_square("square_normal", "Квадрат", Color("fbc02d"), 40.0, 10.0, 8.0, 10.0)
	_add_square("square_large", "Большой квадрат", Color("f5a623"), 58.0, 22.0, 14.0, 20.0)
	_add_square("square_alpha", "Альфа-квадрат", Color("f57c00"), 90.0, 80.0, 28.0, 60.0)

	# --- Triangles (3 variants): faster, higher body damage than squares. ---
	_add_triangle("triangle_small", "Малый треугольник", Color("fc7677"), 32.0, 20.0, 14.0, 15.0)
	_add_triangle("triangle_normal", "Треугольник", Color("fc7677"), 48.0, 30.0, 20.0, 25.0)
	_add_triangle("triangle_alpha", "Альфа-треугольник", Color("f2545b"), 110.0, 200.0, 45.0, 100.0)

	# --- Polygons (9 variants): pentagons and up, high value / high risk. ---
	_add_polygon("pentagon_small", "Малый пятиугольник", 5, Color("768cfc"), 45.0, 60.0, 22.0, 40.0)
	_add_polygon("pentagon_normal", "Пятиугольник", 5, Color("768cfc"), 65.0, 100.0, 30.0, 130.0)
	_add_polygon("pentagon_alpha", "Альфа-пятиугольник", 5, Color("fc76de"), 160.0, 3000.0, 60.0, 4000.0)
	_add_polygon("hexagon", "Шестиугольник", 6, Color("6cc5ff"), 70.0, 130.0, 32.0, 160.0)
	_add_polygon("heptagon", "Семиугольник", 7, Color("6cffb0"), 78.0, 160.0, 34.0, 200.0)
	_add_polygon("octagon", "Восьмиугольник", 8, Color("c76cff"), 86.0, 190.0, 36.0, 240.0)
	_add_polygon("nonagon", "Девятиугольник", 9, Color("ff6cc7"), 94.0, 220.0, 38.0, 280.0)
	_add_polygon("decagon", "Десятиугольник", 10, Color("ffde6c"), 102.0, 260.0, 40.0, 340.0)
	_add_polygon("crasher", "Крашер", 11, Color("f14e54"), 34.0, 14.0, 26.0, 12.0) # aggressive small polygon, chases tanks
	_add_polygon("guardian", "Страж", 12, Color("8c8c8c"), 200.0, 5000.0, 70.0, 6000.0) # rare boss-like polygon

	square_ids = ["square_small", "square_normal", "square_large", "square_alpha"]
	triangle_ids = ["triangle_small", "triangle_normal", "triangle_alpha"]
	polygon_ids = ["pentagon_small", "pentagon_normal", "pentagon_alpha", "hexagon", "heptagon", "octagon", "nonagon", "decagon", "crasher", "guardian"]

func _add_square(id: String, name: String, color: Color, size: float, hp: float, dmg: float, xp: float) -> void:
	shapes[id] = ShapeDef.make(id, name, 4, color, size, hp, dmg, xp)

func _add_triangle(id: String, name: String, color: Color, size: float, hp: float, dmg: float, xp: float) -> void:
	shapes[id] = ShapeDef.make(id, name, 3, color, size, hp, dmg, xp)

func _add_polygon(id: String, name: String, sides: int, color: Color, size: float, hp: float, dmg: float, xp: float) -> void:
	shapes[id] = ShapeDef.make(id, name, sides, color, size, hp, dmg, xp)

## Weighted random pick — squares are common, triangles less so, polygons rare.
func random_shape_id() -> String:
	var roll := randf()
	if roll < 0.72:
		return square_ids[randi() % square_ids.size()]
	elif roll < 0.93:
		return triangle_ids[randi() % triangle_ids.size()]
	else:
		return polygon_ids[randi() % polygon_ids.size()]

func get_shape(id: String) -> ShapeDef:
	return shapes.get(id, shapes["square_normal"])
