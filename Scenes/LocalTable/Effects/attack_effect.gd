class_name AttackEffect extends Node2D

@onready var main_sprite = $main_sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var attack_effect_speed: float = 3500
var idle: bool = true

var flipped: bool = false:
	set(new_value):
		flipped = new_value
		main_sprite.flip_h = new_value
var unit_class: int = 0

func _process(_delta):
	#main_sprite.frame_coords.y = unit_class
	pass

func animate_accel(tween: Tween):
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	var target_position = global_position + Vector2(-100 if flipped else 100, 0)
	tween.tween_property(self, "global_position", target_position, 0.1)
	idle = false
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)

func animate_attack(tween: Tween, target_x):
	#Move to each target, then play the hit effect, repeat
	if idle:
		animation_player.play("idle")
		animate_accel(tween)
	var target_position = Vector2(target_x, global_position.y)
	var distance = abs(target_x - global_position.x)
	tween.tween_property(self, "global_position", target_position, distance / attack_effect_speed)

func animate_finish():
	#expolde when done
	self.queue_free()
