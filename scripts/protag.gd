extends CharacterBody2D

@export_group("Run")
@export var max_speed := 130.0
@export var ground_accel := 1200.0
@export var ground_decel := 1400.0
@export var air_accel := 900.0
@export var air_decel := 500.0


@export_group("Jump")
## How high a full normal jump goes, in pixels.
@export var jump_height := 72.0

## Seconds to reach the top of a normal jump.
@export var jump_time_to_apex := 0.32

## How much upward velocity remains when jump is released.
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.4

## Extra gravity while falling.
@export var fall_gravity_multiplier := 1.3

## Gravity near the top while jump is held.
@export var apex_gravity_multiplier := 0.6

@export var apex_speed_threshold := 50.0
@export var max_fall_speed := 500.0

@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12


@export_group("Wall")
## Maximum downward speed while sliding on a wall.
@export var wall_slide_speed := 100.0

## How quickly fast falling is reduced to wall slide speed.
## Lower = smoother.
@export var wall_slide_friction := 900.0

## Horizontal kick away from the wall.
@export var wall_jump_pushback := 150.0

## Time after wall jump where horizontal steering is limited.
@export var wall_jump_lock_time := 0.10

## Grace period after leaving a wall.
@export var wall_coyote_time := 0.12

## Gravity while rising after a wall jump.
## Lower = floatier.
@export var wall_jump_gravity_multiplier := 0.65

## Gravity while falling after a wall jump.
@export var wall_jump_fall_gravity_multiplier := 0.85

## Horizontal control during the initial wall-jump lock.
@export var wall_jump_air_control := 0.75

## Nudges sprite toward wall while sliding.
@export var wall_cling_offset := 0.0


@export_group("Dash")
@export var dash_speed := 325.0
@export var dash_duration := 0.25
@export var dash_cooldown := 1.0


@export_group("Death")
@export var fade_time := 0.25
@export var black_hold_time := 0.35


# ============================================================
# STATE
# ============================================================

var facing := 1.0
var input_dir := 0.0

var is_dead := false

# Dash
var is_dashing := false
var dash_direction := 1.0
var dash_time_left := 0.0
var dash_cooldown_left := 0.0

# Jump
var wall_jump_active := false
var wall_jump_lock_left := 0.0
var coyote_left := 0.0
var jump_buffer_left := 0.0

# Wall
var wall_coyote_left := 0.0
var last_wall_normal_x := 0.0


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Node is called "ColorRect" in protag.tscn.
@onready var black_screen: ColorRect = $CanvasLayer/ColorRect


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Check that all required InputMap actions exist.
	for action in ["move_left", "move_right", "jump", "dash"]:
		if not InputMap.has_action(action):
			push_error(
				"Input action '%s' is missing in Project Settings > Input Map"
				% action
			)


# ============================================================
# MAIN PHYSICS LOOP
# ============================================================

func _physics_process(delta: float) -> void:

	# --------------------------------------------------------
	# DEAD
	# --------------------------------------------------------

	if is_dead:
		_apply_gravity(delta)
		move_and_slide()
		return


	# --------------------------------------------------------
	# INPUT
	# --------------------------------------------------------

	input_dir = Input.get_axis("move_left", "move_right")


	# --------------------------------------------------------
	# TIMERS
	# --------------------------------------------------------

	_update_timers(delta)


	# --------------------------------------------------------
	# DASH
	# --------------------------------------------------------

	_try_start_dash()


	# --------------------------------------------------------
	# MOVEMENT
	# --------------------------------------------------------

	if is_dashing:

		velocity = Vector2(
			dash_direction * dash_speed,
			0.0
		)

	else:

		_apply_gravity(delta)
		_handle_jump()
		_handle_horizontal(delta)


	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	move_and_slide()


	# --------------------------------------------------------
	# ANIMATION
	# --------------------------------------------------------

	_update_animation()


# ============================================================
# JUMP PHYSICS
# ============================================================

## Gravity derived from jump height and time to apex.
func _gravity_strength() -> float:
	return 2.0 * jump_height / (
		jump_time_to_apex * jump_time_to_apex
	)


## Initial velocity required to reach jump_height.
func _jump_speed() -> float:
	return -2.0 * jump_height / jump_time_to_apex


# ============================================================
# TIMERS
# ============================================================

