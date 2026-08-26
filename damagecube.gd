# damage_cube.gd
extends Area3D

@export var damage_amount: int = 10
@export var damage_interval: float = 1.0   # segundos entre ticks de dano, se ficar parado dentro
@export var damage_once: bool = false       # true = dano só na entrada, false = dano contínuo por tempo

var _bodies_inside: Dictionary = {}  # body -> tempo desde o último dano

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if damage_once:
		return
	for body in _bodies_inside.keys():
		_bodies_inside[body] += delta
		if _bodies_inside[body] >= damage_interval:
			_bodies_inside[body] = 0.0
			_deal_damage(body)

# damage_cube.gd
func _on_body_entered(body: Node3D) -> void:
	print("Script anexado: ", body.get_script())
	if not body.has_method("take_damage"):
		return
	_deal_damage(body)
	
	if damage_once:
		_deal_damage(body)
	else:
		_bodies_inside[body] = 0.0
		_deal_damage(body)  # já causa dano imediato ao entrar, e continua no _process

func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)

func _deal_damage(body: Node3D) -> void:
	body.take_damage(damage_amount)
