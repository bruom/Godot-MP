class_name SingleTokenModel extends TokenModel

var is_destroyed: bool = false

var unit: UnitData

var defending: bool = false

var is_basic: bool:
	get:
		return unit.is_basic

func duplicate() -> SingleTokenModel:
	var new_model = SingleTokenModel.new()
	new_model.unit = unit
	new_model.cur_power = cur_power
	new_model.token_class = token_class
	return new_model

static func create(_unit: UnitData, _token_class: int) -> SingleTokenModel:
	var model = SingleTokenModel.new()
	model.unit = _unit
	model.cur_power = _unit.idle_power
	model.token_class = _token_class
	model.dimensions = _unit.dimensions
	return model

static func create_wall(base_power: int) -> SingleTokenModel:
	var model = SingleTokenModel.new()
	model.unit = JsonLoader.all_units[3]
	model.cur_power = base_power
	model.dimensions = model.unit.dimensions
	model.defending = true
	return model

func serialize() -> Dictionary:
	var dict = {}
	dict["unit_id"] = unit.unit_id
	dict["is_destroyed"] = is_destroyed
	dict["cur_power"] = cur_power
	dict["cur_row"] = cur_row
	dict["cur_col"] = cur_col
	dict["token_class"] = token_class
	dict["defending"] = defending
	dict["dimensions"] = dimensions
	return dict

static func deserialize(dict: Dictionary) -> TokenModel:
	var token = SingleTokenModel.new()
	token.unit = JsonLoader.all_units[dict["unit_id"]]
	token.is_destroyed = dict["is_destroyed"]
	token.cur_power = dict["cur_power"]
	token.cur_row = dict["cur_row"]
	token.cur_col = dict["cur_col"]
	token.token_class = dict["token_class"]
	token.defending = dict["defending"]
	token.dimensions = dict["dimensions"]
	return token
