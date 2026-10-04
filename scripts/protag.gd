extends CharacterBody2D

const SPEED = 130.0
const DASH_SPEED_MULTIPLIER = 2.5
const JUMP_VELOCITY = -360.0

const DASH_DURATION = 0.25 
const DASH_COOLDOWN = 1.0  

var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var is_dashing := false
var dash_direction := 1.0 

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity (Modified: disabled while dashing)
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta

	# Handle jump (Modified: optional, prevents jumping mid-dash)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_dashing:
		velocity.y = JUMP_VELOCITY
		
	# Manage Dash Timers
	if dash_time_left > 0:
		dash_time_left -= delta
	else:
		is_dashing = false
		
	if dash_cooldown_left > 0:
		dash_cooldown_left -= delta

	# Get standard input direction
	var direction := Input.get_axis("move_left", "move_right")
	
	# Trigger dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0:
		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown_left = DASH_COOLDOWN
		dash_direction = -1.0 if animated_sprite.flip_h else 1.0
		
	# Flip sprite visually 
	if direction > 0 and not is_dashing:
		animated_sprite.flip_h = false
	elif direction < 0 and not is_dashing:
		animated_sprite.flip_h = true
		
	# Apply movement and animations
	if is_dashing:
		velocity.x = dash_direction * SPEED * DASH_SPEED_MULTIPLIER
		velocity.y = 0 # Cancel out vertical velocity for a straight horizontal dash
		animated_sprite.play("dash")
	else:
		# Handle normal movement physics
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			
		# Handle normal animations
		if not is_on_floor():
			animated_sprite.play("hop")
		elif direction != 0:
			animated_sprite.play("run") # Change to match your run animation
		else:
			animated_sprite.play("idle_bop")

	move_and_slide()
