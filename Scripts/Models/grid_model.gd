#Responsible for holding a stateful representation of tokens in a grid, and
#handling the operations that can be applied to these tokens
class_name GridModel extends RefCounted

# indexed as tokens[row][col], with col starting at the front
# 0,0 is first token of top row, 2,2 is last token of bottom row
var tokens: Array = []

var all_combos: Array[ComboTokenModel]:
	get:
		var result: Array[ComboTokenModel] = []
		for token in all_tokens:
			if token is ComboTokenModel && !result.has(token):
				result.append(token)
		return result

var all_tokens: Array[TokenModel]:
	get:
		var result: Array[TokenModel] = []
		for row in tokens:
			for token in row:
				if token != null:
					result.append(token)
		return result

var all_unique_tokens: Array[TokenModel]:
	get:
		var result: Array[TokenModel] = []
		for row in tokens:
			for token in row:
				if token != null && !result.has(token):
					result.append(token)
		return result

var nonbasic_tokens: Array[TokenModel]:
	get:
		var result: Array[TokenModel] = []
		ArrayHelpers.append_unique(result, all_tokens.filter(func(t): return !t.is_basic))
		return result

var token_tile_count: int:
	get:
		return all_tokens.reduce(func(acc, token): return acc + (token.dimensions.x * token.dimensions.y), 0)

# true when pending events exist; should disable user inputs while resolving
var resolving: bool:
	get:
		return !event_queue.is_empty()
var event_queue: Array[GridEvent] = []

var should_emit_events: bool = false
signal grid_events(events: Array[GridEvent])

func _init():
	for x in range(Constants.NUM_ROWS):
		tokens.append([])
		tokens[x].resize(Constants.NUM_COLS)

# Events

func emit_events():
	should_emit_events = true

func trigger_effects():
	# Priority 1: form any new combos, all at once
	var pending_basic_combos = ComboHandler.get_basic_combos(tokens)
	var pending_nonbasic_combos = ComboHandler.get_nonbasic_combos(tokens, nonbasic_tokens)
	var pending_defenders = ComboHandler.get_defenders(tokens)
	
	if !pending_basic_combos.is_empty() || !pending_nonbasic_combos.is_empty() || !pending_defenders.is_empty():
		var token_array: Array[SingleTokenModel] = []
		for combo in pending_nonbasic_combos:
			token_array.assign(combo)
			form_nonbasic_combo(token_array.duplicate())
		for combo in pending_basic_combos:
			token_array.assign(combo)
			form_basic_combo(token_array.duplicate())
		for combo in pending_defenders:
			token_array.assign(combo)
			defend(token_array.duplicate())
		return
	
	# Priority 2: shift any defending units that need shifting, all at once
	var shifting: bool = false
	for defending_token in all_tokens.filter(func(t): 
		return t is SingleTokenModel && t.defending
	):
		if shift_defending(defending_token):
			shifting = true
	if shifting:
		return
	
	# Priority 3: shift any combos that need shifting, all at once
	for combo in all_combos:
		if shift_combo(combo):
			shifting = true
	if shifting:
		return
	
	# Priority 4: shift idle units that need shifting, all at once
	if shift_tokens():
		return
	
	# If none of the above are needed, finish resolving effects for now
	if should_emit_events:
		should_emit_events = false
		grid_events.emit(event_queue.duplicate(true))
		event_queue = []

# Token Operations

func clear_token_from_grid(token: TokenModel):
	for row in tokens.size():
		for col in tokens[row].size():
			if tokens[row][col] == token:
				tokens[row][col] = null

func set_token_at(token: TokenModel,  row: int, col: int):
	if token.cur_row > -1 || token.cur_col > -1:
		for aux_row in range(token.cur_row, token.cur_row + token.dimensions.y):
			for aux_col in range(token.cur_col, token.cur_col - token.dimensions.x, -1):
				if tokens[aux_row][aux_col] == token:
					tokens[aux_row][aux_col] = null
	
	if row > -1 && col > -1:
		for aux_row in range(row, row + token.dimensions.y):
			for aux_col in range(col, col - token.dimensions.x, -1):
				tokens[aux_row][aux_col] = token

