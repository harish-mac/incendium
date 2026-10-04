extends Area2D

@export var bounce_force: float = -500.0 
@onready var sprite = $Sprite2D

# Create a variable to remember your custom editor size
var original_scale: Vector2

func _ready():
	# Save the exact scale as soon as the level loads
	original_scale = sprite.scale

func _on_body_entered(body):
	if body.name == "Protag":
		body.velocity.y = bounce_force
		
		if "dash_cooldown_left" in body:
			body.dash_cooldown_left = 0.0
			body.is_dashing = false
		
		var tween = create_tween()
		
		# Multiply your custom scale by the squash modifiers
		var squash_target = Vector2(original_scale.x * 1.3, original_scale.y * 0.4)
		
		# Animate to the squashed size
		tween.tween_property(sprite, "scale", squash_target, 0.05)
		
		# Rebound exactly back to your custom original scale
		tween.tween_property(sprite, "scale", original_scale, 0.15)
