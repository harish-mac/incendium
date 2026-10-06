extends Area2D

signal lever_toggled(is_on: bool)

@export var is_on: bool = false
var player_in_range: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# Updated paths to match your exact scene tree
@onready var label: Label = $Message_area/Label
@onready var message_area: Area2D = $Message_area

func _ready() -> void:
	if is_on:
		animated_sprite.play("lever_2")
	else:
		animated_sprite.play("lever_1")
	
	label.hide()
		
	# Connect the root area (the small interaction box)
	body_entered.connect(_on_interaction_entered)
	body_exited.connect(_on_interaction_exited)
	
	# Connect the new Message_area (the 50px circle)
	message_area.body_entered.connect(_on_message_entered)
	message_area.body_exited.connect(_on_message_exited)

# --- INTERACTION LOGIC (Small Box for toggling) ---
func _on_interaction_entered(body: Node2D) -> void:
	if body.is_in_group("player"): 
		player_in_range = true

func _on_interaction_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

# --- MESSAGE LOGIC (50px Circle for the text box) ---
func _on_message_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.show()

func _on_message_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.hide()

# --- INPUT HANDLING ---
func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("toggle_lever"): 
		toggle_lever()

func toggle_lever() -> void:
	is_on = !is_on
	lever_toggled.emit(is_on)
	
	if is_on:
		animated_sprite.play("lever_2")
	else:
		animated_sprite.play("lever_1")
