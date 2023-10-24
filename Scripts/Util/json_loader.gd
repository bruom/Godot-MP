class_name CardLoader extends Node

var all_units: Dictionary

func _ready():
	all_units = CardLoader.read_units_json()

static func read_units_json() -> Dictionary:
	var units: Dictionary = {}
	var file_string = FileAccess.get_file_as_string("res://Assets/Jsons/units.json")
	var data = JSON.parse_string(file_string)
	for entry in data:
		var new_unit = UnitData.from_json(entry)
		units[new_unit.unit_id] = new_unit
	return units
