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
@export var leash_range: float = 15.0   # distância máxima do spawn antes de desistir e voltar

var current_state: State = State.IDLE
var target: Node3D = null
var _attack_timer: float = 0.0
var _spawn_position: Vector3

##@onready var floating_bar: FloatingHealthBar = $FloatingHealthBar
@onready var detection_area: Area3D = $Area3D

func _ready() -> void:
	
	print("Spawn registrado em: ", _spawn_position)
	##floating_bar.bind_to(health_component)
	##health_component.died.connect(_on_died)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

var _spawn_captured: bool = false

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	print("RETURNING para: ", _spawn_position, " | Posição atual: ", global_position)
	if not _spawn_captured:
		_spawn_position = global_position
		_spawn_captured = true

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
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

	# Checa o leash: se afastou demais do spawn, desiste e volta
	var distance_from_spawn := global_position.distance_to(_spawn_position)
	if distance_from_spawn > leash_range:
		target = null
		current_state = State.RETURNING
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if distance_to_target <= attack_radius:
		current_state = State.ATTACKING
		return

	var direction := (target.global_position - global_position).normalized()
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z))

func _try_attack(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	# Mesmo atacando, se o alvo se afastar e ultrapassar o leash, desiste
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

	var direction := (_spawn_position - global_position).normalized()
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	
	var look_target := Vector3(_spawn_position.x, global_position.y, _spawn_position.z)
	if not look_target.is_equal_approx(global_position):
		look_at(look_target)

func _on_body_entered(body: Node3D) -> void:
	print(">>> ENTROU: ", body.name, " | Estado atual antes: ", State.keys()[current_state])
	if body.is_in_group("player") and current_state != State.RETURNING:
		target = body
		current_state = State.CHASING
		print(">>> Mudou para CHASING")

func _on_body_exited(body: Node3D) -> void:
	print(">>> SAIU: ", body.name)
	if body == target:
		target = null
		current_state = State.IDLE
		print(">>> Voltou para IDLE (target saiu)")

func _on_died() -> void:
	die()
