class_name DefendEvent extends GridEvent

var token: SingleTokenModel
var wall: SingleTokenModel

static func create(_token: SingleTokenModel, _wall: SingleTokenModel) -> DefendEvent:
	var e = DefendEvent.new()
	e.token = _token
	e.wall = _wall
	return e
