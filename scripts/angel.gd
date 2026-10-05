class_name AngelEnemy
extends CharacterBody2D

enum State { CALM, SUSPICIOUS, ALERT }

# Used automatically if the "Projectile Scene" slot in the Inspector is empty
const DEFAULT_PROJECTILE_PATH: String = "res://scenes/projectile.tscn"

@export_group("Patrol Settings")
@export var patrol_offset: Vector2 = Vector2(200, 0)
@export var patrol_duration: float = 3.0
## Leave ON if your angel art faces RIGHT by default (yours does).
@export var sprite_faces_right: bool = true

@export_group("Hover Settings")
@export var hover_height: float = 15.0
@export var hover_duration: float = 1.0

@export_group("Detection")
## Seconds of seeing the player (added up) before the fireball launches.
@export var detect_time: float = 1.33
## How fast suspicion drains when she can't see the player (1.0 = same speed it builds).
@export var suspicion_decay: float = 0.4
@export var calm_color: Color = Color(1.0, 1.0, 1.0, 0.35)        # white  = no suspicion
@export var suspicious_color: Color = Color(1.0, 0.55, 0.1, 0.45) # orange = investigating
@export var alert_color: Color = Color(1.0, 0.1, 0.1, 0.5)        # red    = fireball launched

@export_group("Agitated hover (orange and red)")
## Hover bobs this many times HIGHER...
@export var agitated_amplitude_mult: float = 2.0
## ...and this many times FASTER.
@export var agitated_speed_mult: float = 2.0

@export_group("Investigate (orange)")
## Movement speed while investigating, as a multiple of her normal patrol speed.
@export var investigate_speed_multiplier: float = 1.2
## She sways this many pixels to each side of the last spotted position.
@export var investigate_range: float = 120.0
## Seconds she keeps searching after she loses sight of the player.
@export var search_time: float = 5.0
## If the player moves farther than this from where she is searching, she re-targets.
@export var retarget_distance: float = 80.0
## While investigating, she also notices a player this close even OUTSIDE the cone
## (so you can't hide right underneath her). Set 0 to turn off.
@export var close_sense_radius: float = 120.0

@export_group("Attack Settings")
@export var projectile_scene: PackedScene
## Rest time after a fireball finishes before she can spot you again.
@export var fire_cooldown: float = 3.0
@export var spawn_offset: Vector2 = Vector2(0, -10)

# NOTE: these names must match your Scene tree exactly
@onready var sprite: AnimatedSprite2D = $angel_sprite
@onready var vision_cone: Area2D = $VisionCone
@onready var vision_polygon: Polygon2D = $VisionCone/Polygon2D

var state: State = State.CALM
var facing: int = 1  # 1 = right, -1 = left
var start_position: Vector2
var cooldown_left: float = 0.0

var _suspicion: float = 0.0
var _sprite_base_y: float = 0.0
var _cone_base_x: float = 0.0
var _fireball: Node2D
var _hover_tween: Tween
var _move_tween: Tween   # ONE tween drives all movement (patrol / investigate / return)
var _color_tween: Tween

var _investigating: bool = false
var _last_seen_pos: Vector2
var _investigate_center: Vector2
var _search_left: float = 0.0


func _ready() -> void:
	start_position = global_position
	_sprite_base_y = sprite.position.y
	_cone_base_x = vision_cone.position.x
	vision_polygon.color = calm_color

	# Safety net: if the Inspector slot got cleared, load the fireball ourselves
	if projectile_scene == null and ResourceLoader.exists(DEFAULT_PROJECTILE_PATH):
		projectile_scene = load(DEFAULT_PROJECTILE_PATH)

	_apply_facing()
	_start_hover_effect()
	_start_patrol()


func _physics_process(delta: float) -> void:
	# Resting after a fireball finished (she is flying back to her patrol)
	if cooldown_left > 0.0:
		cooldown_left -= delta
		return

	# A fireball is chasing the player: stay red and wait for it to finish
	if is_instance_valid(_fireball):
		return

	var player := _find_visible_player()

	if player != null:
		# Remember where the player was last seen
		_last_seen_pos = player.global_position
		_search_left = search_time
		_suspicion += delta

		if _suspicion >= detect_time:
			_set_state(State.ALERT)
			_fire_at(player)
		else:
			_set_state(State.SUSPICIOUS)
			# First sighting -> go inspect. Also re-target if the player moved far away.
			if not _investigating \
					or absf(_last_seen_pos.x - _investigate_center.x) > retarget_distance:
				_start_investigate()
	else:
		# Suspicion drains slowly, so her own movement can't reset it instantly
		_suspicion = maxf(_suspicion - delta * suspicion_decay, 0.0)

		# Lost sight: keep searching around the last spot, then give up
		if _investigating:
			_search_left -= delta
			if _search_left <= 0.0:
				_set_state(State.CALM)
				_return_to_patrol()


func _find_visible_player() -> Node2D:
	# 1) Anyone inside the vision cone
	for body in vision_cone.get_overlapping_bodies():
		if body.is_in_group("player") and body.get("is_dead") != true:
			return body

	# 2) While investigating, also notice a player standing very close
	if _investigating and close_sense_radius > 0.0:
		for node in get_tree().get_nodes_in_group("player"):
			if node is Node2D and node.get("is_dead") != true \
					and global_position.distance_to(node.global_position) <= close_sense_radius:
				return node as Node2D

	return null


