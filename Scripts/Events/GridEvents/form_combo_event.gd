class_name FormComboEvent extends GridEvent

var combo: ComboTokenModel
var position: Vector2i

static func create(_combo: ComboTokenModel, _position: Vector2i) -> FormComboEvent:
	var e = FormComboEvent.new()
	e.combo = _combo
	e.position = _position
	return e