func add_token(token: TokenModel, row: int) -> bool:
	var rows = range(row, row + token.dimensions.y)
	var target_col = -1
	for aux_row in rows:
		target_col = max(get_last_occupied_col_in_row(aux_row) + token.dimensions.x, target_col)
	if target_col >= token.dimensions.x - 1 && target_col < Constants.NUM_COLS:
		set_token_at(token, row, target_col)
		token.set_position(row, target_col)
		#token_added.emit(token, row, target_col)
		event_queue.append(AddTokenEvent.create(token, Vector2i(target_col, row)))
		return true
	return false

func move_token(from_row: int, to_row: int) -> bool:
	if from_row != to_row:
		var token_to_move = get_last_unit_in_row(from_row)
		if token_to_move != null && token_to_move is SingleTokenModel:
			var target_col = preview_col_for_unit(token_to_move, to_row)
			if target_col > -1:
				set_token_at(token_to_move, to_row, target_col)
				token_to_move.set_position(to_row, target_col)
				#token_moved.emit(token_to_move, to_row, target_col)
				event_queue.append(MoveTokenEvent.create(token_to_move, Vector2i(token_to_move.cur_col, token_to_move.cur_row), Vector2i(target_col, to_row)))
				return true
	return false

func remove_at(row: int, col: int) -> bool:
	if row < 0 || row >= Constants.NUM_ROWS || col < 0 || col >= Constants.NUM_COLS:
		return false
	if tokens[row][col] != null:
		var token = tokens[row][col]
		if token != null:
			for aux_row in range(token.cur_row, row + token.dimensions.y):
				for aux_col in range(token.cur_col, col - token.dimensions.x, -1):
					if tokens[aux_row][aux_col] == token:
						tokens[aux_row][aux_col] = null
			#token_removed.emit(token, row, col)
			event_queue.append(RemoveTokenEvent.create(token, Vector2i(token.cur_col, token.cur_row)))
			shift_tokens()
			return true
	return false

func remove_token(token: TokenModel) -> bool:
	if tokens[token.cur_row][token.cur_col] == token:
		clear_token_from_grid(token)
		event_queue.append(RemoveTokenEvent.create(token, Vector2i(token.cur_col, token.cur_row)))
		shift_tokens()
		return true
	return false

func remove_tokens(tokens_to_remove: Array[TokenModel]):
	for token in tokens_to_remove:
		if tokens[token.cur_row][token.cur_col] == token:
			clear_token_from_grid(token)
			event_queue.append(RemoveTokenEvent.create(token, Vector2i(token.cur_col, token.cur_row)))
	shift_tokens()

func shift_tokens() -> bool:
	var shifting: bool = false
	for row in tokens.size():
		for col in tokens[row].size():
			var token = tokens[row][col]
			if token != null && token is SingleTokenModel:
				if shift_token(token):
					shifting = true
	return shifting

func shift_token(token: SingleTokenModel) -> bool:
	var width = token.dimensions.x
	var rows = token.get_rows()
	var col = token.cur_col
	if col == width - 1:
		return false
	var target_col = find_shift_target_col(token)
	if target_col != col:
		set_token_at(token, rows[0], target_col)
		token.set_position(rows[0], target_col)
		#token_moved.emit(token, rows[0], target_col)
		event_queue.append(MoveTokenEvent.create(token, Vector2i(token.cur_col, token.cur_row), Vector2i(target_col, rows[0])))
		return true
	return false

func find_shift_target_col(token: TokenModel) -> int:
	var rows = token.get_rows()
	var width = token.dimensions.x
	for col in range(token.cur_col - width, -1, - 1):
		for row in rows:
			if tokens[row][col] != null:
				return col + width
	return width - 1

func shift_defending(token: SingleTokenModel) -> bool:
	if !token.defending:
		return false
	var row = token.cur_row
	var col = token.cur_col
	if col == 0:
		return false
	var target_col = -1
	for col_ahead in range(0, token.cur_col):
		if tokens[row][col_ahead] == null || !tokens[row][col_ahead].defending:
			target_col = col_ahead
			break
	if target_col > -1:
		return insert_token_at(token, row, target_col)
	return false

