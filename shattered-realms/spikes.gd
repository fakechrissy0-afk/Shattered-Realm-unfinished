extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the object has a "die" function (which only our Player has)
	if body.has_method("die"):
		body.die()
