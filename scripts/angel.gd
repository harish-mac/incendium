class_name AngelEnemy
extends CharacterBody2D

@export_group("Patrol Settings")
@export var patrol_offset: Vector2 = Vector2(200, 0) # How far the angel travels from its spawn
@export var patrol_duration: float = 3.0             # Time it takes to reach the offset

@export_group("Hover Settings")
@export var hover_height: float = 15.0               # How high the sprite bobs up and down
@export var hover_duration: float = 1.0              # Speed of the bobbing motion

@onready var sprite: Sprite2D = $Sprite2D
@onready var vision_cone: Area2D = $VisionCone

var start_position: Vector2

func _ready() -> void:
	start_position = global_position
	
	_start_hover_effect()
	_start_patrol()
	
	# Connect the vision cone dynamically to detect the player
	if not vision_cone.body_entered.is_connected(_on_vision_cone_body_entered):
		vision_cone.body_entered.connect(_on_vision_cone_body_entered)

func _start_hover_effect() -> void:
	# Loops indefinitely to create a continuous floating illusion on the Sprite only
	var hover_tween = create_tween().set_loops()
	hover_tween.tween_property(sprite, "position:y", -hover_height, hover_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(sprite, "position:y", 0.0, hover_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_patrol() -> void:
	# Loops indefinitely to move the entire CharacterBody2D back and forth
	var patrol_tween = create_tween().set_loops()
	patrol_tween.tween_property(self, "global_position", start_position + patrol_offset, patrol_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	patrol_tween.tween_property(self, "global_position", start_position, patrol_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_vision_cone_body_entered(body: Node2D) -> void:
	# Checks if the colliding body belongs to the "player" group
	if body.is_in_group("player"):
		print("Angel spotted the player!")
		# TODO: Add logic to transition to a chase state, trigger an alarm, or attack
