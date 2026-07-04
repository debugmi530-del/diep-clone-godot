extends Node
class_name BotBrain
## Utility-based AI for bot tanks. Each physics tick it scores a handful of
## behaviours (farm shapes, hunt a weaker enemy, flee a stronger one, duel a
## similar-strength enemy, wander) against the current situation and commits
## to whichever scores highest, then translates that behaviour into the same
## move_vector / aim_vector / firing flags a human would produce. Scores are
## smoothed and behaviours "stick" for a short time so bots don't flicker
## between decisions every frame, which is what actually reads as "human"
## rather than as a simple finite-state loop.

enum Behavior { FARM, HUNT, FLEE, DUEL, WANDER, COLLECT_STATS }

var tank: TankController
var current_behavior: int = Behavior.WANDER
var behavior_lock_time: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var think_timer: float = 0.0
var personality_aggression: float = 0.5 # 0..1, randomized per bot
var personality_caution: float = 0.5
var personality_greed: float = 0.5
var last_target: Node = null
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO

const THINK_INTERVAL := 0.35
const VISION_RANGE := 1400.0
const FARM_RANGE := 1000.0
const FLEE_HEALTH_RATIO := 0.35

func setup(owner_tank: TankController) -> void:
	tank = owner_tank
	personality_aggression = randf_range(0.15, 0.95)
	personality_caution = randf_range(0.15, 0.95)
	personality_greed = randf_range(0.15, 0.95)
	wander_target = tank.global_position

func _physics_process(delta: float) -> void:
	if tank == null or not is_instance_valid(tank):
		return
	think_timer -= delta
	behavior_lock_time -= delta
	if think_timer <= 0.0:
		think_timer = THINK_INTERVAL
		_think()
	_act(delta)
	_unstick_check(delta)

func _think() -> void:
	if behavior_lock_time > 0.0:
		return # currently committed to a behavior, don't re-evaluate yet

	var nearest_enemy := _find_nearest_enemy()
	var nearest_shape := _find_nearest_shape()

	var scores := {}
	scores[Behavior.WANDER] = 0.2

	if nearest_shape != null:
		var dist_factor: float = 1.0 - clamp(tank.global_position.distance_to(nearest_shape.global_position) / FARM_RANGE, 0.0, 1.0)
		scores[Behavior.FARM] = 0.4 + dist_factor * 0.5 + personality_greed * 0.3

	if nearest_enemy != null:
		var health_ratio: float = tank.health / max(1.0, nearest_enemy.health)
		var power_ratio: float = _estimate_power(tank) / max(1.0, _estimate_power(nearest_enemy))
		var dist: float = tank.global_position.distance_to(nearest_enemy.global_position)
		var closeness: float = 1.0 - clamp(dist / VISION_RANGE, 0.0, 1.0)

		if tank.health / tank.max_health < FLEE_HEALTH_RATIO and power_ratio < 1.1:
			scores[Behavior.FLEE] = 0.9 + (1.0 - power_ratio) * 0.5 + personality_caution * 0.4
		if power_ratio > 1.25:
			scores[Behavior.HUNT] = 0.5 + closeness * 0.4 + personality_aggression * 0.5
		elif power_ratio > 0.75:
			scores[Behavior.DUEL] = 0.35 + closeness * 0.3 + personality_aggression * 0.3
		else:
			scores[Behavior.FLEE] = max(scores.get(Behavior.FLEE, 0.0), 0.4 + closeness * 0.3 + personality_caution * 0.3)

	if tank.stat_points_available > 0:
		scores[Behavior.COLLECT_STATS] = 1.5 # always prioritize spending points immediately

	var best_behavior := Behavior.WANDER
	var best_score := -INF
	for b in scores.keys():
		if scores[b] > best_score:
			best_score = scores[b]
			best_behavior = b

	if best_behavior != current_behavior:
		current_behavior = best_behavior
		behavior_lock_time = randf_range(0.8, 2.2)
	last_target = nearest_enemy

func _act(delta: float) -> void:
	match current_behavior:
		Behavior.COLLECT_STATS:
			_spend_stat_points()
			current_behavior = Behavior.WANDER
		Behavior.FARM:
			_act_farm()
		Behavior.HUNT:
			_act_hunt()
		Behavior.DUEL:
			_act_duel()
		Behavior.FLEE:
			_act_flee()
		_:
			_act_wander(delta)

func _spend_stat_points() -> void:
	# Bots weight stat choices by their personality so different bots build
	# their tank differently, another source of human-feeling variety.
	var weighted := [
		["body_damage", personality_aggression],
		["bullet_damage", personality_aggression],
		["movement_speed", personality_caution],
		["health", personality_caution],
		["reload", personality_aggression * 0.7 + 0.3],
		["bullet_speed", 0.4],
		["health_regen", personality_greed * 0.5 + 0.2],
	]
	weighted.shuffle()
	weighted.sort_custom(func(a, b): return a[1] > b[1])
	while tank.stat_points_available > 0:
		var progressed := false
		for pair in weighted:
			if tank.upgrade_stat(pair[0]):
				progressed = true
				break
		if not progressed:
			break
	_maybe_evolve()

