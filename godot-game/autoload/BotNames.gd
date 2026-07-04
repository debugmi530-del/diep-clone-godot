extends Node
## Loads the 500-name pool used to name bots at match start.

const NAMES_PATH := "res://data/bot_names.json"

var names: Array = []

func _ready() -> void:
	_load_names()

func _load_names() -> void:
	if not FileAccess.file_exists(NAMES_PATH):
		push_warning("bot_names.json missing, using fallback names")
		for i in range(60):
			names.append("Bot%d" % i)
		return
	var f := FileAccess.open(NAMES_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_ARRAY:
		names = parsed
	else:
		push_warning("bot_names.json malformed, using fallback names")

## Returns `count` unique random names from the pool.
func get_random_names(count: int) -> Array:
	var pool := names.duplicate()
	pool.shuffle()
	if count > pool.size():
		count = pool.size()
	return pool.slice(0, count)
