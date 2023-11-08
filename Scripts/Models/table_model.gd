class_name TableModel extends RefCounted

var player_a_hero: HeroModel = HeroModel.new()
var player_b_hero: HeroModel = HeroModel.new()

var player_a_grid: GridModel = GridModel.new()
var player_b_grid: GridModel = GridModel.new()

func serialize() -> Dictionary:
	var dict = {}
	
	dict["player_a_hero"] = player_a_hero.serialize()
	dict["player_b_hero"] = player_b_hero.serialize()
	dict["player_a_grid"] = player_a_grid.serialize()
	dict["player_b_grid"] = player_b_grid.serialize()
	
	return dict

static func deserialize(dict: Dictionary) -> TableModel:
	var table = TableModel.new()
	
	table.player_a_hero = HeroModel.deserialize(dict["player_a_hero"])
	table.player_b_hero = HeroModel.deserialize(dict["player_b_hero"])
	table.player_a_grid = GridModel.deserialize(dict["player_a_grid"])
	table.player_b_grid = GridModel.deserialize(dict["player_b_grid"])
	
	return table
