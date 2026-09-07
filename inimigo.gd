# Inimigo.gd
class_name Inimigo
extends Personagem

enum State { IDLE, CHASING, ATTACKING, RETURNING }

@export_group("IA")
@export var detection_radius: float = 8.0
@export var attack_radius: float = 1.5
@export var chase_speed: float = 200.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.2
@export var leash_range: float = 15.0
@export var deceleration: float = 800.0   # velocidade de frenagem ao entrar em IDLE

var current_state: State = State.IDLE
var target: Node3D = null
var _attack_timer: float = 0.0
var _spawn_position: Vector3
var _spawn_captured: bool = false

@onready var detection_area: Area3D = $Area3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	

func _physics_process(delta: float) -> void:
	apply_gravity(delta)

	if not _spawn_captured:
		_spawn_position = global_position
		_spawn_captured = true

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)
			velocity.z = move_toward(velocity.z, 0, deceleration * delta)
		State.CHASING:
			_chase_target(delta)
		State.ATTACKING:
			_try_attack(delta)
		State.RETURNING:
			_return_to_spawn(delta)

	move_and_slide()

func _chase_target(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	var distance_from_spawn := global_position.distance_to(_spawn_position)
	if distance_from_spawn > leash_range:
		target = null
		current_state = State.RETURNING
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if distance_to_target <= attack_radius:
		current_state = State.ATTACKING
		return

	nav_agent.target_position = target.global_position
	nav_agent.target_position = target.global_position
	print("Path size: ", nav_agent.get_current_navigation_path().size(),
	" | Nav finished: ", nav_agent.is_navigation_finished(),
	" | Agent pos: ", global_position,
	" | Next point: ", nav_agent.get_next_path_position())
	_move_along_path(chase_speed)

func _try_attack(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	var distance_from_spawn := global_position.distance_to(_spawn_position)
	if distance_from_spawn > leash_range:
		target = null
		current_state = State.RETURNING
		return

	var distance := global_position.distance_to(target.global_position)
	if distance > attack_radius:
		current_state = State.CHASING
		return

	velocity.x = 0
	velocity.z = 0
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func _return_to_spawn(delta: float) -> void:
	var distance := global_position.distance_to(_spawn_position)
	if distance <= 0.5:
		velocity.x = 0
		velocity.z = 0
		current_state = State.IDLE
		return

	nav_agent.target_position = _spawn_position
	_move_along_path(chase_speed)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		target = body
		current_state = State.CHASING

func _move_along_path(speed: float) -> void:
	if nav_agent.is_navigation_finished():
		return
	
	var next_path_position := nav_agent.get_next_path_position()
	var direction := (next_path_position - global_position).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	if direction.length() > 0.01:
		look_at(Vector3(next_path_position.x, global_position.y, next_path_position.z))

func _on_body_exited(body: Node3D) -> void:
	if body == target:
		target = null
		current_state = State.RETURNING   # antes ia pra IDLE — agora tenta voltar ao spawn de verdade

func _on_died() -> void:
	die()
