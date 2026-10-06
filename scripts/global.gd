extends Node

var lives := 3
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
		
