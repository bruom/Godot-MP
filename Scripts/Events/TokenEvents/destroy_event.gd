class_name DestroyEvent extends TokenEvent

var token: TokenModel

static func create(_token: TokenModel) -> DestroyEvent:
	var e = DestroyEvent.new()
	e.token = _token
	return e
