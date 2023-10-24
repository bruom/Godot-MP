class_name AttackEvent extends TokenEvent

var attacker: TokenModel
var defender: TokenModel # if null, attacks opposing player

static func create(_attacker: TokenModel, _defender: TokenModel) -> AttackEvent:
	var e = AttackEvent.new()
	e.attacker = _attacker
	e.defender = _defender
	return e
