class_name UnitData extends Resource

var unit_id: int = 0
var name: String = "default"
var texture_path: String = "res://Assets/UnitSprites/slimeow.png"
var scene
var size: int = 0

var dimensions: Vector2i:
	get:
		match size:
			Enums.TokenSizes.SMALL:
				return Vector2i.ONE
			Enums.TokenSizes.MEDIUM:
				return Vector2i(2, 1)
			Enums.TokenSizes.LARGE:
				return Vector2i(2, 2)
		return Vector2i.ONE

var timer: int = 2
var combo_power: int = 15
var idle_power: int = 2

var is_basic:
	get:
		return size == Enums.TokenSizes.SMALL

static func from_json(json: Dictionary) -> UnitData:
	var unit = UnitData.new()
	unit.unit_id = json["unit_id"]
	unit.name = json["name"]
	unit.texture_path = "res://" + json["texture_path"]
	unit.size = json["size"]
	unit.timer = json["timer"]
	unit.combo_power = json["combo_power"]
	unit.idle_power = json["idle_power"]
	
	var scene_path = Constants.UNIT_SCENE_PATH + json["scene"] + ".tscn"
	unit.scene = load(scene_path)
	return unit
