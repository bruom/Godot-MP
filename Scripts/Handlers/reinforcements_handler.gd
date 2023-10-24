class_name ReinforcementsHandler extends RefCounted

static func get_reinforcement_amount(grid: Array) -> int:
	var all_tokens: Array[TokenModel] = []
	for row in grid:
		for token in row:
			if token != null:
				all_tokens.append(token)
	
	return max(0, Constants.TARGET_UNIT_COUNT - all_tokens.size())

static func generate_reinforcements(grid: Array):
	var reinforcements: Array[TokenModel] = []
	var reinforcement_amount_remaining = get_reinforcement_amount(grid)
	
	if reinforcement_amount_remaining <= 0:
		return reinforcements
	
	var all_tokens: Array[TokenModel] = []
	var nonbasics: Array[TokenModel] = []
	for row in grid:
		for token in row:
			if token != null:
				all_tokens.append(token)
				if !token.is_basic && !nonbasics.has(token):
					nonbasics.append(token)
	
	var class_counts: Array = range(0, Constants.NUM_UNIT_CLASSES).map(
		func(unit_class):
			return all_tokens.filter((func(t): return t.token_class == unit_class)).size()
#			return all_tokens.filter(func(t): return t.token_class == unit_class).reduce(
#				func(acc, token): return acc + token.dimensions.x * token.dimensions.y, 0
#			)
	)
	
	var reinforcements_class_counts: Array = []
	reinforcements_class_counts.resize(class_counts.size())
	reinforcements_class_counts.fill(0)
	
	var nonbasic_rolls = Constants.MAX_NONBASIC_COUNT - nonbasics.size()
	var nonbasic_valid_classes: Array = range(0, Constants.NUM_UNIT_CLASSES)
	for nonbasic in nonbasics:
		if nonbasic_valid_classes.has(nonbasic.token_class):
			nonbasic_valid_classes.erase(nonbasic.token_class)
	
	#Create nonbasic units
	#There is a chance for fewer than the maximum amount of nonbasics to be created
	for i in range(0, nonbasic_rolls):
		var rand: float = randf()
		if rand < Constants.MEDIUM_BASE_CHANCE:
			if reinforcement_amount_remaining >= 2:
				var picked_class = nonbasic_valid_classes.pick_random()
				nonbasic_valid_classes.erase(picked_class)
				var unit = JsonLoader.all_units[1]
				#unit.size = Enums.TokenSizes.MEDIUM
				reinforcements.append(SingleTokenModel.create(unit, picked_class))
				reinforcement_amount_remaining -= 2
				reinforcements_class_counts[picked_class] += 2
		elif rand < Constants.MEDIUM_BASE_CHANCE + Constants.LARGE_BASE_CHANCE:
			if reinforcement_amount_remaining >= 4:
				var picked_class = nonbasic_valid_classes.pick_random()
				nonbasic_valid_classes.erase(picked_class)
				var unit = JsonLoader.all_units[2]
				#unit.size = Enums.TokenSizes.LARGE
				reinforcements.append(SingleTokenModel.create(unit, picked_class))
				reinforcement_amount_remaining -= 4
				reinforcements_class_counts[picked_class] += 4
		else:
			pass
	
	#Fill the rest with basic units
	while(reinforcement_amount_remaining > 0):
		var valid_classes = range(0, Constants.NUM_UNIT_CLASSES).filter(
			func(unit_class):
				return reinforcements_class_counts[unit_class] + class_counts[unit_class] < Constants.TARGET_UNIT_COUNT / Constants.NUM_UNIT_CLASSES
		)
		
		var unit = UnitData.new()
		var picked_class = valid_classes.pick_random()
		reinforcements.append(SingleTokenModel.create(unit, picked_class))
		reinforcements_class_counts[picked_class] += 1
		reinforcement_amount_remaining -= 1
	
	return reinforcements

static func count_tiles(tokens: Array[TokenModel]) -> int:
	var total_unit_tile_count = tokens.reduce(
		func(acc, token): return acc + token.dimensions.x * token.dimensions.y, 0
	)
	return total_unit_tile_count
