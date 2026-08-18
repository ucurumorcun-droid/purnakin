extends CharacterBody3D

@export var species := "deer"
@export var max_health := 40.0
@export var walk_speed := 2.2
@export var flee_speed := 6.0
var health := 40.0
var target := Vector3.ZERO
var wander_timer := 0.0
var state := "wander"
var player: Node3D

func _ready() -> void:
	health = max_health
	_build_animal()
	var p := get_tree().get_first_node_in_group("player")
	if p: player = p
	_pick_wander_target()

func _physics_process(delta: float) -> void:
	if player == null:
		var p := get_tree().get_first_node_in_group("player")
		if p: player = p
	if player:
		var d := global_position.distance_to(player.global_position)
		if d < 10.0:
			state = "flee"
			target = global_position + (global_position - player.global_position).normalized() * 18.0
		elif state == "flee" and d > 18.0:
			state = "wander"
	if state == "wander":
		wander_timer -= delta
		if wander_timer <= 0.0 or global_position.distance_to(target) < 1.5:
			_pick_wander_target()
	var direction := global_position.direction_to(target)
	direction.y = 0.0
	if direction.length() > 0.1:
		direction = direction.normalized()
		velocity.x = direction.x * (flee_speed if state == "flee" else walk_speed)
		velocity.z = direction.z * (flee_speed if state == "flee" else walk_speed)
		look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else: velocity.y = -0.5
	move_and_slide()

func _pick_wander_target() -> void:
	wander_timer = randf_range(2.0, 6.0)
	target = global_position + Vector3(randf_range(-14.0, 14.0), 0, randf_range(-14.0, 14.0))

func damage(amount: float) -> Dictionary:
	health -= amount
	if health <= 0.0:
		var drops := {"meat": 2, "hide": 1}
		queue_free()
		return drops
	return {}

func _build_animal() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.55
	body_mesh.height = 1.5
	body.mesh = body_mesh
	body.position.y = 0.95
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.25, 0.12) if species == "deer" else Color(0.38, 0.38, 0.36)
	mat.roughness = 0.95
	body.material_override = mat
	add_child(body)
	for x in [-0.32, 0.32]:
		for z in [-0.35, 0.35]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.09
			leg_mesh.bottom_radius = 0.12
			leg_mesh.height = 0.9
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.45, z)
			leg.material_override = mat
			add_child(leg)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.42
	head_mesh.height = 0.72
	head.mesh = head_mesh
	head.position = Vector3(0, 1.65, -0.58)
	head.material_override = mat
	add_child(head)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
