extends CharacterBody3D

const SPEED := 6.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 5.5
const MOUSE_SENSITIVITY := 0.0022

var gravity := 18.0
var pitch := 0.0
var stamina := 100.0
var hunger := 100.0
var thirst := 100.0
var health := 100.0
var hud: Label

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		head.rotation.x = pitch
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_vec := Input.get_vector(KEY_A, KEY_D, KEY_W, KEY_S)
	var direction := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and direction.length() > 0.1 and stamina > 1.0
	var speed := SPRINT_SPEED if sprinting else SPEED
	if sprinting:
		stamina = max(0.0, stamina - 18.0 * delta)
	else:
		stamina = min(100.0, stamina + 11.0 * delta)
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * 8.0 * delta)
	move_and_slide()
	_update_survival(delta)
	_update_hud()

func _update_survival(delta: float) -> void:
	hunger = max(0.0, hunger - 0.045 * delta)
	thirst = max(0.0, thirst - 0.085 * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		health = max(0.0, health - 3.0 * delta)
	if global_position.y < -12.0:
		global_position = Vector3(0, 8, 18)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 22)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98))
	layer.add_child(hud)
	var help := Label.new()
	help.text = "WASD Hareket  |  SHIFT Koş  |  SPACE Zıpla  |  Sol Tık Etkileşim  |  ESC Fare"
	help.position = Vector2(24, 690)
	help.add_theme_font_size_override("font_size", 15)
	layer.add_child(help)
	var cross := Label.new()
	cross.text = "+"
	cross.position = Vector2(636, 346)
	cross.add_theme_font_size_override("font_size", 22)
	layer.add_child(cross)

func _update_hud() -> void:
	if hud:
		hud.text = "Purnakin\nCan: %3d   Açlık: %3d   Susuzluk: %3d   Dayanıklılık: %3d" % [health, hunger, thirst, stamina]
