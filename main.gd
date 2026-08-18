extends Node3D

var player: CharacterBody3D
var inventory := {"wood": 0, "stone": 0, "metal": 0}
var world_time := 8.0
var rng := RandomNumberGenerator.new()
var status_label: Label
var toast_label: Label
var build_mode := false
var build_preview: MeshInstance3D
var action_cooldown := 0.0
var built_count := 0

func _ready() -> void:
	rng.seed = 472991
	player = $Player
	_setup_environment()
	_build_terrain()
	_build_water()
	_spawn_resources()
	_build_ui()

func _process(delta: float) -> void:
	world_time = fmod(world_time + delta * 0.045, 24.0)
	action_cooldown = max(0.0, action_cooldown - delta)
	_update_sun()
	_handle_gameplay()
	_update_build_preview()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			build_mode = not build_mode
			_show_toast("İnşa modu: " + ("AÇIK" if build_mode else "KAPALI"))
		if event.keycode == KEY_C:
			_craft_campfire()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and build_mode:
		_place_building()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.055, 0.12, 0.22)
	sky_mat.sky_horizon_color = Color(0.55, 0.63, 0.67)
	sky_mat.ground_bottom_color = Color(0.018, 0.025, 0.02)
	sky_mat.ground_horizon_color = Color(0.25, 0.30, 0.25)
	sky_mat.sun_angle_max = 8.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	$WorldEnvironment.environment = env

func height_at(x: float, z: float) -> float:
	var broad := sin(x * 0.045) * 4.0 + cos(z * 0.052) * 3.0
	var detail := sin(x * 0.13 + z * 0.08) * 1.1 + cos(z * 0.16 - x * 0.05) * 0.8
	var mountain := max(0.0, 1.0 - Vector2(x + 32.0, z + 20.0).length() / 38.0) * 12.0
	var ridge := max(0.0, 1.0 - Vector2(x - 45.0, z - 38.0).length() / 30.0) * 7.0
	var lake := max(0.0, 1.0 - Vector2(x - 25.0, z + 8.0).length() / 22.0) * -7.0
	return broad + detail + mountain + ridge + lake

func _build_terrain() -> void:
	var size := 160
	var step := 4.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := int(size / step)
	var row := 2 * count + 1
	for z in range(-count, count + 1):
		for x in range(-count, count + 1):
			var px := x * step
			var pz := z * step
			var py := height_at(px, pz)
			vertices.append(Vector3(px, py, pz))
			uvs.append(Vector2(float(x + count) / (row - 1), float(z + count) / (row - 1)))
			normals.append(Vector3.UP)
	for z in range(2 * count):
		for x in range(2 * count):
			var a := z * row + x
			var b := a + 1
			var c := a + row
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
	mat.albedo_color = Color(0.16, 0.27, 0.11)
	mat.roughness = 0.98
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
	mat.albedo_color = Color(0.025, 0.15, 0.22, 0.82)
	mat.metallic = 0.35
	mat.roughness = 0.08
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = mat
	add_child(water)

func _spawn_resources() -> void:
	for i in range(115):
		var x := rng.randf_range(-70, 70)
		var z := rng.randf_range(-70, 70)
		var y := height_at(x, z)
		if y < 0.4:
			continue
		var node := load("res://resource_node.gd").new()
		add_child(node)
		node.position = Vector3(x, y, z)
		node.setup("wood" if i % 3 != 0 else "stone", rng.randi_range(2, 5))
	for i in range(28):
		var x := rng.randf_range(-64, 64)
		var z := rng.randf_range(-64, 64)
		var y := height_at(x, z)
		if y > 0.8:
			var node := load("res://resource_node.gd").new()
			add_child(node)
			node.position = Vector3(x, y, z)
			node.setup("metal", rng.randi_range(1, 3))

func _handle_gameplay() -> void:
	if action_cooldown > 0.0 or build_mode:
		return
	if Input.is_key_pressed(KEY_E):
		var cam := player.get_viewport().get_camera_3d()
		var from := cam.global_position
		var to := from - cam.global_transform.basis.z * 4.5
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [player]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit and hit.collider.has_method("harvest"):
			var loot: Dictionary = hit.collider.harvest()
			inventory[loot.type] += loot.amount
			action_cooldown = 0.25
			_show_toast("+%d %s" % [loot.amount, loot.type])

func _craft_campfire() -> void:
	if inventory.wood >= 5 and inventory.stone >= 3:
		inventory.wood -= 5
		inventory.stone -= 3
		_spawn_campfire(player.global_position + -player.global_transform.basis.z * 2.5)
		_show_toast("Kamp ateşi üretildi (-5 odun, -3 taş)")
	else:
		_show_toast("Kamp ateşi için 5 odun + 3 taş gerekli")

func _spawn_campfire(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(pos.x, height_at(pos.x, pos.z), pos.z)
	add_child(body)
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.95
	cyl.height = 0.18
	ring.mesh = cyl
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.22, 0.23, 0.22)
	ring.material_override = stone_mat
	ring.position.y = 0.1
	body.add_child(ring)
	var fire := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.9
	fire.mesh = sphere
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.25, 0.03)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.12, 0.01)
	fire_mat.emission_energy_multiplier = 4.0
	fire.material_override = fire_mat
	fire.position.y = 0.65
	body.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.16)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position.y = 1.2
	body.add_child(light)

func _update_build_preview() -> void:
	if not build_mode:
		if build_preview:
			build_preview.visible = false
		return
	if not build_preview:
		build_preview = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, 2.5, 3.0)
		build_preview.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.75, 0.4, 0.38)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		build_preview.material_override = mat
		add_child(build_preview)
	var cam := player.get_viewport().get_camera_3d()
	var pos := cam.global_position - cam.global_transform.basis.z * 5.0
	pos.y = height_at(pos.x, pos.z) + 1.25
	build_preview.position = pos
	build_preview.visible = true

func _place_building() -> void:
	if inventory.wood < 12 or inventory.stone < 6:
		_show_toast("Duvar için 12 odun + 6 taş gerekli")
		return
	inventory.wood -= 12
	inventory.stone -= 6
	var pos := build_preview.position
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 2.5, 3.0)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.20, 0.12)
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.5, 3.0)
	col.shape = shape
	body.add_child(col)
	built_count += 1
	_show_toast("Yapı yerleştirildi")

func _update_sun() -> void:
	var daylight := sin((world_time - 6.0) / 24.0 * TAU)
	$Sun.rotation_degrees.x = -35.0 - daylight * 35.0
	$Sun.light_energy = clamp(0.25 + daylight * 0.95, 0.04, 1.2)
	$Moon.light_energy = clamp(0.14 - daylight * 0.12, 0.02, 0.18)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "PURNAKIN  •  WILDERNESS"
	title.position = Vector2(22, 82)
	title.add_theme_font_size_override("font_size", 20)
	layer.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(22, 110)
	status_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(status_label)
	toast_label = Label.new()
	toast_label.position = Vector2(22, 145)
	toast_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(toast_label)

func _update_ui() -> void:
	if status_label:
		status_label.text = "Odun %d   Taş %d   Metal %d   |   Yapılar %d   |   Saat %02d:%02d" % [inventory.wood, inventory.stone, inventory.metal, built_count, int(world_time), int((world_time - int(world_time)) * 60.0)]

func _show_toast(message: String) -> void:
	if toast_label:
		toast_label.text = message
		get_tree().create_timer(2.0).timeout.connect(func():
			if toast_label:
				toast_label.text = ""
		)
