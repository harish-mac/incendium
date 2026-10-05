extends Node2D

@onready var lever: Area2D = $lever
@onready var laser: Node2D = $laser

func _ready() -> void:
	lever.lever_toggled.connect(_on_lever_toggled)
	_on_lever_toggled(lever.is_on)

func _on_lever_toggled(is_on: bool) -> void:
	laser.set_active(!is_on)
