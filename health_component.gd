class_name HealthComponent
extends Node

signal health_changed(current: int, max: int)
signal died

var health: int = max_health:
	set(value):
		health = clamp(value, 0.0, max_health)
		health_changed.emit(health, max_health)
		if health <= 0:
			died.emit()

@export var max_health: int

func get_Health() -> int:
	return health
func set_Health(value: int) -> void:
	health = clamp(value, 0, max_health)
