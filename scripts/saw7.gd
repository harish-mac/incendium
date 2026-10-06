extends AnimatableBody2D

@export var spin_speed: float = 800.0 
@onready var anim = $AnimationPlayer

func _ready():
	# Triggers your back-and-forth movement animation
	anim.play("move_saw")

func _physics_process(delta: float) -> void:
	# Constantly spins the visual sprite independent of the animation player
	if has_node("Sprite2D"):
		$Sprite2D.rotation_degrees += spin_speed * delta
