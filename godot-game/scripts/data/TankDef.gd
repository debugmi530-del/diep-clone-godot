extends Resource
class_name TankDef
## Definition of a tank "type" in the tree (built-in or player-made in the
## constructor). This is intentionally a plain data object (not a scene) so
## both built-in tanks and constructor-made tanks share one representation.

@export var id: String = ""
@export var display_name: String = "Tank"
@export var tier: int = 1 # 1..6, matches GameConfig.TIER_COLORS
@export var parent_id: String = "" # id of the tank this evolves from, "" = root
@export var weapon_class: String = "normal" # see classes/ folder for valid keys
@export var barrel_count: int = 1
@export var barrel_size: float = 1.0 # relative scale of barrel length/width
@export var body_size: float = 1.0 # relative scale of the tank body
@export var color: Color = Color("00b2e1")
@export var is_custom: bool = false

# Base stats before player stat-upgrades are applied. These represent the
# tank *shape's* innate identity (e.g. sniper has low fire rate baseline,
# high damage baseline) independent from the 7 upgradeable stats.
@export var base_reload: float = 1.0
@export var base_movement_speed: float = 1.0
@export var base_bullet_speed: float = 1.0
@export var base_bullet_damage: float = 1.0
@export var base_body_damage: float = 1.0
@export var base_health: float = 1.0
@export var base_health_regen: float = 1.0

# Class-specific extra parameters (e.g. drone count, mine count, homing
# strength, spread angle). Stored generically so the constructor UI and the
# weapon-class scripts can share one schema without every class needing its
# own Resource subclass.
@export var extra_params: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"tier": tier,
		"parent_id": parent_id,
		"weapon_class": weapon_class,
		"barrel_count": barrel_count,
		"barrel_size": barrel_size,
		"body_size": body_size,
		"color": color.to_html(false),
		"is_custom": is_custom,
		"base_reload": base_reload,
		"base_movement_speed": base_movement_speed,
		"base_bullet_speed": base_bullet_speed,
		"base_bullet_damage": base_bullet_damage,
		"base_body_damage": base_body_damage,
		"base_health": base_health,
		"base_health_regen": base_health_regen,
		"extra_params": extra_params,
	}

static func from_dict(d: Dictionary) -> TankDef:
	var t := TankDef.new()
	t.id = d.get("id", "")
	t.display_name = d.get("display_name", "Tank")
	t.tier = int(d.get("tier", 1))
	t.parent_id = d.get("parent_id", "")
	t.weapon_class = d.get("weapon_class", "normal")
	t.barrel_count = int(d.get("barrel_count", 1))
	t.barrel_size = float(d.get("barrel_size", 1.0))
	t.body_size = float(d.get("body_size", 1.0))
	t.color = Color(d.get("color", "00b2e1"))
	t.is_custom = bool(d.get("is_custom", false))
	t.base_reload = float(d.get("base_reload", 1.0))
	t.base_movement_speed = float(d.get("base_movement_speed", 1.0))
	t.base_bullet_speed = float(d.get("base_bullet_speed", 1.0))
	t.base_bullet_damage = float(d.get("base_bullet_damage", 1.0))
	t.base_body_damage = float(d.get("base_body_damage", 1.0))
	t.base_health = float(d.get("base_health", 1.0))
	t.base_health_regen = float(d.get("base_health_regen", 1.0))
	t.extra_params = d.get("extra_params", {})
	return t
