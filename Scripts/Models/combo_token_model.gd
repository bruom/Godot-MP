class_name ComboTokenModel extends TokenModel

var main_unit: UnitData

var is_basic: bool:
	get:
		return main_unit.is_basic if main_unit else true

var cur_timer: int:
	set(new_value):
		cur_timer = max(new_value, 0)
		timer_changed.emit(cur_timer)
var tokens: Array[SingleTokenModel]

var defending: bool = false

signal timer_changed(new_value: int)

func tick_timer():
	cur_timer -= 1

func get_cols() -> Array[int]:
	var cols: Array[int] = []
	cols.assign(range(cur_col, cur_col - dimensions.x, -1))
	return cols

static func create_basic(_tokens: Array[SingleTokenModel]) -> ComboTokenModel:
	var combo = ComboTokenModel.new()
	if _tokens.size() == 1:
		combo.dimensions = _tokens[0].dimensions
		combo.cur_col = _tokens[0].cur_col
		combo.cur_row = _tokens[0].cur_row
	else:
		var min_col = _tokens.map(func(t): return t.cur_col).min()
		var max_col = _tokens.map(func(t): return t.cur_col).max()
		var min_row = _tokens.map(func(t): return t.cur_row).min()
		var max_row = _tokens.map(func(t): return t.cur_row).max()
		combo.dimensions = Vector2i((max_col - min_col) + 1, (max_row - min_row) + 1)
		combo.cur_col = max_col
		combo.cur_row = min_row
	for token in _tokens:
		token.cur_row -= combo.cur_row
		token.cur_col -= combo.cur_col
	combo.tokens = _tokens
	combo.main_unit = _tokens[0].unit
	combo.cur_timer = _tokens[0].unit.timer
	combo.cur_power = _tokens[0].unit.combo_power
	return combo

static func create_nonbasic(main_token: SingleTokenModel, _aux_tokens: Array[SingleTokenModel]) -> ComboTokenModel:
	var combo = ComboTokenModel.new()
	combo.main_unit = main_token.unit
	combo.token_class = main_token.token_class
	combo.dimensions = main_token.dimensions
	combo.cur_col = main_token.cur_col
	combo.cur_row = main_token.cur_row
	combo.tokens.assign([main_token])
	combo.cur_timer = main_token.unit.timer
	combo.cur_power = main_token.unit.combo_power
	main_token.cur_row = 0
	main_token.cur_col = 0
	return combo

func serialize() -> Dictionary:
	var dict = {}
	dict["unit_id"] = main_unit.unit_id
	dict["cur_power"] = cur_power
	dict["cur_row"] = cur_row
	dict["cur_col"] = cur_col
	dict["token_class"] = token_class
	dict["defending"] = defending
	dict["dimensions"] = dimensions
	dict["cur_timer"] = cur_timer
	dict["tokens"] = tokens.map(func(token): return token.serialize())
	return dict

static func deserialize(dict: Dictionary) -> TokenModel:
	var token = ComboTokenModel.new()
	token.main_unit = JsonLoader.all_units[dict["unit_id"]]
	token.cur_power = dict["cur_power"]
	token.cur_row = dict["cur_row"]
	token.cur_col = dict["cur_col"]
	token.token_class = dict["token_class"]
	token.defending = dict["defending"]
	token.dimensions = dict["dimensions"]
	token.cur_timer = dict["cur_timer"]
	token.tokens.assign(dict["tokens"].map(func(data): SingleTokenModel.deserialize(data)))
	return token
