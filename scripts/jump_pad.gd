extends Area2D

@export var bounce_force: float = -500.0 
@onready var sprite = $Sprite2D

var original_scale: Vector2
var is_active: bool = true

func _ready():
	original_scale = sprite.scale

func _on_body_entered(body):
	if body.name == "Protag" and is_active:
		# Lock the pad so it can't be triggered multiple times in a row
		is_active = false
		
		# Apply bounce and dash reset
		body.velocity.y = bounce_force
		if "dash_cooldown_left" in body:
			body.dash_cooldown_left = 0.0
			body.is_dashing = false
		
		# Animate squash, then instantly shrink it to 0 (invisible)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(original_scale.x * 1.3, original_scale.y * 0.4), 0.05)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.15)
		
		# Turn off the Area2D trigger and the solid StaticBody2D block
		set_deferred("monitoring", false)
		if has_node("StaticBody2D"):
			$StaticBody2D.process_mode = Node.PROCESS_MODE_DISABLED
			
		# Wait exactly 3 seconds 
		await get_tree().create_timer(3.0).timeout
		
		# Turn the physics and triggers back on
		if has_node("StaticBody2D"):
			$StaticBody2D.process_mode = Node.PROCESS_MODE_INHERIT
		set_deferred("monitoring", true)
		is_active = true
		
		# Pop the visual back to its original size with a springy animation
		var reform_tween = create_tween()
		reform_tween.tween_property(sprite, "scale", original_scale, 0.2).set_trans(Tween.TRANS_BOUNCE)
