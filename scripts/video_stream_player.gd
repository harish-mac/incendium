extends VideoStreamPlayer

func _ready() -> void:
	# Ensure the video starts playing automatically
	play()
	# Listen for when the video naturally ends
	finished.connect(_on_video_finished)

func _process(_delta: float) -> void:
	# Allow the player to press Spacebar/Enter to skip the intro
	if Input.is_action_just_pressed("ui_accept"):
		_on_video_finished()

func _on_video_finished() -> void:
	# Make sure this path exactly matches where L1_1 is saved in your FileSystem
	var first_level_path = "res://scenes/L1_1.tscn" 
	
	if ResourceLoader.exists(first_level_path):
		get_tree().change_scene_to_file(first_level_path)
	else:
		push_error("Could not find L1_1! Check the file path.")
