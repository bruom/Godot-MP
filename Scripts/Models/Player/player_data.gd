class_name PlayerData extends Node

var peer_id: int
var player_name: String = "no name"
var loadout: Loadout = Loadout.new()

func serialize() -> Dictionary:
	var dict = {}
	dict["player_name"] = player_name
	dict["peer_id"] = peer_id
	return dict

static func deserialize(dict: Dictionary) -> PlayerData:
	var player_data = PlayerData.new()
	player_data.player_name = dict["player_name"]
	player_data.peer_id = dict["peer_id"]
	return player_data