func _maybe_evolve() -> void:
	var children: Array = TankDatabase.get_children(tank.def.id)
	if children.is_empty():
		return
	var needed_level: int = 0
	if tank.tier == 1:
		needed_level = GameConfig.TIER_LEVEL_THRESHOLDS[2]
	elif tank.tier == 2:
		needed_level = GameConfig.TIER_LEVEL_THRESHOLDS[3]
	elif tank.tier == 3:
		needed_level = GameConfig.TIER_LEVEL_THRESHOLDS[4]
	elif tank.tier == 4:
		needed_level = GameConfig.TIER_LEVEL_THRESHOLDS[5]
	else:
		return
	if tank.level >= needed_level:
		var choice: String = children[randi() % children.size()]
		tank.evolve_to(choice)

func _act_farm() -> void:
	var shape := _find_nearest_shape()
	if shape == null:
		_act_wander(0.016)
		return
	var to_shape: Vector2 = shape.global_position - tank.global_position
	tank.move_vector = to_shape.normalized()
	tank.aim_vector = to_shape.normalized()
	tank.firing_primary = to_shape.length() < 700.0

func _act_hunt() -> void:
	if last_target == null or not is_instance_valid(last_target):
		_act_wander(0.016)
		return
	var to_target: Vector2 = last_target.global_position - tank.global_position
	tank.move_vector = to_target.normalized()
	tank.aim_vector = to_target.normalized()
	tank.firing_primary = to_target.length() < 900.0

func _act_duel() -> void:
	if last_target == null or not is_instance_valid(last_target):
		_act_wander(0.016)
		return
	var to_target: Vector2 = last_target.global_position - tank.global_position
	var dist := to_target.length()
	var ideal_range: float = 500.0
	# Strafe around the ideal range rather than walking straight in, which
	# reads much more like a player kiting than a simple chase-and-shoot bot.
	var radial: Vector2 = to_target.normalized() * clamp(dist - ideal_range, -1.0, 1.0)
	var tangent: Vector2 = to_target.normalized().rotated(PI / 2.0) * (1.0 if int(Time.get_ticks_msec() / 900) % 2 == 0 else -1.0)
	tank.move_vector = (radial + tangent).normalized()
	tank.aim_vector = to_target.normalized()
	tank.firing_primary = dist < 950.0

func _act_flee() -> void:
	if last_target == null or not is_instance_valid(last_target):
		_act_wander(0.016)
		return
	var away: Vector2 = tank.global_position - last_target.global_position
	tank.move_vector = away.normalized()
	tank.aim_vector = away.normalized() # face away so we can still fire covering shots
	tank.firing_primary = tank.def.weapon_class in ["sniper", "machinegun", "rocket"]

func _act_wander(delta: float) -> void:
	if tank.global_position.distance_to(wander_target) < 150.0 or randf() < 0.002:
		wander_target = tank.global_position + Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(400, 1400)
		wander_target = wander_target.clamp(Vector2(-GameConfig.WORLD_SIZE/2, -GameConfig.WORLD_SIZE/2), Vector2(GameConfig.WORLD_SIZE/2, GameConfig.WORLD_SIZE/2))
	var to_target: Vector2 = wander_target - tank.global_position
	tank.move_vector = to_target.normalized()
	tank.aim_vector = to_target.normalized()
	tank.firing_primary = false

func _unstick_check(delta: float) -> void:
	if tank.global_position.distance_to(last_position) < 4.0 and tank.move_vector.length() > 0.1:
		stuck_timer += delta
		if stuck_timer > 1.2:
			wander_target = tank.global_position + Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * 600.0
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	last_position = tank.global_position

func _find_nearest_enemy() -> Node:
	var best: Node = null
	var best_dist := VISION_RANGE
	for t in tank.get_tree().get_nodes_in_group("tanks"):
		if t == tank or not is_instance_valid(t):
			continue
		var d: float = tank.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best

func _find_nearest_shape() -> Node:
	var best: Node = null
	var best_dist := FARM_RANGE
	for s in tank.get_tree().get_nodes_in_group("shapes"):
		if not is_instance_valid(s):
			continue
		var d: float = tank.global_position.distance_to(s.global_position)
		if d < best_dist:
			best_dist = d
			best = s
	return best

func _estimate_power(t: Node) -> float:
	return t.max_health + t.body_damage * 3.0 + t.bullet_damage * 2.0 + t.level * 5.0
