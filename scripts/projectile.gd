class_name AngelProjectile
extends Area2D
## An UNESCAPABLE homing fireball. It only ends when it hits the player
## or the player dies.
## Scene tree needed:
##   Projectile (Area2D)  <- this script
##   ├─ AnimatedSprite2D  (the fire art)
##   └─ CollisionShape2D  (small circle over the bright part of the fire)

## Pixels per second. The player runs at 130 and dashes at ~325 in short
## bursts, so 210 outruns a dash-running player. Lower it to be kinder.
@export var speed: float = 165.0
## Higher = steers harder toward the player.
@export var turn_speed: float = 4.0
## Seconds before it fizzles out. 0 = never (unescapable).
@export var lifetime: float = 0.0
## Off = flies straight through walls so hiding doesn't work.
@export var destroy_on_walls: bool = false

# The angel fills these in when it spawns the fireball
var target: Node2D
var direction: Vector2 = Vector2.RIGHT

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.play()  # plays whichever animation is selected ("default")

	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		# Player already dead/respawning: the fireball is done
		if target.get("is_dead") == true:
			queue_free()
			return

		# Slowly rotate our direction toward the player = "homing"
		var wanted: Vector2 = (target.global_position - global_position).normalized()
		direction = direction.slerp(wanted, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

	global_position += direction * speed * delta

	# Fire art has its round body at the BOTTOM and the tail at the TOP.
	# This turns the fireball so the body leads and the tail trails behind.
	rotation = direction.angle() - PI / 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die()
		queue_free()
	elif destroy_on_walls:
		queue_free()
