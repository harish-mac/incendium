extends Node2D

enum MovementType { STATIC, SWEEP, PATROL }

@export_group("Laser Settings")
@export var max_range: float = 1200.0
@export var beam_width: float = 30.0
@export var is_active: bool = true

@export_group("Movement Settings")
@export var movement_type: MovementType = MovementType.STATIC
## For SWEEP: Maximum angle in degrees to swing left and right
@export var sweep_angle: float = 45.0
## For SWEEP & PATROL: Duration in seconds for one back-and-forth cycle
@export var cycle_duration: float = 3.0
## For PATROL: Distance in pixels to slide along the ceiling
@export var patrol_offset: Vector2 = Vector2(160, 0)

@onready var beam_pivot: Area2D = $BeamPivot
@onready var ray_cast: RayCast2D = $BeamPivot/RayCast2D
@onready var line_2d: Line2D = $BeamPivot/Line2D
@onready var collision_shape: CollisionShape2D = $BeamPivot/CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const ZAPPER_TEXTURE = preload("res://assets/Main ship weapon - Projectile - Zapper.png")

var _tween: Tween

func _ready() -> void:
	beam_pivot.body_entered.connect(_on_body_entered)
	
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	
	if animated_sprite:
		animated_sprite.visible = false
	
	line_2d.width = beam_width
	line_2d.texture_mode = Line2D.LINE_TEXTURE_TILE
	_setup_beam_shader()
	
	ray_cast.target_position = Vector2.DOWN * max_range
	set_active(is_active)
	_start_movement()

func _setup_beam_shader() -> void:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;

	uniform sampler2D beam_texture : filter_nearest, repeat_enable;
	uniform float fps = 12.0;

	void fragment() {
		int frame = int(mod(TIME * fps, 8.0));
		float frame_u = float(frame) / 8.0;
		float frame_w = 1.0 / 8.0;

		vec2 uv = vec2(
			frame_u + UV.y * frame_w,
			mod(UV.x, 1.0)
		);
		COLOR = texture(beam_texture, uv);
	}
	"""
	mat.shader = shader
	mat.set_shader_parameter("beam_texture", ZAPPER_TEXTURE)
	line_2d.material = mat

func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	
	var hit_distance: float = max_range
	
	if ray_cast.is_colliding():
		# Calculate distance relative to the BeamPivot
		var hit_point = beam_pivot.to_local(ray_cast.get_collision_point())
		hit_distance = max(hit_point.length(), 1.0)
		
		var collider = ray_cast.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("die"):
			# NEW: Only kill the player if they are NOT hidden in an ambush zone
			if not collider.get("is_hidden"):
				collider.die()
	
	var hit_local_pos := Vector2(0.0, hit_distance)
	line_2d.points = [Vector2.ZERO, hit_local_pos]
	
	# Keep the hitbox aligned with the beam length
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect := collision_shape.shape as RectangleShape2D
		rect.size = Vector2(beam_width, hit_distance)
		collision_shape.position = Vector2(0.0, hit_distance / 2.0)

func _start_movement() -> void:
	if _tween:
		_tween.kill()
		
	match movement_type:
		MovementType.STATIC:
			return
			
		MovementType.SWEEP:
			beam_pivot.rotation_degrees = -sweep_angle
			_tween = create_tween().set_loops()
			_tween.tween_property(beam_pivot, "rotation_degrees", sweep_angle, cycle_duration / 2.0).set_trans(Tween.TRANS_SINE)
			_tween.tween_property(beam_pivot, "rotation_degrees", -sweep_angle, cycle_duration / 2.0).set_trans(Tween.TRANS_SINE)
			
		MovementType.PATROL:
			var start_pos := position
			var target_pos := start_pos + patrol_offset
			_tween = create_tween().set_loops()
			_tween.tween_property(self, "position", target_pos, cycle_duration / 2.0).set_trans(Tween.TRANS_SINE)
			_tween.tween_property(self, "position", start_pos, cycle_duration / 2.0).set_trans(Tween.TRANS_SINE)

func set_active(active: bool) -> void:
	is_active = active
	
	# Only hide the beam and disable detection; keep the mount visible
	beam_pivot.visible = active
	beam_pivot.set_deferred("monitoring", active)
	beam_pivot.set_deferred("monitorable", active)
	
	if ray_cast:
		ray_cast.enabled = active
	if collision_shape:
		collision_shape.set_deferred("disabled", !active)
	if not active and line_2d:
		line_2d.points = [Vector2.ZERO, Vector2.ZERO]
		
	if _tween:
		if is_active:
			_tween.play()
		else:
			_tween.pause()

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("player") and body.has_method("die"):
		# NEW: Only kill the player if they are NOT hidden in an ambush zone
		if not body.get("is_hidden"):
			body.die()
