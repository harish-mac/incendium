extends CharacterBody2D

const SPEED = 130.0
const DASH_SPEED_MULTIPLIER = 2.5
const JUMP_VELOCITY = -360.0
const WALL_JUMP_PUSHBACK = 100.0 
const WALL_SLIDE_SPEED = 100.0 

const DASH_DURATION = 0.25 
const DASH_COOLDOWN = 0.7  
const WALL_JUMP_LOCK_TIME = 0.25 

var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var is_dashing := false
var dash_direction := 1.0 

var wall_jump_lock_left := 0.0 

var is_dead := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fade: ColorRect = $"../UI/Fade"

func _ready() -> void:
	fade.color.a = 0.0
	
	if not Global.has_checkpoint:
		Global.checkpoint_position = global_position
		Global.has_checkpoint = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Add the gravity
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta
		
		# Wall Slide Limit
		if is_on_wall() and velocity.y > 0:
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

	# MOVED: Get standard input direction early so the jump function can read it
	var direction := Input.get_axis("move_left", "move_right")

	# Handle Jump & Wall Jump
	if Input.is_action_just_pressed("jump") and not is_dashing:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			velocity.y = JUMP_VELOCITY
			
			# --- ZIG-ZAG LOGIC ---
			# get_wall_normal().x always points AWAY from the wall.
			# If you are holding the D-pad/key in that same direction, you want to leap across.
			if direction == sign(get_wall_normal().x):
				# Give a 50% stronger pushback to cross the gap, and cut the steering lock in half
				velocity.x = get_wall_normal().x * (WALL_JUMP_PUSHBACK * 1.5)
				wall_jump_lock_left = WALL_JUMP_LOCK_TIME * 0.5 
			else:
				# Standard vertical climb (holding towards the wall or neutral)
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
		animated_sprite.play("roll")
	else:
		# Standard horizontal steering (if not locked by wall jump)
		if wall_jump_lock_left <= 0:
			if direction:
				velocity.x = direction * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				
		# Visual Sprite Flipping
		if wall_jump_lock_left > 0:
			animated_sprite.flip_h = velocity.x < 0
		elif not is_on_wall() or is_on_floor():
			if direction > 0:
				animated_sprite.flip_h = false
			elif direction < 0:
				animated_sprite.flip_h = true
				
		# Handle Animations
		if not is_on_floor():
			if is_on_wall() and velocity.y > 0:
				animated_sprite.play("wall_slide")
				animated_sprite.flip_h = get_wall_normal().x > 0
			else:
				animated_sprite.play("hop")
		elif direction != 0:
			animated_sprite.play("run") 
		else:
			animated_sprite.play("idle_bop")

	move_and_slide()

func respawn() -> void:
	global_position = Global.checkpoint_position
	velocity = Vector2.ZERO
	animated_sprite.play("idle_bop")
	
	await get_tree().create_timer(0.15).timeout
	
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.4)
	await tween.finished
	
	is_dead = false

func game_over() -> void:
	print("GAME OVER")
	Global.lives = 3
	Global.has_checkpoint = false
	get_tree().reload_current_scene()

func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	Global.lives -= 1
	
	velocity = Vector2.ZERO
	
	print("Lives remaining: ", Global.lives)
	
	if Global.lives > 0:
		animated_sprite.play("death")
		await animated_sprite.animation_finished
		
		var tween := create_tween()
		tween.tween_property(fade, "color:a", 1.0, 0.4)
		await tween.finished
		
		await respawn()
		
	else:
		animated_sprite.play("death_final")
		await animated_sprite.animation_finished
		
		var tween := create_tween()
		tween.tween_property(fade, "color:a", 1.0, 0.4)
		await tween.finished
		
		game_over()
