extends CharacterBody2D

# --- KONSTANTA UTAMA ---
const SPEED = 200.0
const AGILITY = 0.1 # Seberapa lincah musuh berbelok (0.0 - 1.0)

# --- BOBOT "KEINGINAN" (Prioritas AI) ---
const SEEK_WEIGHT = 1.0     # Bobot untuk mengejar player
const SEPARATION_WEIGHT = 1.5 # Bobot untuk menghindar musuh (overlap)
const AVOID_WALL_WEIGHT = 3.0 # Bobot untuk menghindar tembok (Paling Penting)

# --- JARAK DETEKSI ---
const SEPARATION_DISTANCE = 48.0 # Jarak radius $SoftCollision Anda
const STOP_DISTANCE = 86.0       # Jarak berhenti (logika Anda)

# --- Referensi Node ---
@onready var player = $/root/World/Player
@onready var line_of_sight = $LineOfSight
@onready var soft_collision = $SoftCollision # <-- Sensor Musuh Dinamis
@onready var obstacle_avoiders = $ObstacleAvoiders # <-- Sensor Tembok Dinamis


func _physics_process(_delta) -> void:
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# --- FASE 1: HITUNG SEMUA GAYA (FORCES) ---
	
	# 1. Gaya Kejar Player (Logika Asli Anda)
	var seek_force = get_seek_force()
	
	# 2. Gaya Pisah (Separation) (Memperbaiki Overlap)
	var separation_force = get_separation_force()
	
	# 3. Gaya Hindar Tembok
	var avoid_wall_force = get_obstacle_avoid_force()
	
	
	# --- FASE 2: GABUNGKAN SEMUA GAYA (STEERING) ---
	
	var combined_force = Vector2.ZERO
	combined_force += seek_force * SEEK_WEIGHT
	combined_force += separation_force * SEPARATION_WEIGHT
	combined_force += avoid_wall_force * AVOID_WALL_WEIGHT
	
	# --- FASE 3: TERAPKAN KECEPATAN ---
	
	# "Raycast dinamis" Anda ada di sini:
	# Arahkan "sensor" penghindar tembok ke arah kita ingin bergerak
	if combined_force.length_squared() > 0:
		obstacle_avoiders.rotation = combined_force.angle()

	# Gunakan lerp() untuk "menyetir" (steering)
	var target_velocity = combined_force.normalized() * SPEED
	velocity = velocity.lerp(target_velocity, AGILITY)
	
	move_and_slide()


# ================================================================
# FUNGSI PERILAKU (STEERING BEHAVIORS)
# ================================================================

# "KEINGINAN" 1: Mengejar Player (Logika Asli Anda)
func get_seek_force() -> Vector2:
	if player.global_position.distance_to(global_position) <= STOP_DISTANCE:
		return Vector2.ZERO

	line_of_sight.target_position = player.global_position - global_position
	line_of_sight.force_raycast_update()
	
	if not line_of_sight.is_colliding() or line_of_sight.get_collider() == player:
		return (player.global_position - global_position).normalized()
	
	return Vector2.ZERO


# "KEINGINAN" 2: Menghindar Musuh Lain (Perbaikan Overlap)
# Ini adalah "sensor dinamis" Anda. Ia mendeteksi *semua* musuh
# di dalam radius, tidak peduli arahnya.
func get_separation_force() -> Vector2:
	var avoid_vector = Vector2.ZERO
	
	# Area2D secara DINAMIS memberi kita daftar semua yang tumpang tindih
	for body in soft_collision.get_overlapping_bodies():
		if body != self and body is CharacterBody2D:
			
			var dist = global_position.distance_to(body.global_position)
			if dist > 0: 
				var push_dir = (global_position - body.global_position).normalized()
				# Semakin dekat, semakin kuat dorongan
				var strength = clamp(1.0 - (dist / SEPARATION_DISTANCE), 0.0, 1.0)
				avoid_vector += push_dir * strength
	
	# PENTING: JANGAN dinormalisasi.
	# Ini adalah perbaikan dari bug Anda sebelumnya.
	return avoid_vector


# "KEINGINAN" 3: Menghindar Tembok (Raycast "Kumis" Dinamis)
func get_obstacle_avoid_force() -> Vector2:
	var avoid_vector = Vector2.ZERO
	
	# $ObstacleAvoiders (Node2D) berputar,
	# membuat RayCast di dalamnya juga berputar secara dinamis
	for ray in obstacle_avoiders.get_children():
		if ray is RayCast2D and ray.is_colliding():
			var push_direction = -ray.target_position.normalized()
			
			# Beri bobot lebih jika yang kena adalah sensor depan
			if ray.name == "front":
				avoid_vector += push_direction * 1.0
			else:
				avoid_vector += push_direction * 0.5 
	
	# Di sini kita normalisasi, karena kita hanya peduli arah umum
	# untuk menghindar tembok
	return avoid_vector.normalized()
