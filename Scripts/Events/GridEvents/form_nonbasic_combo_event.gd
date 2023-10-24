class_name FormNonbasicComboEvent extends GridEvent

var combo: ComboTokenModel
var aux_tokens: Array[SingleTokenModel]
var position: Vector2i

static func create(_combo: ComboTokenModel, _aux_tokens: Array[SingleTokenModel], _position: Vector2i) -> FormNonbasicComboEvent:
	var e = FormNonbasicComboEvent.new()
	e.combo = _combo
	e.aux_tokens = _aux_tokens
	e.position = _position
	return e
