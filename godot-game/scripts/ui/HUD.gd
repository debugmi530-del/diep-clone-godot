extends Control
## In-match UI: health/xp bars, stat upgrade buttons, tier evolution choices,
## the leaderboard panel, and the death screen.

var tank: TankController

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var xp_bar: ProgressBar = $HealthPanel/XPBar
@onready var level_label: Label = $HealthPanel/LevelLabel
@onready var score_label: Label = $HealthPanel/ScoreLabel
@onready var stat_box: VBoxContainer = $StatPanel/StatBox
@onready var evolve_box: HBoxContainer = $EvolvePanel/EvolveBox
@onready var leaderboard_box: VBoxContainer = $LeaderboardPanel/LeaderboardBox
@onready var death_panel: Control = $DeathPanel

var stat_buttons: Dictionary = {}

func setup(player_tank: TankController) -> void:
        tank = player_tank
        tank.leveled_up.connect(_on_leveled_up)
        tank.tier_changed.connect(_on_tier_changed)
        _build_stat_panel()
        _refresh_evolve_panel()
        death_panel.visible = false

func _process(_delta: float) -> void:
        if tank == null or not is_instance_valid(tank):
                return
        health_bar.max_value = tank.max_health
        health_bar.value = tank.health
        xp_bar.max_value = tank.xp_to_next
        xp_bar.value = tank.xp
        level_label.text = "Уровень %d" % tank.level
        score_label.text = "Очки: %d" % tank.score
        for stat_key in stat_buttons.keys():
                var btn: Button = stat_buttons[stat_key]
                var lvl: int = tank.stat_levels.get(stat_key, 0)
                btn.text = "%s (%d/%d)" % [GameConfig.stat_display_name(stat_key), lvl, GameConfig.STAT_MAX_POINTS]
                btn.disabled = tank.stat_points_available <= 0 or lvl >= GameConfig.STAT_MAX_POINTS

func _build_stat_panel() -> void:
        for child in stat_box.get_children():
                child.queue_free()
        stat_buttons.clear()
        for stat_key in GameConfig.stat_names():
                var btn := Button.new()
                btn.text = GameConfig.stat_display_name(stat_key)
                btn.pressed.connect(_on_stat_pressed.bind(stat_key))
                stat_box.add_child(btn)
                stat_buttons[stat_key] = btn

func _on_stat_pressed(stat_key: String) -> void:
        tank.upgrade_stat(stat_key)

func _on_leveled_up(_new_level: int) -> void:
        _refresh_evolve_panel()

func _on_tier_changed(_new_tier: int) -> void:
        _refresh_evolve_panel()

func _refresh_evolve_panel() -> void:
        for c in evolve_box.get_children():
                c.queue_free()
        if tank == null:
                return
        var children: Array = TankDatabase.get_children(tank.def.id)
        for child_id in children:
                var def: TankDef = TankDatabase.get_tank(child_id)
                var btn := Button.new()
                btn.text = def.display_name
                btn.pressed.connect(_on_evolve_pressed.bind(child_id))
                evolve_box.add_child(btn)

func _on_evolve_pressed(tank_id: String) -> void:
        tank.evolve_to(tank_id)
        _refresh_evolve_panel()

func update_leaderboard(snapshot: Array) -> void:
        for c in leaderboard_box.get_children():
                c.queue_free()
        var i := 1
        for entry in snapshot:
                var lbl := Label.new()
                lbl.text = "%d. %s — ур.%d (%d)" % [i, entry["name"], entry["level"], entry["score"]]
                if entry.get("is_player", false):
                        lbl.modulate = GameConfig.COLOR_PLAYER_BLUE
                leaderboard_box.add_child(lbl)
                i += 1

func show_death_screen() -> void:
        death_panel.visible = true

func _on_respawn_pressed() -> void:
        get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
        get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
