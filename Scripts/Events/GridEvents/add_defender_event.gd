class_name AddDefenderEvent extends GridEvent

var token: SingleTokenModel

static func create(_token: SingleTokenModel) -> AddDefenderEvent:
	var e = AddDefenderEvent.new()
	e.token = _token
	return e
