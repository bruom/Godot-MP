class_name GameManager extends Node

var player_a: PlayerData
var player_b: PlayerData
var table_state: TableModel = TableModel.new()

var turn_player: PlayerData

signal token_events(events: Array[TokenEvent])

func _process(_delta):
	table_state.player_a_grid.trigger_effects()
	table_state.player_b_grid.trigger_effects()

#Regularly used when moving from one turn to the next, switching active player
func tick_turn():
	var next_turn_player = player_a if turn_player == player_b else player_b
	begin_turn(next_turn_player)

#Can be directly called to set a player's turn, such as for the first turn of the match
func begin_turn(player: PlayerData):
	turn_player = player
	var grid = table_state.player_a_grid if player == player_a else table_state.player_b_grid
	var hero = table_state.player_a_hero if player == player_a else table_state.player_b_hero
	
	hero.cur_ap = 3
	
	var all_combos = grid.all_combos
	all_combos.map(func(combo): combo.tick_timer())
	
	var ready_combos = all_combos.filter(func(combo): return combo.cur_timer == 0)
	for ready_combo in ready_combos:
		handle_attack(ready_combo, turn_player)

func handle_attack(combo_model: ComboTokenModel, attacking_player: PlayerData):
	var rows = combo_model.get_rows()
	var events: Array[TokenEvent] = []
	
	var attacking_grid = table_state.player_a_grid if attacking_player == player_a else table_state.player_b_grid
	var defending_grid = table_state.player_b_grid if attacking_player == player_a else table_state.player_a_grid
	var destroyed_defender_units: Array[TokenModel] = []
	
	for col in range(0, Constants.NUM_COLS):
		var defenders: Array[TokenModel] = []
		for row in rows:
			var front_token = defending_grid.tokens[row][col]
			if front_token != null && !defenders.has(front_token) && front_token.cur_power > 0:
				defenders.append(front_token)
			for defender in defenders:
				var power_change = min(combo_model.cur_power, defender.cur_power)
				defender.cur_power -= power_change
				combo_model.cur_power -= power_change
				
				events.append(AttackEvent.create(combo_model, defender))
				events.append(ChangePowerEvent.create(combo_model, -power_change))
				events.append(ChangePowerEvent.create(defender, -power_change))
				
				if defender.cur_power <= 0 && !destroyed_defender_units.has(defender):
					destroyed_defender_units.append(defender)
					events.append(DestroyEvent.create(defender))
		if combo_model.cur_power <= 0:
			break
	
	if combo_model.cur_power > 0:
		var defending_hero = table_state.player_b_hero if attacking_player == player_a else table_state.player_a_hero
		events.append(AttackEvent.create(combo_model, null))
		defending_hero.cur_health -= combo_model.cur_power
	
	defending_grid.remove_tokens(destroyed_defender_units)
	attacking_grid.remove_token(combo_model)
	
	events.append(DestroyEvent.create(combo_model))
	token_events.emit(events)

#Player Actions

func basic_move(player: PlayerData, from_row: int, to_row: int) -> bool:
	var grid = table_state.player_a_grid if turn_player == player_a else table_state.player_b_grid
	var hero = table_state.player_a_hero if turn_player == player_a else table_state.player_b_hero
	
	if hero.cur_ap >= 1 && turn_player == player:
		var success = grid.move_token(from_row, to_row)
		if success:
			hero.cur_ap -= 1
			return true
	return false

func basic_remove(player: PlayerData, row: int, col: int) -> bool:
	var grid = table_state.player_a_grid if turn_player == player_a else table_state.player_b_grid
	var hero = table_state.player_a_hero if turn_player == player_a else table_state.player_b_hero
	
	if hero.cur_ap >= 1 && turn_player == player:
		var success = grid.remove_at(row, col)
		if success:
			hero.cur_ap -= 1
			return true
	return false

#Effects

func damage_unit(target: TokenModel, grid: GridModel, amount: int):
	target.cur_power -= amount
	if target.cur_power < 0:
		grid.remove_token(target)
		token_events.emit([DestroyEvent.create(target)])

#Generate Reinforcements

