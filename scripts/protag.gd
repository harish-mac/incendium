extends CharacterBody2D

const SPEED = 130.0
const DASH_SPEED_MULTIPLIER = 2.5
const JUMP_VELOCITY = -360.0
const WALL_JUMP_VELOCITY = -260.0
const WALL_JUMP_PUSHBACK = 160.0
const WALL_SLIDE_SPEED = 100.0

const DASH_DURATION = 0.25
const DASH_COOLDOWN = 0.7
const WALL_JUMP_LOCK_TIME = 0.08

var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var is_dashing := false
var dash_direction := 1.0

var wall_jump_lock_left := 0.0

var is_dead := false

var _fade: ColorRect

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false
var attack_index := 0

var attack_animations = [
	"attack_1",
	"attack_2_slash",
	"attack_3_slas" # CHANGE THIS to your exact 3rd animation name
]

# Add these variables near the top of protag.gd
var is_hidden: bool = false
var _ambush_count: int = 0

func set_hidden(hidden: bool) -> void:
	if hidden:
		_ambush_count += 1
	else:
		_ambush_count = max(0, _ambush_count - 1)
	
	is_hidden = _ambush_count > 0
	
	# Visual stealth feedback: semi-transparent when hidden
	if animated_sprite:
		animated_sprite.modulate.a = 0.5 if is_hidden else 1.0

func _ready() -> void:
	add_to_group("player")
	# Death animations must NOT loop, otherwise animation_finished never fires
	# and die() waits forever. Forced here so a scene merge can't break it.
	animated_sprite.sprite_frames.set_animation_loop("death", false)
	animated_sprite.sprite_frames.set_animation_loop("death_final", false)

	# Checkpoint logic
	if not Global.has_checkpoint:
		Global.checkpoint_position = global_position
		Global.has_checkpoint = true


# Returns the fade rect from the shared UI scene (group "game_ui") if the level
# has one. Otherwise builds a fallback fade so the player works in any level.
# Looked up lazily so scene load order doesn't matter.
func _get_fade() -> ColorRect:
	if is_instance_valid(_fade):
		return _fade

	for node in get_tree().get_nodes_in_group("game_ui"):
		if node.get("fade") is ColorRect:
			_fade = node.fade
			return _fade

	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fade)
	return _fade


func _fade_to(alpha: float, duration: float = 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(_get_fade(), "color:a", alpha, duration)
	await tween.finished


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity + wall slide limit
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta
		if is_on_wall() and velocity.y > 0:
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

	var direction := Input.get_axis("move_left", "move_right")

	# Start attack
	if ( Input.is_action_just_pressed("attack") or Input.is_action_pressed("attack") ) and not is_attacking:
		attack()

# Handle attack
	if is_attacking:
		if not Input.is_action_pressed("attack"):
			is_attacking = false
			animated_sprite.stop()

		# Attack animation finished while mouse is still held
		elif not animated_sprite.is_playing():
			attack_index += 1

			if attack_index >= attack_animations.size():
				attack_index = 0

			animated_sprite.play(attack_animations[attack_index])
	
	# Jump & wall jump
	if Input.is_action_just_pressed("jump") and not is_dashing:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			velocity.y = WALL_JUMP_VELOCITY

			# get_wall_normal().x points away from the wall. Holding that
			# direction leaps across the gap (zig-zag), so push harder.
			if direction == sign(get_wall_normal().x):
				velocity.x = get_wall_normal().x * (WALL_JUMP_PUSHBACK * 1.5)
				wall_jump_lock_left = WALL_JUMP_LOCK_TIME * 0.5
			else:
				velocity.x = get_wall_normal().x * WALL_JUMP_PUSHBACK
				wall_jump_lock_left = WALL_JUMP_LOCK_TIME

	# Timers
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

	# Movement and animations
	if is_attacking:
		pass
	elif is_dashing:
		velocity.x = dash_direction * SPEED * DASH_SPEED_MULTIPLIER
		velocity.y = 0
		animated_sprite.play("roll")
	else:
		# Horizontal steering (unless locked by a wall jump)
		if wall_jump_lock_left <= 0:
			if direction:
				velocity.x = direction * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

		# Sprite flipping
		if wall_jump_lock_left > 0:
			animated_sprite.flip_h = velocity.x < 0
		elif not is_on_wall() or is_on_floor():
			if direction > 0:
				animated_sprite.flip_h = false
			elif direction < 0:
				animated_sprite.flip_h = true

		# Animations
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
		await _fade_to(1.0)
		await respawn()
	else:
		animated_sprite.play("death_final")
		await animated_sprite.animation_finished
		await _fade_to(1.0)
		game_over()


func respawn() -> void:
	global_position = Global.checkpoint_position
	velocity = Vector2.ZERO
	animated_sprite.play("idle_bop")

	await get_tree().create_timer(0.15).timeout
	await _fade_to(0.0)

	is_dead = false


func game_over() -> void:
	print("GAME OVER")
	Global.lives = 3
	Global.has_checkpoint = false
	get_tree().reload_current_scene()

func attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	is_attacking = true
	velocity.x = 0

	animated_sprite.play(attack_animations[attack_index])
