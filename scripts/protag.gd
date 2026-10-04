extends CharacterBody2D

const SPEED = 130.0
const DASH_SPEED_MULTIPLIER = 2.5
const JUMP_VELOCITY = -360.0
const WALL_JUMP_PUSHBACK = 200.0 
const WALL_SLIDE_SPEED = 100.0 # NEW: The maximum falling speed when hugging a wall

const DASH_DURATION = 0.25 
const DASH_COOLDOWN = 1.0  
const WALL_JUMP_LOCK_TIME = 0.15 

var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var is_dashing := false
var dash_direction := 1.0 

var wall_jump_lock_left := 0.0 

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta
		
		# NEW: Wall Slide Limit
		# If touching a wall and falling downwards, clamp the speed
		if is_on_wall() and velocity.y > 0:
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

	# Handle Jump & Wall Jump
	if Input.is_action_just_pressed("jump") and not is_dashing:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			velocity.y = JUMP_VELOCITY
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSHBACK
			wall_jump_lock_left = WALL_JUMP_LOCK_TIME 
			
	# Manage Timers
	if dash_time_left > 0:
		dash_time_left -= delta
	else:
		is_dashing = false
		
	if dash_cooldown_left > 0:
		dash_cooldown_left -= delta
		
	if wall_jump_lock_left > 0:
		wall_jump_lock_left -= delta

	# Get standard input direction
	var direction := Input.get_axis("move_left", "move_right")
	
	# Trigger dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0:
		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown_left = DASH_COOLDOWN
		dash_direction = -1.0 if animated_sprite.flip_h else 1.0
		
	# Apply movement and animations
	if is_dashing:
		velocity.x = dash_direction * SPEED * DASH_SPEED_MULTIPLIER
		velocity.y = 0 
		animated_sprite.play("dash")
	else:
		# Standard horizontal steering (if not locked by wall jump)
		if wall_jump_lock_left <= 0:
			if direction:
				velocity.x = direction * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				
		# Visual Sprite Flipping (Disabled during wall slide to prevent flickering)
		if not is_on_wall() or is_on_floor():
			if direction > 0:
				animated_sprite.flip_h = false
			elif direction < 0:
				animated_sprite.flip_h = true
				
		# Handle Animations
		if not is_on_floor():
			if is_on_wall() and velocity.y > 0:
				animated_sprite.play("wall_slide")
				# Automatically flip the sprite to correctly cling to the wall
				animated_sprite.flip_h = get_wall_normal().x > 0
			else:
				animated_sprite.play("hop")
		elif direction != 0:
			animated_sprite.play("run") 
		else:
			animated_sprite.play("idle_bop")

	move_and_slide()
