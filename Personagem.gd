# Personagem.gd
class_name Personagem
extends CharacterBody3D

## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we move around?
@export var can_move : bool = true
## Can we press to jump?
@export var can_jump : bool = true

@export_group("Gravity")
@export var gravity: float = 150.0
@export var fall_gravity_multiplier: float = 2.0
@export var low_jump_multiplier: float = 2.5

@onready var health_component: HealthComponent = $health_component

@export_group("Speeds")
@export var base_speed: float = 50.0

var move_speed: float = 0.0

func apply_gravity(delta: float, is_holding_jump: bool = false) -> void:
	if not has_gravity:
		return
	if not is_on_floor():
		var gravity_multiplier := 1.0
		if velocity.y < 0:
			gravity_multiplier = fall_gravity_multiplier
		elif velocity.y > 0 and not is_holding_jump:
			gravity_multiplier = low_jump_multiplier
		velocity += Vector3.DOWN * gravity * gravity_multiplier * delta

func take_damage(amount: int) -> void:
	health_component.health -= amount
	

func die() -> void:
	queue_free()  # comportamento padrão; Player pode sobrescrever (respawn, game over, etc.)
