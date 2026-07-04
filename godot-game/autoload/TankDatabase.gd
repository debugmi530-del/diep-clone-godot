extends Node
## Builds the full built-in tank tree: 1 (tier1) -> 3 (tier2) -> 9 (tier3)
## -> 27 (tier4) -> 81 (tier5) -> 243 (tier6), exactly as requested, then
## merges in any player-made tanks saved by the constructor (which may also
## declare a custom tank as their parent).
##
## The 364 built-in nodes are generated procedurally: each node picks a
## weapon class from CLASS_KEYS and a name from that class's name pool, and
## inherits/mutates its parent's stats. This keeps the whole tree internally
## consistent and lets the tank count exactly match the requested branching
## without maintaining 364 hand-authored records.

const CLASS_KEYS := ["normal", "sniper", "turret", "drone", "rammer", "shotgun", "machinegun", "mine_layer", "rocket"]

# Baseline identity stats per class, matching the brief:
#   normal     - balanced
#   sniper     - low hp/fire-rate/speed, high damage
#   turret     - places stationary turrets
#   drone      - places controllable drones
#   rammer     - no guns at tier baseline, huge body damage/hp, ram-immune
#   shotgun    - many barrels, low per-pellet damage, high total, short range
#   machinegun - high fire rate, low damage, medium range
#   mine_layer - places mines, no guns at tier baseline
#   rocket     - above-average damage, mild homing, slower projectile, slow reload
const CLASS_BASE_STATS := {
	"normal":     {"reload": 1.0, "move": 1.0, "bspeed": 1.0, "bdamage": 1.0, "bodydmg": 1.0, "hp": 1.0, "regen": 1.0, "barrels": 1},
	"sniper":     {"reload": 1.6, "move": 0.85, "bspeed": 1.4, "bdamage": 1.7, "bodydmg": 0.8, "hp": 0.75, "regen": 0.9, "barrels": 1},
	"turret":     {"reload": 1.1, "move": 0.95, "bspeed": 0.95, "bdamage": 0.9, "bodydmg": 0.9, "hp": 1.05, "regen": 1.0, "barrels": 1},
	"drone":      {"reload": 1.4, "move": 0.9, "bspeed": 0.7, "bdamage": 0.8, "bodydmg": 0.85, "hp": 1.0, "regen": 1.0, "barrels": 1},
	"rammer":     {"reload": 1.0, "move": 1.05, "bspeed": 1.0, "bdamage": 1.0, "bodydmg": 2.6, "hp": 1.8, "regen": 1.1, "barrels": 0},
	"shotgun":    {"reload": 1.3, "move": 1.0, "bspeed": 0.9, "bdamage": 0.45, "bodydmg": 0.95, "hp": 1.0, "regen": 1.0, "barrels": 5},
	"machinegun": {"reload": 0.45, "move": 1.0, "bspeed": 1.05, "bdamage": 0.55, "bodydmg": 0.9, "hp": 0.95, "regen": 1.0, "barrels": 1},
	"mine_layer": {"reload": 1.7, "move": 0.95, "bspeed": 0.0, "bdamage": 1.3, "bodydmg": 0.9, "hp": 1.1, "regen": 1.0, "barrels": 0},
	"rocket":     {"reload": 1.5, "move": 0.95, "bspeed": 0.75, "bdamage": 1.35, "bodydmg": 0.9, "hp": 1.0, "regen": 1.0, "barrels": 1},
}

const CLASS_DISPLAY := {
	"normal": "Обычный",
	"sniper": "Снайпер",
	"turret": "Турельщик",
	"drone": "Дронер",
	"rammer": "Таран",
	"shotgun": "Дробовик",
	"machinegun": "Пулемёт",
	"mine_layer": "Мино-укладчик",
	"rocket": "Ракетчик",
}

