# health_bar.gd
class_name HealthBar
extends ProgressBar

@export var animate_transition: bool = true
@export var transition_duration: float = 0.3
@export var use_damage_trail: bool = true
@export var damage_trail_delay: float = 0.4
@export var damage_trail_duration: float = 0.7


@onready var damage_trail: ProgressBar = get_node_or_null("../DamageTrail")

var _health_component: HealthComponent

func bind_to(health_component: HealthComponent) -> void:
	_health_component = health_component
	max_value = health_component.max_health
	value = health_component.health
	if damage_trail:
		damage_trail.max_value = health_component.max_health
		damage_trail.value = health_component.health
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max: float) -> void:
	max_value = max
	if animate_transition:
		var tween := create_tween()
		tween.tween_property(self, "value", current, transition_duration)
	else:
		value = current

	if damage_trail and use_damage_trail:
		damage_trail.max_value = max
		var trail_tween := create_tween()
		trail_tween.tween_property(damage_trail, "value", current, damage_trail_duration).set_delay(damage_trail_delay)

	
