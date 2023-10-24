class_name AddTokenEvent extends GridEvent

var token: SingleTokenModel
var position: Vector2i

static func create(_token: SingleTokenModel, _position: Vector2i) -> AddTokenEvent:
	var e = AddTokenEvent.new()
	e.token = _token
	e.position = _position
	return e
