extends AnimatableBody2D

@onready var anim = $AnimationPlayer

func _ready():
	# Replace "move" with the exact name of your animation
	anim.play("move2")
