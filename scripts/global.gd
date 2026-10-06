extends Node

const MAX_LIVES := 9
var lives := MAX_LIVES
var checkpoint_position := Vector2.ZERO
var checkpoint_scene := ""
var has_checkpoint := false

# NEW: 15 minutes represented in seconds
var time_left: float = 15.0 * 60.0 

func _process(delta: float) -> void:
	if time_left > 0:
		time_left -= delta
	else:
		time_left = 0.0
		# Optional: Trigger a game over or penalty here when time runs out
		

func reset_game() -> void:
	lives = MAX_LIVES
	has_checkpoint = false
	checkpoint_position = Vector2.ZERO
	checkpoint_scene = ""
	time_left = 15.0 * 60.0
