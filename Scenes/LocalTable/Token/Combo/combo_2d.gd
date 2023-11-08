class_name Combo2D extends Token2D

@onready var attack_scene = preload("res://Scenes/LocalTable/Effects/attack_effect.tscn")

@onready var timer_label: Label = $combo_frame/Panel/timer_label
@onready var combo_frame = $combo_frame

var attack_effect: AttackEffect

var opacity: float = 1.0:
	set(new_value):
		opacity = new_value
		set_color()

var token_model: ComboTokenModel

var rows: int:
	get:
		return token_model.dimensions.y
var cols: int:
	get:
		return token_model.dimensions.x
		
var tokens: Array[Token2D]

func _process(_delta):
	if tokens.is_empty():
		queue_free()

func setup(_model: ComboTokenModel, _tokens: Array[Token2D]):
	token_model = _model
	token_model.timer_changed.connect(_on_timer_changed)
	timer_label.text = str(_model.cur_timer)
	combo_frame.size.x = cols * Constants.TILE_SIZE
	combo_frame.size.y = rows * Constants.TILE_SIZE
	tokens = _tokens
	for token in tokens:
		token.reparent(self, true)

func append_attack_anim_to_tween(tween: Tween, target_x_position: float):
	var front_x = global_position.x + (0.0 if flipped else combo_frame.size.x)
	var distance = target_x_position - front_x
	var target_position = Vector2(target_x_position - (0.0 if flipped else combo_frame.size.x), global_position.y)
	
	tween.tween_property(self, "global_position", target_position, distance * 0.0003)
	var original_scale = self.scale
	tween.tween_property(self, "scale", original_scale * 0.7, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.11)

func attack(tween: Tween) -> AttackEffect:
	var attack_position = tokens[0].global_position
	combo_frame.hide()
	
	tween.tween_interval(0.2)
	tween.set_parallel(true)
	for token in tokens:
		token.attack()
		tween.tween_property(token, "global_position", attack_position, 0.25)
	tween.set_parallel(false)
	
	var _attack_effect = attack_scene.instantiate()
	get_parent().add_child(_attack_effect)
	_attack_effect.visible = false
	_attack_effect.flipped = flipped
	_attack_effect.global_position = attack_position
	attack_effect = _attack_effect
	tween.tween_property(_attack_effect, "visible", true, 0.01)
	return _attack_effect


func destroy():
	for token in tokens:
		if token != null:
			token.destroy()

func set_color():
	set_modulate(Color(1.0, 1.0, 1.0, opacity))

func _on_timer_changed(new_value: int):
	timer_label.text = str(new_value)

