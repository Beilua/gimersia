extends StaticBody2D

var speed = 750

func _physics_process(delta):
	global_position += transform.x * speed * delta

func _on_fireball_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		body.queue_free()
		queue_free()
		
	if body.is_in_group("Obstacle"):
		queue_free()
