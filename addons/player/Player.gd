class_name Player
extends Personagem

signal stamina_changed(new_Stamina: float, max_stamina: float)
signal stamina_depleted
signal stamina_full

@export var max_stamina: float = 100.0
@export var regen_rate: float = 20.0        # stamina por segundo
@export var regen_delay: float = 1.0        # segundos parado sem gastar antes de regenerar
@export var drain_rate: float = 25.0        # stamina por segundo ao segurar sprint, por ex.

@onready var hud: CanvasLayer = $HUD
@onready var health_bar: HealthBar = $HUD/HealthBarContainer/HealthBar
@onready var damage_trail_bar: ProgressBar = $HUD/HealthBarContainer/DamageTrail
@onready var stamina_bar: ProgressBar = $HUD/StaminaBar

var stamina: float = max_stamina:
	set(value):
		var old_value := stamina
		stamina = clamp(value, 0, max_stamina)
		stamina_changed.emit(stamina, max_stamina)
		if stamina <= 0 and old_value > 0:
			stamina_depleted.emit()
		elif stamina >= max_stamina and old_value < max_stamina:
			stamina_full.emit()

var _time_since_last_use: float = 0.0
var _is_draining: bool = false

func _on_health_changed(current: int, max: int) -> void:
	health_bar.max_value = max
	health_bar.value = current
	
	damage_trail_bar.max_value = max
	var tween := create_tween()
	tween.tween_property(damage_trail_bar, "value", current, 0.5).set_delay(0.2)




func _on_stamina_changed(current: int, max: int) -> void:
	stamina_bar.max_value = max
	stamina_bar.value = current

func get_stamina() -> float:
	return stamina
func set_stamina(value: float) -> void:
	stamina = clamp(value, 0, max_stamina)
	
func _process(delta: float) -> void:
	if _is_draining:
		_time_since_last_use = 0
	else:
		_time_since_last_use += delta
		if _time_since_last_use >= regen_delay and stamina < max_stamina:
			stamina += regen_rate * delta
	
	_is_draining = false

func drain(delta: float, custom_rate: float = -1.0) -> bool:
	var rate := custom_rate if custom_rate >= 0.0 else drain_rate
	if stamina <= 0.0:
		_is_draining = true
		return false
	stamina -= rate * delta
	_is_draining = true
	return true
	
func try_consume(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	_time_since_last_use = 0.0
	return true
	
func has_stamina(amount: float = 0) -> bool:
	return stamina > amount



## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.004


## Speed of jump.
@export var jump_velocity : float = 150
## How fast do we run?
@export var sprint_speed : float = 500.0
## How fast do we freefly?
@export var freefly_speed : float = 2500.0




@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_rotation : Vector2
var freeflying : bool = false


## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	health_bar.bind_to(health_component)
	health_component.set_Health(100) ##deve dar set_Health pra cada entidade (inimigos, bosses)
	stamina = max_stamina
	stamina_changed.connect(_on_stamina_changed)
	$HUD/StaminaBar.value = stamina

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity (assimétrica: sobe normal, cai mais rápido)
	if has_gravity:
		if not is_on_floor():
			var gravity_multiplier := 1.0
			if velocity.y < 0:
				# Caindo
				gravity_multiplier = fall_gravity_multiplier
			elif velocity.y > 0 and not Input.is_action_pressed(input_jump):
				# Subindo, mas soltou o botão -> corta o pulo
				gravity_multiplier = low_jump_multiplier
			velocity += Vector3.DOWN * gravity * gravity_multiplier * delta
	
	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
	
	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
		if drain(delta):
			move_speed = sprint_speed
			
		else:
			move_speed = base_speed
	else:
		move_speed = base_speed
		
	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0
	
	# Use velocity to actually move
	move_and_slide()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
		
