extends Node3D

var player: CharacterBody3D
var inventory := {"wood": 0, "stone": 0, "metal": 0}
var world_time := 8.0
var built_count := 0
var status_label: Label
var rng := RandomNumberGenerator.new()
var interact_cooldown := 0.0
var build_mode := false
var build_key_down := false

func _ready() -> void:
	rng.seed = 472991
	player = $Player
	_setup_environment()
	_build_terrain()
	_build_water()
	_spawn_resources()
	_build_status_ui()

func _process(delta: float) -> void:
	world_time = fmod(world_time + delta * 0.045, 24.0)
	interact_cooldown = max(0.0, interact_cooldown - delta)
	_update_sun()
	_handle_input()
	if status_label:
		status_label.text = "Envanter  Odun: %d   Taş: %d   Metal: %d   |   %s" % [inventory.wood, inventory.stone, inventory.metal, "YAPI MODU: Sol Tık yerleştir" if build_mode else "E: Kaynak topla | B: Yapı modu"]

func _handle_input() -> void:
	var b_down := Input.is_key_pressed(KEY_B)
	if b_down and not build_key_down:
		build_mode = not build_mode
	build_key_down = b_down
	if Input.is_key_pressed(KEY_E) and interact_cooldown <= 0.0:
		_harvest_target()
		interact_cooldown = 0.25
	if build_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and interact_cooldown <= 0.0:
		_place_building()
		interact_cooldown = 0.35

func _harvest_target() -> void:
	var camera := player.get_viewport().get_camera_3d()
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 4.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("harvest"):
		var loot: Dictionary = hit.collider.harvest()
		inventory[loot.type] += loot.amount

func _place_building() -> void:
	if inventory.wood < 4:
		return
	var camera := player.get_viewport().get_camera_3d()
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 6.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		return
	var pos: Vector3 = hit.position
	pos.y += 1.0
	var building := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(2.8, 2.0, 0.25)
	building.mesh = cube
	building.position = pos
	building.rotation.y = player.rotation.y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.16, 0.065)
	mat.roughness = 0.88
	building.material_override = mat
	add_child(building)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = cube.size
	collision.shape = shape
	body.add_child(collision)
	building.add_child(body)
	inventory.wood -= 4
	built_count += 1

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.25, 0.42)
	sky_mat.sky_horizon_color = Color(0.58, 0.66, 0.70)
	sky_mat.ground_bottom_color = Color(0.025, 0.04, 0.025)
	sky_mat.ground_horizon_color = Color(0.35, 0.38, 0.31)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	$WorldEnvironment.environment = env

func height_at(x: float, z: float) -> float:
	var broad := sin(x * 0.045) * 4.0 + cos(z * 0.052) * 3.0
	var detail := sin(x * 0.13 + z * 0.08) * 1.1 + cos(z * 0.16 - x * 0.05) * 0.8
	var mountain := max(0.0, 1.0 - Vector2(x + 32.0, z + 20.0).length() / 38.0) * 12.0
	var lake := max(0.0, 1.0 - Vector2(x - 25.0, z + 8.0).length() / 22.0) * -7.0
	return broad + detail + mountain + lake

func _build_terrain() -> void:
	var size := 160
	var step := 4.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := int(size / step)
	for z in range(-count, count + 1):
		for x in range(-count, count + 1):
			var px := x * step
			var pz := z * step
			var py := height_at(px, pz)
			vertices.append(Vector3(px, py, pz))
			uvs.append(Vector2(float(x) / count, float(z) / count))
			normals.append(Vector3.UP)
	for z in range(2 * count):
		for x in range(2 * count):
			var a := z * (2 * count + 1) + x
			var b := a + 1
			var c := a + (2 * count + 1)
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.30, 0.13)
	mat.roughness = 0.96
	terrain.material_override = mat
	add_child(terrain)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _build_water() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45, 45)
	water.mesh = plane
	water.position = Vector3(25, -1.2, -8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.20, 0.27, 0.82)
	mat.metallic = 0.25
	mat.roughness = 0.12
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = mat
	add_child(water)

func _spawn_resources() -> void:
	for i in range(95):
		var x := rng.randf_range(-68, 68)
		var z := rng.randf_range(-68, 68)
		var y := height_at(x, z)
		if y < 0.2:
			continue
		var node := load("res://resource_node.gd").new()
		add_child(node)
		node.position = Vector3(x, y, z)
		node.setup("wood" if i % 3 != 0 else "stone", rng.randi_range(2, 5))
	for i in range(22):
		var x := rng.randf_range(-60, 60)
		var z := rng.randf_range(-60, 60)
		var y := height_at(x, z)
		if y > 0.5:
			var node := load("res://resource_node.gd").new()
			add_child(node)
			node.position = Vector3(x, y, z)
			node.setup("metal", rng.randi_range(1, 3))

func _update_sun() -> void:
	var daylight := sin((world_time - 6.0) / 24.0 * TAU)
	$Sun.rotation_degrees.x = -35.0 - daylight * 35.0
	$Sun.light_energy = clamp(0.25 + daylight * 0.95, 0.05, 1.2)
	$Moon.light_energy = clamp(0.14 - daylight * 0.12, 0.02, 0.18)

func _build_status_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(24, 112)
	status_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(status_label)
	var title := Label.new()
	title.text = "Purnakin  •  Survival Prototype"
	title.position = Vector2(24, 82)
	title.add_theme_font_size_override("font_size", 20)
	layer.add_child(title)
