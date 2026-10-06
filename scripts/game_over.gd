extends CanvasLayer

# >>> If your first level scene is a different file, change this path. <<<
# (Right-click the scene in the FileSystem dock -> "Copy Path", paste it here.)
const FIRST_SCENE := "res://scenes/L1_1.tscn"

# Drag these in from the Inspector after opening game_over.tscn
@export var game_over_image: Texture2D
@export var game_over_sound: AudioStream

var _can_restart := false
var _restarting := false
var _prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Layout: picture on top, prompt underneath
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 20
	box.offset_bottom = -20
	box.modulate.a = 0.0
	add_child(box)

	var pic := TextureRect.new()
	pic.texture = game_over_image
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(pic)

	_prompt = Label.new()
	_prompt.text = "Press SPACE to restart"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.modulate.a = 0.0
	box.add_child(_prompt)

	# Sound
	if game_over_sound:
		var sfx := AudioStreamPlayer.new()
		sfx.stream = game_over_sound
		add_child(sfx)
		sfx.play()

	# Fade the picture in, then show the prompt and allow restarting
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 1.0)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func(): _can_restart = true)
	# Blink the prompt forever after that
	tween.finished.connect(_start_blink)


func _start_blink() -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(_prompt, "modulate:a", 0.3, 0.7)
	blink.tween_property(_prompt, "modulate:a", 1.0, 0.7)


func _input(event: InputEvent) -> void:
	if not _can_restart or _restarting:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_restarting = true
		get_viewport().set_input_as_handled()
		_restart()


func _restart() -> void:
	Global.reset_game()
	get_tree().change_scene_to_file(FIRST_SCENE)
