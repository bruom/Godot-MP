class_name Combo2D extends Token2D

@onready var timer_label: Label = $combo_frame/Panel/timer_label
@onready var combo_frame = $combo_frame

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

func set_color():
	set_modulate(Color(1.0, 1.0, 1.0, opacity))

func _on_timer_changed(new_value: int):
	timer_label.text = str(new_value)
