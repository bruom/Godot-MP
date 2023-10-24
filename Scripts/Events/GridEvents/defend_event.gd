class_name DefendEvent extends GridEvent

var token: SingleTokenModel

static func create(_token: SingleTokenModel) -> DefendEvent:
	var e = DefendEvent.new()
	e.token = _token
	return e
