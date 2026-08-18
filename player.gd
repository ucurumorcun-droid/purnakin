extends CharacterBody3D

const WALK_SPEED := 5.5
const SPRINT_SPEED := 8.5
const JUMP_VELOCITY := 5.8
const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 18.0

var stamina := 100.0
var hunger := 100.0
var thirst := 100.0
var health := 100.0
var hud: Label
var vitals_bar: Label
var dead := false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		var motion := event as InputEventMouseMotion
		head.rotation.x = clamp(head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -1.48, 1.48)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W): input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_vec.y += 1.0
	input_vec = input_vec.normalized()
	var direction := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and direction.length() > 0.1 and stamina > 1.0
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting:
		stamina = max(0.0, stamina - 20.0 * delta)
	else:
		stamina = min(100.0, stamina + 12.0 * delta)
	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 9.0 * delta)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED * 9.0 * delta)
	move_and_slide()
	_update_survival(delta)
	_update_hud()

func _update_survival(delta: float) -> void:
	hunger = max(0.0, hunger - 0.032 * delta)
	thirst = max(0.0, thirst - 0.065 * delta)
	if hunger <= 0.0:
		health = max(0.0, health - 0.7 * delta)
	if thirst <= 0.0:
		health = max(0.0, health - 1.2 * delta)
	if global_position.y < -20.0:
		global_position = Vector3(0, 12, 18)
	if health <= 0.0 and not dead:
		dead = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(22, 18)
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)
	var help := Label.new()
	help.text = "WASD Hareket  |  SHIFT Koş  |  SPACE Zıpla  |  E Topla  |  B İnşa  |  C Üret  |  ESC Mouse"
	help.position = Vector2(22, 685)
	help.add_theme_font_size_override("font_size", 15)
	layer.add_child(help)
	var cross := Label.new()
	cross.text = "+"
	cross.position = Vector2(636, 342)
	cross.add_theme_font_size_override("font_size", 24)
	layer.add_child(cross)

func _update_hud() -> void:
	if hud:
		hud.text = "Purnakin  |  CAN %3d   AÇLIK %3d   SUSUZLUK %3d   DAYANIKLILIK %3d" % [health, hunger, thirst, stamina]
	if dead and hud:
		hud.text = "ÖLDÜN\nR tuşuna basarak yeniden başla"

func _input(event: InputEvent) -> void:
	if dead and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
