class_name RemoveTokenEvent extends GridEvent

var token: TokenModel
var position: Vector2i

static func create(_token: TokenModel, _position: Vector2i) -> RemoveTokenEvent:
	var e = RemoveTokenEvent.new()
	e.token = _token
	e.position = _position
	return e