func generate_reinforcements(reinforcements_player: PlayerData) -> Array[TokenModel]:
	var added_units: Array[TokenModel] = []
	
	var grid = table_state.player_a_grid if reinforcements_player == player_a else table_state.player_b_grid
	
	var reinforcements: Array[TokenModel] = ReinforcementsHandler.generate_reinforcements(grid.tokens)
	added_units.append_array(place_reinforcements(grid, reinforcements))
	
	#If ideal reinforcements could not be placed, loosen restrictions to hit desired
	# unit count
	if !reinforcements.is_empty():
		#First step: break LARGE units into same class MEDIUM units (plus two smalls)
		var large_units = reinforcements.filter(func(t): return t.unit.size == Enums.TokenSizes.LARGE)
		for large_unit in large_units:
			reinforcements.erase(large_unit)
			reinforcements.append(SingleTokenModel.create(JsonLoader.all_units[1], large_unit.token_class))
			reinforcements.append(SingleTokenModel.create(JsonLoader.all_units[0], large_unit.token_class))
			reinforcements.append(SingleTokenModel.create(JsonLoader.all_units[0], large_unit.token_class))
		added_units.append_array(place_reinforcements(grid, reinforcements))
	if !reinforcements.is_empty():
		#Second step: break MEDIUM units into same class SMALL units
		var meduim_units = reinforcements.filter(func(t): return t.unit.size == Enums.TokenSizes.MEDIUM)
		for meduim_unit in meduim_units:
			reinforcements.append(SingleTokenModel.create(JsonLoader.all_units[0], meduim_unit.token_class))
			reinforcements.append(SingleTokenModel.create(JsonLoader.all_units[0], meduim_unit.token_class))
		added_units.append_array(place_reinforcements(grid, reinforcements))
	if !reinforcements.is_empty():
		#Third step: change class of SMALL units until they fit somewhere
		added_units.append_array(place_any_class(grid, reinforcements.size()))
	
#	print("Reinforcements results:")
#	print("Added " + str(added_units.size()) + " units to grid")
#	print("Total unit-tiles in grid: " + str(grid.all_tokens.size()))
#	print("Tiles per class: ")
#	for i in range(0, Constants.NUM_UNIT_CLASSES):
#		print(str(grid.all_tokens.filter((func(t): return t.token_class == i)).size()))
	
	return added_units

func place_any_class(grid: GridModel, count: int) -> Array[TokenModel]:
	var added_units: Array[TokenModel] = []
	while count > 0:
		var added = false
		for token_class in Enums.TokenClasses:
			var reinforcement = SingleTokenModel.create(JsonLoader.all_units[0], token_class)
			var row = get_row_for_reinforcement(grid, reinforcement)
			if row >= 0 && row < Constants.NUM_ROWS:
				added = true
				grid.add_token(reinforcement, row)
				added_units.append(reinforcement)
				count -= 1
				break
		if !added:
			print("Could not add " + str(count) + " units to the grid")
			break
	return added_units

func place_reinforcements(grid: GridModel, reinforcements: Array[TokenModel], retry_factor: int = 2) -> Array[TokenModel]:
	var added_units: Array[TokenModel] = []
	var retries: int = reinforcements.size() * retry_factor
	while !reinforcements.is_empty():
		retries -= 1
		if retries < 0:
			break
		reinforcements.shuffle()
		for reinforcement in reinforcements:
			var target_row = get_row_for_reinforcement(grid, reinforcement)
			
			if target_row >= 0 && target_row < Constants.NUM_ROWS - (reinforcement.dimensions.y - 1):
				reinforcements.erase(reinforcement)
				grid.add_token(reinforcement, target_row)
				added_units.append(reinforcement)
				break
	return added_units

func get_row_for_reinforcement(grid: GridModel, reinforcement: TokenModel) -> int:
	var unit_height = reinforcement.dimensions.y
	var target_row: int = -1
	var rows = range(0, Constants.NUM_ROWS - (unit_height - 1))
	rows.shuffle()
	for row in rows:
		var target_col = grid.preview_col_for_unit(reinforcement, row)
		var is_valid = target_col >= 0 && target_col < Constants.NUM_COLS
		#Large units may need more room to fit, so we check all their rows
		if !reinforcement.is_basic:
			is_valid = range(row, row + unit_height).reduce(
				func(acc, element): return acc && grid.get_last_occupied_col_in_row(row) == grid.get_last_occupied_col_in_row(element),
				is_valid
			)
		#Basic units have a risk of forming combos when added, we need a
		# check to prevent that - reinforcements never create new combos
		if reinforcement.is_basic:
			is_valid = is_valid && !ComboHandler.would_reinforcement_create_combo(grid.tokens, row, target_col, reinforcement.token_class)
		if is_valid:
			target_row = row
			break
	
	return target_row
