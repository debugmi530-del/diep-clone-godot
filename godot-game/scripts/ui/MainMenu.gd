extends Control

@onready var nickname_field: LineEdit = $CenterBox/NicknameField
@onready var play_button: Button = $CenterBox/PlayButton
@onready var settings_button: Button = $CenterBox/SettingsButton
@onready var tree_button: Button = $CenterBox/TreeButton
@onready var constructor_button: Button = $CenterBox/ConstructorButton
@onready var title_label: Label = $Title

func _ready() -> void:
	nickname_field.text = SaveSystem.nickname
	nickname_field.text_changed.connect(_on_nickname_changed)
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	tree_button.pressed.connect(_on_tree_pressed)
	constructor_button.pressed.connect(_on_constructor_pressed)

func _on_nickname_changed(new_text: String) -> void:
	SaveSystem.set_nickname(new_text)

func _on_play_pressed() -> void:
	RunState.player_start_tank_id = "root"
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_tree_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TierTreeView.tscn")

func _on_constructor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TankConstructor.tscn")
