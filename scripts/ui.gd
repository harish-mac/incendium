extends CanvasLayer

@onready var fade: ColorRect = $Fade
@onready var timer_label: Label = $TimerLabel
@onready var idle_sprite: AnimatedSprite2D = $SpriteBox/Idlesprite
@onready var pause_button: BaseButton = $PauseButton
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: BaseButton = $PauseMenu/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_button: BaseButton = $PauseMenu/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade.color.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.visible = false

	pause_button.pressed.connect(toggle_pause)
	resume_button.pressed.connect(toggle_pause)
	quit_button.pressed.connect(func(): get_tree().quit())

	idle_sprite.play()

func _process(_delta: float) -> void:
	var minutes := int(Global.time_left / 60.0)
	var seconds := int(Global.time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.visible = paused
	if paused:
		resume_button.grab_focus()
