class_name Hero2D extends Node2D

@onready var hp_label = $hp_label
@onready var ap_label = $ap_label

@export var is_player: bool

var model: HeroModel

func setup(_model: HeroModel):
	model = _model
	model.health_changed.connect(update_hp_display)
	model.ap_changed.connect(update_ap_display)
	update_hp_display(model.cur_health)
	update_ap_display(model.cur_ap)

func update_hp_display(hp_value: int):
	hp_label.text = str(hp_value)

func update_ap_display(ap_value: int):
	ap_label.text = str(ap_value)
