class_name HeroModel extends RefCounted

#TODO: wait to emit this signal, so local_table can choose when to animate
# damage in sync with attacks and such
var cur_health: int = 100:
	set(new_value):
		cur_health = new_value
		health_changed.emit(new_value)

var cur_ap: int = 0:
	set(new_value):
		cur_ap = new_value
		ap_changed.emit(new_value)

var cur_mana: int = 0:
	set(new_value):
		cur_mana = new_value
		mana_changed.emit(new_value)

signal health_changed(new_value: int)
signal ap_changed(new_value: int)
signal mana_changed(new_value: int)

func serialize() -> Dictionary:
	var dict = {}
	dict["cur_health"] = cur_health
	dict["cur_ap"] = cur_ap
	dict["cur_mana"] = cur_mana
	return dict

static func deserialize(dict: Dictionary) -> HeroModel:
	var model = HeroModel.new()
	model.cur_health = dict["cur_health"]
	model.cur_ap = dict["cur_ap"]
	model.cur_mana = dict["cur_mana"]
	return model