# ---------------------------------------------------------------- state ---

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state

	var target_color := calm_color
	match state:
		State.SUSPICIOUS:
			target_color = suspicious_color
		State.ALERT:
			target_color = alert_color

	# Smooth colour change
	if _color_tween:
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(vision_polygon, "color", target_color, 0.15)

	# More agitated hover when suspicious or alert
	_start_hover_effect()


# --------------------------------------------------------------- attack ---

func _fire_at(player: Node2D) -> void:
	if projectile_scene == null:
		push_error("Angel: no Projectile Scene! Drag projectile.tscn into the Inspector slot.")
		_fire_failed()
		return

	var p = projectile_scene.instantiate()

	# The fireball's root node must have projectile.gd attached
	if not ("target" in p):
		push_error("Angel: the fireball scene has no projectile.gd on its root node!")
		p.queue_free()
		_fire_failed()
		return

	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector2(spawn_offset.x * facing, spawn_offset.y)
	p.target = player
	p.direction = (player.global_position - p.global_position).normalized()

	_fireball = p
	p.tree_exited.connect(_on_fireball_gone)
	print("Angel fires a fireball!")


func _fire_failed() -> void:
	# Don't get stuck red with nothing to show for it
	_suspicion = 0.0
	cooldown_left = fire_cooldown
	_set_state(State.SUSPICIOUS)


func _on_fireball_gone() -> void:
	if not is_inside_tree():
		return  # the scene is closing/reloading
	_fireball = null
	_suspicion = 0.0
	cooldown_left = fire_cooldown
	_set_state(State.CALM)
	_return_to_patrol()


# --------------------------------------------------------------- facing ---

func _face(dir: float) -> void:
	if is_zero_approx(dir):
		return
	facing = 1 if dir > 0.0 else -1
	_apply_facing()


func _apply_facing() -> void:
	# Flip the sprite
	sprite.flip_h = (facing < 0) if sprite_faces_right else (facing > 0)
	# Mirror the vision cone (its shape AND its drawing flip together)
	vision_cone.scale.x = facing
	vision_cone.position.x = _cone_base_x * facing


# ---------------------------------------------------------------- hover ---

func _start_hover_effect() -> void:
	if _hover_tween:
		_hover_tween.kill()

	var agitated := state != State.CALM
	var amplitude := hover_height * (agitated_amplitude_mult if agitated else 1.0)
	var duration := hover_duration / (agitated_speed_mult if agitated else 1.0)

	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_property(sprite, "position:y", _sprite_base_y - amplitude, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(sprite, "position:y", _sprite_base_y, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --------------------------------------------------------------- speeds ---

# Her normal walking speed in pixels per second (distance / time of one patrol leg)
func _patrol_speed() -> float:
	return maxf(patrol_offset.length() / maxf(patrol_duration, 0.1), 40.0)


# Yellow/orange state speed = normal speed x 1.2 (by default)
func _investigate_speed() -> float:
	return _patrol_speed() * investigate_speed_multiplier


# --------------------------------------------------------------- movement ---
# Only ONE of these is running at a time (they all share _move_tween).

# 1) Normal back-and-forth patrol (CALM / white)
func _start_patrol() -> void:
	var a := start_position
	var b := start_position + patrol_offset
	var dir := signf(patrol_offset.x)

	_move_tween = create_tween().set_loops()

	# Going out: face the way we're moving
	_move_tween.tween_callback(_face.bind(dir))
	_move_tween.tween_property(self, "global_position", b, patrol_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Coming back: turn around
	_move_tween.tween_callback(_face.bind(-dir))
	_move_tween.tween_property(self, "global_position", a, patrol_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# 2) Fly to where the player was last seen (SUSPICIOUS / orange)
func _start_investigate() -> void:
	_investigating = true
	_search_left = search_time
	# Go to the player's X but keep her own flying height
	_investigate_center = Vector2(_last_seen_pos.x, global_position.y)

	if _move_tween:
		_move_tween.kill()

	var distance := absf(_investigate_center.x - global_position.x)
	var travel := maxf(distance / _investigate_speed(), 0.1)

	_move_tween = create_tween()
	_move_tween.tween_callback(_face.bind(_investigate_center.x - global_position.x))
	_move_tween.tween_property(self, "global_position", _investigate_center, travel) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tween.tween_callback(_start_search_sway)


# 3) Sway left and right around that spot at the same investigate speed
func _start_search_sway() -> void:
	var right := _investigate_center + Vector2(investigate_range, 0)
	var left := _investigate_center + Vector2(-investigate_range, 0)
	var leg := maxf(2.0 * investigate_range / _investigate_speed(), 0.2)

	_move_tween = create_tween().set_loops()
	_move_tween.tween_callback(_face.bind(1.0))
	_move_tween.tween_property(self, "global_position", right, leg * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(_face.bind(-1.0))
	_move_tween.tween_property(self, "global_position", left, leg) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(_face.bind(1.0))
	_move_tween.tween_property(self, "global_position", _investigate_center, leg * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# 4) Give up searching: fly back to the patrol start, then patrol again
func _return_to_patrol() -> void:
	_investigating = false

	if _move_tween:
		_move_tween.kill()

	var distance := global_position.distance_to(start_position)
	var travel := maxf(distance / _patrol_speed(), 0.2)

	_move_tween = create_tween()
	_move_tween.tween_callback(_face.bind(start_position.x - global_position.x))
	_move_tween.tween_property(self, "global_position", start_position, travel) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(_start_patrol)