func _update_timers(delta: float) -> void:

	# --------------------------------------------------------
	# COYOTE TIME
	# --------------------------------------------------------

	if is_on_floor():

		coyote_left = coyote_time

		# Landing ends a wall jump.
		wall_jump_active = false

	else:

		coyote_left = maxf(
			coyote_left - delta,
			0.0
		)


	# --------------------------------------------------------
	# WALL COYOTE
	# --------------------------------------------------------

	if is_on_wall_only():

		wall_coyote_left = wall_coyote_time

		last_wall_normal_x = get_wall_normal().x

	else:

		wall_coyote_left = maxf(
			wall_coyote_left - delta,
			0.0
		)


	# --------------------------------------------------------
	# JUMP BUFFER
	# --------------------------------------------------------

	jump_buffer_left = maxf(
		jump_buffer_left - delta,
		0.0
	)

	if Input.is_action_just_pressed("jump"):

		jump_buffer_left = jump_buffer_time


	# --------------------------------------------------------
	# WALL JUMP LOCK
	# --------------------------------------------------------

	wall_jump_lock_left = maxf(
		wall_jump_lock_left - delta,
		0.0
	)


	# --------------------------------------------------------
	# DASH COOLDOWN
	# --------------------------------------------------------

	dash_cooldown_left = maxf(
		dash_cooldown_left - delta,
		0.0
	)


	# --------------------------------------------------------
	# DASH TIMER
	# --------------------------------------------------------

	if is_dashing:

		dash_time_left -= delta

		if dash_time_left <= 0.0:

			is_dashing = false


# ============================================================
# DASH
# ============================================================

func _try_start_dash() -> void:

	if is_dashing:
		return

	if dash_cooldown_left > 0.0:
		return

	if not Input.is_action_just_pressed("dash"):
		return


	is_dashing = true

	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown


	# Dash in the direction being held.
	# Otherwise dash in facing direction.

	if input_dir != 0.0:

		dash_direction = signf(input_dir)

	else:

		dash_direction = facing


	facing = dash_direction


# ============================================================
# WALL SLIDE DETECTION
# ============================================================

## Player must:
## - be touching a wall
## - be falling
## - be holding toward the wall

func _is_wall_sliding() -> bool:
	if not is_on_wall_only():
		return false

	if velocity.y <= 0.0:
		return false

	return true


# ============================================================
# GRAVITY
# ============================================================

func _apply_gravity(delta: float) -> void:

	# --------------------------------------------------------
	# ON GROUND
	# --------------------------------------------------------

	if is_on_floor():

		wall_jump_active = false
		return


	# --------------------------------------------------------
	# WALL SLIDE
	# --------------------------------------------------------

	if _is_wall_sliding():

		wall_jump_active = false


		# Smoothly slow down a fast fall.
		if velocity.y > wall_slide_speed:

			velocity.y = move_toward(
				velocity.y,
				wall_slide_speed,
				wall_slide_friction * delta
			)

		else:

			# Very gentle gravity while sliding.
			velocity.y = minf(
				velocity.y
				+ _gravity_strength() * 0.55 * delta,
				wall_slide_speed
			)

		return


	# --------------------------------------------------------
	# WALL JUMP
	# --------------------------------------------------------

	if wall_jump_active:

		var multiplier := wall_jump_gravity_multiplier


		# Slight hang time around apex.
		if (
			absf(velocity.y) < apex_speed_threshold
			and Input.is_action_pressed("jump")
		):

			multiplier *= 0.65


		# Slightly stronger gravity once descending,
		# but still much lighter than normal falling.

		if velocity.y > 0.0:

			multiplier = wall_jump_fall_gravity_multiplier


		velocity.y = minf(
			velocity.y
			+ _gravity_strength() * multiplier * delta,
			max_fall_speed
		)

		return


	# --------------------------------------------------------
	# NORMAL GRAVITY
	# --------------------------------------------------------

	var multiplier := 1.0


	# Hang slightly near apex.
	if (
		absf(velocity.y) < apex_speed_threshold
		and Input.is_action_pressed("jump")
	):

		multiplier = apex_gravity_multiplier


	# Faster falling.
	elif velocity.y > 0.0:

		multiplier = fall_gravity_multiplier


	velocity.y = minf(
		velocity.y
		+ _gravity_strength() * multiplier * delta,
		max_fall_speed
	)


# ============================================================
# JUMP
# ============================================================

