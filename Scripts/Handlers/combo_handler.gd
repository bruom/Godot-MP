class_name ComboHandler extends RefCounted

static func get_basic_combos(grid: Array) -> Array:
	var new_basic_combos: Array[Array] = []
	for row in range(0, Constants.NUM_ROWS):
		new_basic_combos.append_array(check_row_for_basic_combos(grid, row))
	return new_basic_combos

static func get_defenders(grid: Array) -> Array:
	var new_defending_combos: Array[Array] = []
	for col in range(0, Constants.NUM_COLS):
		new_defending_combos.append_array(check_col_for_basic_combos(grid, col))
	return new_defending_combos

static func get_nonbasic_combos(grid: Array, nonbasic_units: Array) -> Array:
	var new_nonbasic_combos: Array = []
	for nonbasic_unit in nonbasic_units:
		if nonbasic_unit is ComboTokenModel:
			#ignore preexisting combos
			continue
		
		var valid: bool = false
		var aux_units: Array[TokenModel] = []
		if nonbasic_unit.unit.size == Enums.TokenSizes.LARGE:
			var aux_indexes = aux_indexes_for_large_unit(nonbasic_unit.position)
			aux_units = get_units_for_indexes(grid, aux_indexes)
			valid = aux_units.size() == 4
		elif nonbasic_unit.unit.size == Enums.TokenSizes.MEDIUM:
			var aux_indexes = aux_indexes_for_medium_unit(nonbasic_unit.position)
			aux_units = get_units_for_indexes(grid, aux_indexes)
			valid = aux_units.size() == 2
		
		valid = valid && aux_units.reduce(
			func(accum, unit):
				var valid_unit = unit.token_class == nonbasic_unit.token_class
				valid_unit = valid_unit && unit is SingleTokenModel
				valid_unit = valid_unit && !unit.defending
				return accum && valid_unit,
			true
		)
		if valid:
			aux_units.push_front(nonbasic_unit)
			new_nonbasic_combos.append(aux_units)
	return new_nonbasic_combos

static func would_reinforcement_create_combo(grid: Array, row: int, col: int, unit_class: int) -> bool:
	var temp_grid = grid.duplicate(true)
	temp_grid[row][col] = SingleTokenModel.create(UnitData.new(), unit_class)
	
	var creates_combo: bool = false
	var row_array: Array[TokenModel] = []
	row_array.assign(temp_grid[row])
	creates_combo = creates_combo || !check_line_for_basic_combos(row_array).is_empty()
	var col_array: Array[TokenModel] = []
	col_array.assign(range(0, Constants.NUM_ROWS).map(func(r): return temp_grid[r][col]))
	creates_combo = creates_combo || !check_line_for_basic_combos(col_array).is_empty()
	var nonbasics_in_row: Array[TokenModel] = []
	for token in grid[row]:
		if token is SingleTokenModel && !token.is_basic && token.token_class == unit_class:
			nonbasics_in_row.append(token)
	creates_combo = creates_combo || !get_nonbasic_combos(temp_grid, nonbasics_in_row).is_empty()
	
	return creates_combo

#Helpers

static func check_row_for_basic_combos(grid: Array, row: int) -> Array:
	var line: Array[TokenModel] = []
	line.assign(grid[row])
	return check_line_for_basic_combos(line)

static func check_col_for_basic_combos(grid: Array, col: int) -> Array:
	var line: Array[TokenModel] = []
	line.assign(range(0, Constants.NUM_ROWS).map(func(row): return grid[row][col]))
	return check_line_for_basic_combos(line)

static func check_line_for_basic_combos(line: Array[TokenModel]) -> Array:
	var new_combos: Array = []
	var tentative_combo: Array[SingleTokenModel] = []
	for token in line:
		
		if is_valid_for_combo(tentative_combo, token):
			tentative_combo.append(token)
		else:
			if tentative_combo.size() >= 3:
				new_combos.append(tentative_combo)
			tentative_combo = []
			if is_valid_for_combo(tentative_combo, token):
				tentative_combo.append(token)

	#End of row:
	if tentative_combo.size() >= 3:
		new_combos.append(tentative_combo)
	tentative_combo = []
	
	return new_combos

static func is_valid_for_combo(tentative_combo: Array[SingleTokenModel], candidate: TokenModel) -> bool:
	if candidate == null || candidate is ComboTokenModel:
		return false
	var combo_class: int = -1 if tentative_combo.is_empty() else tentative_combo[0].token_class
	return !candidate.defending && candidate.is_basic && (candidate.token_class == combo_class || tentative_combo.is_empty())

static func get_units_for_indexes(grid: Array, indexes: Array[Vector2i]) -> Array[TokenModel]:
	var units: Array[TokenModel] = []
	for index in indexes:
		if index.x < 0 || index.x >= Constants.NUM_COLS || index.y < 0 || index.y >= Constants.NUM_ROWS:
			return []
		var this_unit = grid[index.y][index.x]
		if this_unit && !units.has(this_unit):
			units.append(this_unit)
	return units

static func aux_indexes_for_large_unit(large_unit_position: Vector2i) -> Array[Vector2i]:
	var indexes: Array[Vector2i] = []
	for col in range (1, 3):
		for row in range (0, 2):
			indexes.append(large_unit_position + Vector2i(col, row))
	return indexes

static func aux_indexes_for_medium_unit(medium_unit_position: Vector2i) -> Array[Vector2i]:
	var indexes: Array[Vector2i] = []
	for col in range (1, 3):
		indexes.append(medium_unit_position + Vector2i(col, 0))
	return indexes