func shift_combo(combo: ComboTokenModel) -> bool:
	var combo_rows: Array[int] = combo.get_rows()
	var current_cols: Array[int] = combo.get_cols()
	var cur_front_col: int = current_cols.min()
	var valid_front_col: int = -1
	for col in range(cur_front_col-1, -1, -1):
		var col_is_valid: bool = true
		for row in combo_rows:
			if tokens[row][col] && (tokens[row][col] is ComboTokenModel || tokens[row][col].defending):
				col_is_valid = false
		if col_is_valid:
			valid_front_col = col
			continue
	
	if valid_front_col > -1:
		for target_col in range(valid_front_col + (combo.dimensions.x - 1), combo.cur_col):
			if insert_token_at(combo, combo.cur_row, target_col):
				return true
	return false

func insert_token_at(token: TokenModel, row: int, col: int) -> bool:
	if col >= Constants.NUM_COLS || col - (token.dimensions.x -1) < 0:
		return false
	
	var original_coords: Vector2i = Vector2i(token.cur_col, token.cur_row)
	clear_token_from_grid(token)
	
	var rows = range(row, row + token.dimensions.y)
	
	#get the first token in each affected row that needs to be pushed back
	var lead_tokens: Array[TokenModel] = []
	for aux_row in rows:
		for aux_col in range(col - (token.dimensions.x - 1), col + 1):
			if tokens[aux_row][aux_col] != null:
				lead_tokens.append(tokens[aux_row][aux_col])
				break
	
	var affected_tokens: Dictionary = {}
	var resulting_events: Array[GridEvent] = []
	
	var can_move: bool = true
	for lead_token in lead_tokens:
		affected_tokens[lead_token] = Vector2i(lead_token.cur_col, lead_token. cur_row)
		var lead_token_front_col = lead_token.cur_col -(lead_token.dimensions.x - 1)
		can_move = can_move && push_back(lead_token, (col + 1) - lead_token_front_col, affected_tokens, resulting_events)
	
	if can_move:
		set_token_at(token, row, col)
		token.set_position(row, col)
		resulting_events.append(MoveTokenEvent.create(token, original_coords, Vector2i(col, row)))
		event_queue.append_array(resulting_events)
		return true
	else:
		#revert
		for affected_token in affected_tokens.keys():
			set_token_at(affected_token, affected_tokens[affected_token].y, affected_tokens[affected_token].x)
			token.set_position(affected_tokens[affected_token].y, affected_tokens[affected_token].x)
		set_token_at(token, original_coords.y, original_coords.x)
		token.set_position(original_coords.y, original_coords.x)
		resulting_events = []
		return false

func push_back(token: TokenModel, amount: int, affected_tokens: Dictionary, events: Array[GridEvent]) -> bool:
	if token.cur_col + amount >= Constants.NUM_COLS:
		return false
	
	var rows = token.get_rows()
	var lead_tokens: Array[TokenModel] = []
	for row in rows:
		for col in range(token.cur_col +1, token.cur_col + amount + 1):
			if tokens[row][col]:
				if !lead_tokens.has(tokens[row][col]):
					lead_tokens.append(tokens[row][col])
				break
	
	var can_move = true
	for lead_token in lead_tokens:
		affected_tokens[lead_token] = Vector2i(lead_token.cur_col, lead_token. cur_row)
		var lead_token_front_col = lead_token.cur_col -(lead_token.dimensions.x - 1)
		var displacement_amount = (token.cur_col + amount + 1) - lead_token_front_col
		can_move = can_move && push_back(lead_token, displacement_amount, affected_tokens, events)
	
	if can_move:
		var start_pos = Vector2i(token.cur_col, token.cur_row)
		set_token_at(token, token.cur_row, token.cur_col + amount)
		token.set_position(token.cur_row, token.cur_col + amount)
		var end_pos = Vector2i(token.cur_col, token.cur_row)
		events.append(MoveTokenEvent.create(token, start_pos, end_pos))
		return true
	return false

# Combos

func form_nonbasic_combo(new_combo: Array[SingleTokenModel]):
	var nonbasics = new_combo.filter(func(t): return !t.is_basic)
	var basic_tokens = new_combo.filter(func(t): return t.is_basic)
	if nonbasics.size() != 1:
		return
	var main_token = nonbasics[0]
	var combo_model = ComboTokenModel.create_nonbasic(main_token, basic_tokens)
	for token in basic_tokens:
		clear_token_from_grid(token)
	clear_token_from_grid(main_token)
	set_token_at(combo_model, combo_model.cur_row, combo_model.cur_col)
	
	event_queue.append(FormNonbasicComboEvent.create(combo_model, basic_tokens, combo_model.position))

