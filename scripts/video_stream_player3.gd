extends VideoStreamPlayer

func _ready() -> void:
	play()
	finished.connect(_on_video_finished)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_on_video_finished()

func _on_video_finished() -> void:
	var next_level_path = "res://scenes/L5_1.tscn" 
	
	if ResourceLoader.exists(next_level_path):
		get_tree().change_scene_to_file(next_level_path)
	else:
		push_error("Could not find L5_1! Check the file path.")
