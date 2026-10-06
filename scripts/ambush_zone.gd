class_name AmbushZone
extends Area2D

func _ready() -> void:
	add_to_group("ambush")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("set_hidden"):
		body.set_hidden(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("set_hidden"):
		body.set_hidden(false)
