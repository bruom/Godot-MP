class_name TokenModel extends RefCounted

var cur_power: int:
	set(new_value):
		cur_power = max(new_value, 0)

#For SingleTokens that are part of a Combo, these values are relative to the
# Combo's origin
var cur_row: int = -1
var cur_col: int = -1

var position: Vector2i:
	get:
		return Vector2i(cur_col, cur_row)
	set(new_value):
		cur_col = new_value.x
		cur_row = new_value.y

var dimensions: Vector2i = Vector2i(1,1)

var token_class: int

func get_rows() -> Array[int]:
	var rows: Array[int] = []
	for i in range(0, dimensions.y):
		rows.append(cur_row + i)
	return rows

func set_position(row: int, col: int):
	cur_row = row
	cur_col = col

static func deserialize(_dict: Dictionary) -> TokenModel:
	return SingleTokenModel.new()
