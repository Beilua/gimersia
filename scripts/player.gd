extends CharacterBody2D

var speed = 400
var dash_speed = 1000
var is_dashing = false
var can_dash = true
var last_direction = "front"

var fireball = load('res://scenes/fireball.tscn')

@onready var sprite = $AnimatedSprite2D
@onready var shadow_spawner = $/root/World/ShadowSpawner
@onready var dash_duration_timer = $Timers/DashDuration
@onready var dash_cooldown_timer = $Timers/DashCooldown
@onready var attack_range = $AttackRange
@onready var raycast = $RayCast

# Shadow settings
var shadow_interval = 0.05
var shadow_timer = 0.0
var shadow_fade_time = 0.3

# Enemy tracking
var enemies: Array = []
var enemies_sorted: Array = []

var valid_target = null


#func _ready():
	#dash_duration_timer.timeout.connect(_on_dash_duration_timeout)
	#dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	#attack_range.body_entered.connect(_on_attack_range_body_entered)
	#attack_range.body_exited.connect(_on_attack_range_body_exited)

func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# --- DASH LOGIC ---
	if is_dashing:
		velocity = direction.normalized() * dash_speed
		shadow_timer -= delta
		if shadow_timer <= 0:
			_spawn_shadow()
			shadow_timer = shadow_interval
	else:
		velocity = direction * speed

	move_and_slide()
	if direction == Vector2.ZERO:
		sprite.play("idle_" + last_direction)
	else:
		var dir = ""
		if direction.x > 0 and direction.y < 0:
			dir = "rightback"
		elif direction.x < 0 and direction.y < 0:
			dir = "leftback"
		elif direction.x > 0 and direction.y > 0:
			dir = "rightfront"
		elif direction.x < 0 and direction.y > 0:
			dir = "leftfront"
		elif direction.y < 0:
			dir = "back"
		elif direction.y > 0:
			dir = "front"
		elif direction.x > 0:
			dir = "right"
		elif direction.x < 0:
			dir = "left"
		if dir != "":
			last_direction = dir
			sprite.play("walk_" + dir)

	# --- TARGETING SYSTEM ---
	if enemies.size() > 0:
		_update_targeting()

func _input(event):
	if event.is_action_pressed("dash") and can_dash and not is_dashing:
		_start_dash()
	elif event.is_action_pressed("attack"):
		var fireball_instance = fireball.instantiate()
		get_parent().add_child(fireball_instance)
		fireball_instance.global_position = global_position
		
		if (valid_target):
			fireball_instance.look_at(valid_target.global_position)
		else:
			fireball_instance.look_at(get_global_mouse_position())

# --- DASH HANDLING ---
func _start_dash():
	is_dashing = true
	can_dash = false
	dash_duration_timer.start()
	_spawn_shadow()
	shadow_timer = shadow_interval

	# Matikan collision dengan musuh (Layer 2)
	set_collision_mask_value(2, false)
	set_collision_layer_value(1, false) # opsional, jika ingin tidak bisa ditabrak juga

func _on_dash_duration_timeout():
	is_dashing = false
	dash_cooldown_timer.start()

	# Aktifkan kembali collision dengan musuh
	set_collision_mask_value(2, true)
	set_collision_layer_value(1, true)


func _on_dash_cooldown_timeout():
	can_dash = true

# --- SHADOW EFFECT ---
func _spawn_shadow():
	var shadow = Sprite2D.new()
	shadow.texture = sprite.texture
	if sprite.has_method("get_frame"):
		shadow.frame = sprite.frame
		shadow.hframes = sprite.hframes
		shadow.vframes = sprite.vframes
	shadow.position = global_position
	shadow.scale = sprite.scale
	shadow.rotation = sprite.rotation

	# warna putih agak terang
	shadow.modulate = Color(1.2, 1.2, 1.2, 0.8)
	shadow_spawner.add_child(shadow)

	var tween = create_tween()
	tween.tween_property(shadow, "modulate:a", 0, shadow_fade_time)
	tween.tween_callback(Callable(shadow, "queue_free"))

# --- TARGETING ---
func _update_targeting():
	enemies_sorted.clear()
	for enemy in enemies:
		enemies_sorted.append({
			"enemy": enemy,
			"distance": enemy.global_position.distance_to(global_position)
		})

	# Urutkan musuh dari terdekat ke terjauh
	enemies_sorted.sort_custom(func(a, b): return a["distance"] < b["distance"])

	if enemies_sorted.is_empty():
		return

	var first_target = enemies_sorted[0]["enemy"]
	valid_target = null

	for data in enemies_sorted:
		var target = data["enemy"]
		raycast.target_position = target.global_position - raycast.global_position
		raycast.force_raycast_update()

		if not raycast.is_colliding() or raycast.get_collider().is_in_group("Enemy"):
			valid_target = target
			break

		var collider = raycast.get_collider()
		if collider:
			# Cek apakah collider atau parent-nya adalah target (mengatasi hitbox sebagai child)
			var node_to_check = collider
			var hit_is_target = false
			while node_to_check:
				if node_to_check == target:
					hit_is_target = true
					break
				node_to_check = node_to_check.get_parent()

			if hit_is_target:
				valid_target = target
				break
			else:
				continue

	# Jika semua target terhalang, fallback ke yang pertama
	if valid_target == null:
		valid_target = first_target

	if valid_target:
		raycast.target_position = valid_target.global_position - raycast.global_position
		raycast.force_raycast_update()
	else:
		pass
# --- ENEMY DETECTION ---
func _on_attack_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		enemies.append(body)

func _on_attack_range_body_exited(body: Node2D) -> void:
	if body in enemies:
		enemies.erase(body)