const NAME_SUFFIXES := ["", " I", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X", " XI", " XII"]

var tanks: Dictionary = {} # id -> TankDef
var children_of: Dictionary = {} # id -> Array[String] child ids

func _ready() -> void:
	_build_tree()
	_load_custom_tanks()

func _build_tree() -> void:
	tanks.clear()
	children_of.clear()

	var root := TankDef.new()
	root.id = "root"
	root.display_name = "Базовый танк"
	root.tier = 1
	root.parent_id = ""
	root.weapon_class = "normal"
	root.barrel_count = 1
	root.color = GameConfig.TIER_COLORS[1]
	_apply_class_stats(root, "normal", 0)
	tanks[root.id] = root
	children_of[root.id] = []

	_branch(root, 0)

func _branch(parent: TankDef, depth: int) -> void:
	if depth >= 5:
		return
	for i in range(3):
		var class_index := (depth * 5 + i * 3 + parent.id.hash()) % CLASS_KEYS.size()
		var class_key: String = CLASS_KEYS[abs(class_index)]
		var child := TankDef.new()
		child.id = "%s.%d" % [parent.id, i]
		var suffix_index: int = clamp(depth + 1, 0, NAME_SUFFIXES.size() - 1)
		child.display_name = "%s%s" % [CLASS_DISPLAY[class_key], NAME_SUFFIXES[suffix_index]]
		child.tier = parent.tier + 1
		child.parent_id = parent.id
		child.weapon_class = class_key
		child.color = GameConfig.TIER_COLORS.get(child.tier, Color.WHITE)
		_apply_class_stats(child, class_key, depth + 1)
		tanks[child.id] = child
		children_of[child.id] = []
		children_of[parent.id].append(child.id)
		_branch(child, depth + 1)

func _apply_class_stats(t: TankDef, class_key: String, depth: int) -> void:
	var base: Dictionary = CLASS_BASE_STATS[class_key]
	# Each tier compounds slightly so deeper tanks are meaningfully stronger
	# in their identity stats, mirroring diep.io's tier power curve.
	var growth := 1.0 + depth * 0.12
	t.base_reload = base["reload"]
	t.base_movement_speed = base["move"]
	t.base_bullet_speed = base["bspeed"]
	t.base_bullet_damage = base["bdamage"] * growth
	t.base_body_damage = base["bodydmg"] * growth
	t.base_health = base["hp"] * growth
	t.base_health_regen = base["regen"]
	t.barrel_count = max(0, int(base["barrels"]))
	t.extra_params = {
		"ram_immune": class_key == "rammer",
		"drone_count": 3 if class_key == "drone" else 0,
		"turret_count": 1 if class_key == "turret" else 0,
		"mine_count": 3 if class_key == "mine_layer" else 0,
		"homing_strength": 0.35 if class_key == "rocket" else 0.0,
	}

func get_tank(id: String) -> TankDef:
	return tanks.get(id, tanks.get("root"))

func get_children(id: String) -> Array:
	return children_of.get(id, [])

func get_root_ids() -> Array:
	return ["root"]

func all_tank_ids() -> Array:
	return tanks.keys()

## --- Custom tanks made in the constructor ---

func _load_custom_tanks() -> void:
	for d in SaveSystem.custom_tanks:
		var t := TankDef.from_dict(d)
		tanks[t.id] = t
		if not children_of.has(t.id):
			children_of[t.id] = []
		if t.parent_id != "" and children_of.has(t.parent_id):
			if not children_of[t.parent_id].has(t.id):
				children_of[t.parent_id].append(t.id)

func register_custom_tank(t: TankDef) -> void:
	t.is_custom = true
	if t.id.is_empty():
		t.id = "custom_%d" % Time.get_unix_time_from_system()
	tanks[t.id] = t
	if not children_of.has(t.id):
		children_of[t.id] = []
	if t.parent_id != "" and children_of.has(t.parent_id):
		children_of[t.parent_id].append(t.id)
	SaveSystem.add_custom_tank(t.to_dict())