func _handle_jump() -> void:

	if jump_buffer_left <= 0.0:
		return


	# --------------------------------------------------------
	# NORMAL JUMP
	# --------------------------------------------------------

	if coyote_left > 0.0:

		velocity.y = _jump_speed()

		wall_jump_active = false

		_consume_jump()

		return


	# --------------------------------------------------------
	# WALL JUMP
	# --------------------------------------------------------

	if wall_coyote_left > 0.0:

		# Activate floatier wall-jump gravity.
		wall_jump_active = true


		# Same vertical launch as normal jump.
		velocity.y = _jump_speed()


		# Kick away from wall.
		velocity.x = (
			last_wall_normal_x
			* wall_jump_pushback
		)


		# Briefly limit steering.
		wall_jump_lock_left = wall_jump_lock_time


		# Face the direction we're jumping.
		facing = signf(last_wall_normal_x)


		_consume_jump()


	# --------------------------------------------------------
	# VARIABLE JUMP HEIGHT
	# --------------------------------------------------------

	if (
		Input.is_action_just_released("jump")
		and velocity.y < 0.0
	):

		velocity.y *= jump_cut_multiplier


# ============================================================
# CONSUME JUMP
# ============================================================

func _consume_jump() -> void:

	jump_buffer_left = 0.0
	coyote_left = 0.0
	wall_coyote_left = 0.0


# ============================================================
# HORIZONTAL MOVEMENT
# ============================================================

func _handle_horizontal(delta: float) -> void:

	# --------------------------------------------------------
	# WALL JUMP LOCK
	# --------------------------------------------------------

	if wall_jump_lock_left > 0.0:

		# Still allow some control during the lock.
		# This feels much less rigid than completely freezing
		# horizontal movement.

		if input_dir != 0.0:

			var target_speed := (
				input_dir
				* max_speed
				* wall_jump_air_control
			)

			velocity.x = move_toward(
				velocity.x,
				target_speed,
				air_accel * delta * 0.5
			)

		return


	# --------------------------------------------------------
	# NORMAL MOVEMENT
	# --------------------------------------------------------

	var on_floor := is_on_floor()


	if input_dir != 0.0:

		var accel := (
			ground_accel
			if on_floor
			else air_accel
		)


		velocity.x = move_toward(
			velocity.x,
			input_dir * max_speed,
			accel * delta
		)


		# Don't change facing while clinging to a wall.
		if not _is_wall_sliding():

			facing = signf(input_dir)


	else:

		var decel := (
			ground_decel
			if on_floor
			else air_decel
		)


		velocity.x = move_toward(
			velocity.x,
			0.0,
			decel * delta
		)


# ============================================================
# ANIMATION
# ============================================================

func _update_animation() -> void:

	var sliding := _is_wall_sliding()


	# --------------------------------------------------------
	# SPRITE DIRECTION
	# --------------------------------------------------------

	if sliding:

		animated_sprite.flip_h = (
			get_wall_normal().x > 0.0
		)

	else:

		animated_sprite.flip_h = (
			facing < 0.0
		)


	# --------------------------------------------------------
	# WALL CLING OFFSET
	# --------------------------------------------------------

	if sliding:

		animated_sprite.offset.x = (
			-get_wall_normal().x
			* wall_cling_offset
		)

	else:

		animated_sprite.offset.x = 0.0


	# --------------------------------------------------------
	# ANIMATIONS
	# --------------------------------------------------------

	if is_dashing:

		animated_sprite.play("roll")

	elif is_on_floor():

		if absf(velocity.x) > 5.0:

			animated_sprite.play("run")

		else:

			animated_sprite.play("idle_bop")

	elif sliding:

		animated_sprite.play("wall_slide")

	elif (
		wall_jump_lock_left > 0.0
		and velocity.y < 0.0
	):

		animated_sprite.play("wall_jump")

	else:

		animated_sprite.play("hop")


# ============================================================
# DEATH
# ============================================================

func die() -> void:

	if is_dead:
		return


	is_dead = true
	is_dashing = false
	input_dir = 0.0
	velocity.x = 0.0


	var anim := "death"


	if Global.lives > 1:

		Global.lives -= 1

	else:

		Global.lives = 3
		anim = "death_final"


	# Make sure animation_finished fires.
	animated_sprite.sprite_frames.set_animation_loop(
		anim,
		false
	)

	animated_sprite.play(anim)


	await animated_sprite.animation_finished


	# --------------------------------------------------------
	# FADE TO BLACK
	# --------------------------------------------------------

	black_screen.modulate.a = 0.0
	black_screen.visible = true


	var tween := create_tween()


	tween.tween_property(
		black_screen,
		"modulate:a",
		1.0,
		fade_time
	)


	tween.tween_interval(
		black_hold_time
	)


	await tween.finished


	get_tree().reload_current_scene()
