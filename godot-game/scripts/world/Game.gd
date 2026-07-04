extends Node2D
## Root of the actual match: spawns the arena background, the shape field,
## the player tank and 49 bot tanks, wires up the camera and HUD, and keeps
## the leaderboard snapshot updated for the HUD to read.

var tank_scene: PackedScene = preload("res://scenes/Tank.tscn")
var player_tank: TankController
var all_tanks: Array = []

@onready var shape_spawner = $ShapeSpawner
@onready var camera: Camera2D = $PlayerCamera
@onready var hud = $HUDLayer/HUD
@onready var background: Node2D = $Background

func _ready() -> void:
	RunState.reset_for_new_match()
	_build_background()
	_spawn_player()
	_spawn_bots()
	hud.setup(player_tank)
	_start_leaderboard_timer()

func _build_background() -> void:
	var border := Line2D.new()
	var half := GameConfig.WORLD_SIZE / 2.0
	border.points = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half), Vector2(-half, -half)
	])
	border.width = 12.0
	border.default_color = Color("3a3a4a")
	background.add_child(border)

func _spawn_player() -> void:
	player_tank = tank_scene.instantiate()
	player_tank.is_player = true
	player_tank.nickname = SaveSystem.nickname
	player_tank.tank_def_id = RunState.player_start_tank_id
	player_tank.position = Vector2.ZERO
	add_child(player_tank)
	player_tank.add_to_group("player")
	all_tanks.append(player_tank)
	player_tank.died.connect(_on_player_died)
	camera.reparent(player_tank)
	camera.position = Vector2.ZERO

func _spawn_bots() -> void:
	var names: Array = BotNames.get_random_names(GameConfig.MAX_BOTS)
	for i in range(GameConfig.MAX_BOTS):
		var bot := tank_scene.instantiate()
		bot.is_player = false
		bot.nickname = names[i] if i < names.size() else "Bot%d" % i
		bot.tank_def_id = "root"
		bot.position = Vector2(
			randf_range(-GameConfig.WORLD_SIZE / 2.0, GameConfig.WORLD_SIZE / 2.0),
			randf_range(-GameConfig.WORLD_SIZE / 2.0, GameConfig.WORLD_SIZE / 2.0)
		)
		add_child(bot)
		bot.add_to_group("bots")
		all_tanks.append(bot)
		var brain := BotBrain.new()
		bot.add_child(brain)
		brain.setup(bot)
		bot.died.connect(_on_bot_died.bind(bot))

func _on_bot_died(_killer, bot) -> void:
	all_tanks.erase(bot)
	# Respawn a fresh bot elsewhere after a short delay to keep the arena
	# populated with 49 bots for the whole match.
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(player_tank):
		return
	var new_bot := tank_scene.instantiate()
	new_bot.is_player = false
	new_bot.nickname = BotNames.get_random_names(1)[0]
	new_bot.tank_def_id = "root"
	new_bot.position = Vector2(
		randf_range(-GameConfig.WORLD_SIZE / 2.0, GameConfig.WORLD_SIZE / 2.0),
		randf_range(-GameConfig.WORLD_SIZE / 2.0, GameConfig.WORLD_SIZE / 2.0)
	)
	add_child(new_bot)
	new_bot.add_to_group("bots")
	all_tanks.append(new_bot)
	var brain := BotBrain.new()
	new_bot.add_child(brain)
	brain.setup(new_bot)
	new_bot.died.connect(_on_bot_died.bind(new_bot))

func _on_player_died(_killer) -> void:
	hud.show_death_screen()

func _start_leaderboard_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_leaderboard)
	add_child(timer)

func _update_leaderboard() -> void:
	all_tanks = all_tanks.filter(func(t): return is_instance_valid(t))
	var sorted_tanks := all_tanks.duplicate()
	sorted_tanks.sort_custom(func(a, b): return a.score > b.score)
	var top := sorted_tanks.slice(0, min(10, sorted_tanks.size()))
	var snapshot := []
	for t in top:
		snapshot.append({"name": t.nickname, "score": t.score, "level": t.level, "is_player": t.is_player})
	RunState.leaderboard_snapshot = snapshot
	hud.update_leaderboard(snapshot)
