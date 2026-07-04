extends Node
## Global tunable constants for the whole game.
## Central place so balance changes don't require hunting through scenes.

# --- World ---
const WORLD_SIZE: float = 22000.0 # width/height of the square arena in pixels
const MAX_SHAPES: int = 2000 # lowered from the original 40000 design target for playable performance
const MAX_BOTS: int = 49
const TOTAL_PLAYERS: int = MAX_BOTS + 1

# Minimum center-to-center distance enforced between newly spawned shapes so
# they don't stack directly on top of each other.
const SHAPE_MIN_SPACING: float = 90.0

# Only bodies within this radius of any player/bot get full physics processing.
# Shapes outside this radius are frozen (still exist, just don't simulate) so
# that thousands of bodies don't bring physics to a halt. This is a
# performance safeguard, not a gameplay rule — nothing outside this radius is
# "deleted".
const ACTIVE_PHYSICS_RADIUS: float = 3200.0

# --- Leveling ---
const MAX_LEVEL: int = 50
const TIER_LEVEL_THRESHOLDS := {
        1: 0,
        2: 10,
        3: 20,
        4: 30,
        5: 50,
}
const STAT_MAX_POINTS: int = 10 # points per stat, 1 level = 1 point
const STAT_COUNT: int = 7 # health, healthRegen, bodyDamage, bulletSpeed, bulletPenetration/damage, reload, movementSpeed

# --- Physics tuning ---
const TANK_LINEAR_DAMP: float = 3.2
const TANK_ANGULAR_DAMP: float = 6.0
const SHAPE_LINEAR_DAMP: float = 1.4
const SHAPE_ANGULAR_DAMP: float = 2.0
const KNOCKBACK_FORCE_SCALE: float = 900.0

# --- Colors (diep.io palette) ---
const COLOR_PLAYER_BLUE := Color("00b2e1")
const COLOR_ENEMY_RED := Color("f14e54")
const COLOR_BOT_TEAL := Color("00e1c8")
const COLOR_SQUARE := Color("fbc02d")
const COLOR_TRIANGLE := Color("fc7677")
const COLOR_PENTAGON := Color("768cfc")
const COLOR_PENTAGON_ALPHA := Color("fc76de")
const COLOR_CRASHER := Color("f14e54")
const COLOR_BULLET := Color("999999")
const COLOR_BACKGROUND := Color("14141e")
const COLOR_GRID := Color("1c1c28")

const TIER_COLORS := {
        1: Color("00b2e1"), # blue
        2: Color("4dd65c"), # green
        3: Color("f2d94e"), # yellow
        4: Color("f2984e"), # orange
        5: Color("e14e4e"), # red
        6: Color("b04ee1"), # purple (tier 6 / 243, user hadn't picked a color)
}

const TIER_UPGRADE_COUNT := {
        1: 1,
        2: 3,
        3: 9,
        4: 27,
        5: 81,
        6: 243,
}

func stat_names() -> Array:
        return [
                "health",
                "health_regen",
                "body_damage",
                "bullet_speed",
                "bullet_damage",
                "reload",
                "movement_speed",
        ]

func stat_display_name(stat_key: String) -> String:
        match stat_key:
                "health": return "Здоровье"
                "health_regen": return "Реген. здоровья"
                "body_damage": return "Урон тараном"
                "bullet_speed": return "Скорость снаряда"
                "bullet_damage": return "Урон снаряда"
                "reload": return "Скорострельность"
                "movement_speed": return "Скорость движения"
                _: return stat_key
