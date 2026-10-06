extends Area2D

@export_file("*.tscn") var manual_override_path: String

# How long the fade-to-black takes in seconds
@export var fade_duration: float = 0.2
 

var is_transitioning: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Protag" and not is_transitioning:
		is_transitioning = true
		
		# Reset the global checkpoint so the new level establishes its own origin
		Global.has_checkpoint = false
		
		# 1. Universally generate a fade screen over the entire game
		var canvas = CanvasLayer.new()
		canvas.layer = 105 # Draws higher than the player's layer (100)
		add_child(canvas)
		
		var fade = ColorRect.new()
		fade.color = Color(0, 0, 0, 0) # Start transparent
		fade.set_anchors_preset(Control.PRESET_FULL_RECT) # Stretch to screen
		canvas.add_child(fade)
		
		# 2. Tween the screen to solid black
		var tween = create_tween()
		tween.tween_property(fade, "color:a", 1.0, fade_duration)
		
		# Wait for the fade animation to complete
		await tween.finished
		
		# 3. Change the scene while the screen is completely black
		if manual_override_path != "":
			get_tree().change_scene_to_file(manual_override_path)
			return
			
		_load_next_sequential_level()

func _load_next_sequential_level() -> void:
	var current_path = get_tree().current_scene.scene_file_path
	var base_dir = current_path.get_base_dir()
	var current_file = current_path.get_file().get_basename() 
	
	var parts = current_file.split("_")
	if parts.size() < 2:
		push_error("Current scene name does not match the L#_# format.")
		return
		
	var current_level = parts[0].trim_prefix("L").to_int()
	var current_scene = parts[1].to_int()
	
	# Try the next scene in the same level
	var next_scene_name = "L" + str(current_level) + "_" + str(current_scene + 1) + ".tscn"
	var next_scene_path = base_dir + "/" + next_scene_name
	
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
		return
		
	# If that doesn't exist, try the first scene of the next level
	var next_level_name = "L" + str(current_level + 1) + "_1.tscn"
	var next_level_path = base_dir + "/" + next_level_name
	
	if ResourceLoader.exists(next_level_path):
		get_tree().change_scene_to_file(next_level_path)
		return
		
	push_error("Could not find the next sequential scene! You might have reached the end of the game.")
