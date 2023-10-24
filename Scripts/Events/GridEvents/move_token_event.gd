class_name MoveTokenEvent extends GridEvent

var token: TokenModel
var start_position: Vector2i
var end_position: Vector2i

static func create(_token: TokenModel, _start_position: Vector2i, _end_position: Vector2i) -> MoveTokenEvent:
	var e = MoveTokenEvent.new()
	e.token = _token
	e.start_position = _start_position
	e.end_position = _end_position
	return e