func form_basic_combo(new_combo: Array[SingleTokenModel]):
	for token in new_combo:
		if !all_tokens.has(token):
			return
	for token in new_combo:
		clear_token_from_grid(token)
	var combo_model = ComboTokenModel.create_basic(new_combo)
	set_token_at(combo_model, combo_model.cur_row, combo_model.cur_col)

	event_queue.append(FormComboEvent.create(combo_model, combo_model.position))

func defend(new_combo: Array[SingleTokenModel]):
	for token in new_combo:
		#true when both a horizontal and a vertical combo are made at once, using
		# the same unit
		if !all_tokens.has(token):
			pass
			#add_extra_defender(token)
		else:
			token.defending = true
			#token_defending.emit(token)
			event_queue.append(DefendEvent.create(token))

# CURRENTLY BROKEN
#When a unit would become part of both a horizontal and a vertical combo at the
# same time, it gets assigned to the horizontal combo.
# An attempt is made to create a duplicate of this unit to be assigned to the
# vertical combo, but if there is no room, the vertical combo is formed with 
# only the two remaining units
func add_extra_defender(defender: SingleTokenModel) -> bool:
	if !row_is_full(defender.cur_row):
		defender.defending = true
		var temp_col = get_last_occupied_col_in_row(defender.cur_row) + 1
		defender.set_position(defender.cur_row, temp_col)
		tokens[defender.cur_row][temp_col] = defender
		#extra_defender_added.emit(defender, defender.cur_col)
		event_queue.append(AddDefenderEvent.create(defender))
	return false

# Unit Placement

func get_last_unit_in_row(row: int) -> TokenModel:
	var last_col = get_last_occupied_col_in_row(row)
	if last_col > -1:
		return tokens[row][last_col]
	return null

#Checks whether a target row can receive a unit being moved, and where it would end up
func preview_col_for_unit(unit: SingleTokenModel, target_row: int) -> int:
	var rows = range(target_row, target_row + unit.dimensions.y)
	var target_col = -1
	clear_token_from_grid(unit)
	for row in rows:
		target_col = max(get_last_occupied_col_in_row(row) + unit.dimensions.x, target_col)
	set_token_at(unit, unit.cur_row, unit.cur_col)
	if target_col >= unit.dimensions.x - 1 && target_col < Constants.NUM_COLS:
		return target_col
	return -1

func get_last_occupied_col_in_row(row: int) -> int:
	if row < 0 || row >= Constants.NUM_ROWS:
		return -1
	var last_occupied_col: int = -1
	for i in range(Constants.NUM_COLS-1, -1, -1):
		if tokens[row][i] != null:
			last_occupied_col = i
			break
	return last_occupied_col

func row_is_full(row: int) -> bool:
	return get_last_occupied_col_in_row(row) == Constants.NUM_COLS-1

func get_units_behind_unit(unit: TokenModel, ignore_rows: Array[int] = []) -> Array[TokenModel]:
	var units_behind: Array[TokenModel] = []
	if unit.cur_col == Constants.NUM_COLS-1:
		return units_behind
	for row in unit.get_rows():
		if ignore_rows.has(row):
			continue
		for col in range(unit.cur_col + 1, Constants.NUM_COLS):
			var this_token = tokens[row][col]
			if this_token && !units_behind.has(this_token):
				units_behind.append(this_token)
	
	for unit_behind in units_behind:
		if !ArrayHelpers.is_array_subset_of_other(unit_behind.get_rows(), unit.get_rows()):
			ArrayHelpers.append_unique(units_behind, get_units_behind_unit(unit_behind))
	
	return units_behind

# Serialization

func serialize() -> Dictionary:
	var dict = {}
	dict["tokens"] = tokens.map(
		func(row): return row.map(
			func(token): return null if token == null else token.serialize()
		)
	)
	return dict

static func deserialize(dict: Dictionary) -> GridModel:
	var line = GridModel.new()
	line.tokens.assign(dict["tokens"].map(
		func(row): return row.map(
			func(token): return null if token == null else SingleTokenModel.deserialize(token))
		)
	)
	return line
