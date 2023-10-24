class_name ChangePowerEvent extends TokenEvent

var token: TokenModel
var change_amount: int

static func create(_token: TokenModel, _change_amount: int) -> ChangePowerEvent:
	var e = ChangePowerEvent.new()
	e.token = _token
	e.change_amount = _change_amount
	return e
