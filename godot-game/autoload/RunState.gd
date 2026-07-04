extends Node
## Carries state between scenes: which tank the player picked to start with
## (usually "root"), and match-wide bookkeeping used by the HUD/leaderboard.

var player_start_tank_id: String = "root"
var player_nickname: String = "Player"

## Populated by Game.gd once the match starts; read by the leaderboard UI.
## Array of Dictionary: {name, score, is_player}
var leaderboard_snapshot: Array = []

func reset_for_new_match() -> void:
	leaderboard_snapshot.clear()
