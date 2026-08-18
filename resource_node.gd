extends StaticBody3D

var resource_type := "wood"
var amount := 1
var mesh_root: Node3D

func setup(kind: String, quantity: int) -> void:
	resource_type = kind
	amount = quantity
	_build_visual()

func _build_visual() -> void:
	mesh_root = Node3D.new()
	add_child(mesh_root)
	var mat := StandardMaterial3D.new()
	if resource_type == "wood":
		mat.albedo_color = Color(0.18, 0.075, 0.025)
		mat.roughness = 0.9
		var trunk := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.28
		cylinder.bottom_radius = 0.42
		cylinder.height = 3.4
		trunk.mesh = cylinder
		trunk.material_override = mat
		trunk.position.y = 1.7
		mesh_root.add_child(trunk)
		var leaves_mat := StandardMaterial3D.new()
		leaves_mat.albedo_color = Color(0.055, 0.20, 0.075)
		var leaves := MeshInstance3D.new()
		var cone := SphereMesh.new()
		cone.radius = 1.65
		cone.height = 3.0
		leaves.mesh = cone
		leaves.material_override = leaves_mat
		leaves.position.y = 3.7
		mesh_root.add_child(leaves)
	else:
		mat.albedo_color = Color(0.30, 0.32, 0.34)
		mat.roughness = 1.0
		var rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.85
		sphere.height = 1.2
		rock.mesh = sphere
		rock.material_override = mat
		rock.scale = Vector3(1.25, 0.75, 1.0)
		rock.position.y = 0.55
		mesh_root.add_child(rock)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.0, 1.4)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)

func harvest() -> Dictionary:
	amount -= 1
	if amount <= 0:
		queue_free()
	return {"type": resource_type, "amount": 1}
