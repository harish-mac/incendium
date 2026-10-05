extends AnimatableBody2D

@export var spin_speed: float = 800.0 

func _physics_process(delta: float) -> void:
	# Constantly spins the visual sprite independent of the animation player
	if has_node("Sprite2D"):
		$Sprite2D.rotation_degrees += spin_speed * delta
