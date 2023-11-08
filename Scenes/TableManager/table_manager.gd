#Root scene which handles primarily the communication between clients and server
class_name TableManager extends Node

@onready var local_table_scene = preload("res://Scenes/LocalTable/local_table.tscn")

# Server has one which is the authority for game state, each client has a local one
#which (all going well) will be kept synched to the server's
@onready var game_manager: GameManager = $GameManager

var player_a: PlayerData:
	get:
		return game_manager.player_a
		
var player_b: PlayerData:
	get:
		return game_manager.player_b

var table_state: TableModel:
	get:
		return game_manager.table_state

var turn_player_id: int:
	get:
		return game_manager.turn_player.peer_id

#Each client has their own, server does not have one - handles input and visuals
var local_table: LocalTable


func setup(_player_a: PlayerData, _player_b: PlayerData):
	game_manager.player_a = _player_a
	game_manager.player_b = _player_b
	if !multiplayer.is_server():
		local_table = local_table_scene.instantiate()
		add_child(local_table)
		var player = player_a if multiplayer.get_unique_id() == _player_a.peer_id else player_b
		local_table.setup(game_manager, player)
		local_table.unit_moved.connect(_on_unit_moved)
		local_table.unit_removed.connect(_on_unit_removed)
		local_table.reinforcements_called.connect(_on_reinforcements_called)
		local_table.turn_ended.connect(_on_end_turn)
	else:
		start_game()

#Server-side functions

func start_game():
	reinforce(player_a)
	reinforce(player_b)
	game_manager.begin_turn(player_a)
	begin_turn.rpc(turn_player_id)

func tick_turn():
	if multiplayer.is_server():
		game_manager.tick_turn()
		client_update_state.rpc(game_manager.table_state.serialize())
		begin_turn.rpc(turn_player_id)

@rpc("any_peer", "call_remote", "reliable")
func player_moved_unit(from_row: int, to_row: int):
	var player = player_a if multiplayer.get_remote_sender_id() == player_a.peer_id else player_b
	var success = game_manager.basic_move(player, from_row, to_row)
	if success:
		move_token.rpc(multiplayer.get_remote_sender_id(), from_row, to_row) 

@rpc("any_peer", "call_remote", "reliable")
func player_removed_unit(row: int, col: int):
	var player = player_a if multiplayer.get_remote_sender_id() == player_a.peer_id else player_b
	var success = game_manager.basic_remove(player, row, col)
	if success:
		remove_token.rpc(multiplayer.get_remote_sender_id(), row, col)

@rpc("any_peer", "call_remote", "reliable")
func player_called_reinforcements():
	var player_id = multiplayer.get_remote_sender_id()
	var player_data = player_a if player_id == player_a.peer_id else player_b
	reinforce(player_data)

func reinforce(player_data: PlayerData):
	var reinforcements = game_manager.generate_reinforcements(player_data)
	var serialized_tokens = reinforcements.map(func(token):
		return token.serialize()
	)
	add_tokens.rpc(player_data.peer_id, serialized_tokens)

@rpc("any_peer", "call_remote", "reliable")
func debug_end_turn():
	tick_turn()

#Client-side functions

#Client calls resulting from input
func _on_unit_moved(from_row: int, to_row: int):
	if !multiplayer.is_server():
		player_moved_unit.rpc_id(1, from_row, to_row)

func _on_unit_removed(row: int, col: int):
	if !multiplayer.is_server():
		player_removed_unit.rpc_id(1, row, col)

func _on_reinforcements_called():
	if !multiplayer.is_server():
		player_called_reinforcements.rpc_id(1)

func _on_end_turn():
	if !multiplayer.is_server():
		debug_end_turn.rpc_id(1)

#Client updating operations, called by server
@rpc("call_remote")
func add_token(player_id, token_model: Dictionary, row: int):
	if player_a.peer_id == player_id:
		game_manager.table_state.player_a_grid.add_token(SingleTokenModel.deserialize(token_model), row)
	else:
		game_manager.table_state.player_b_grid.add_token(SingleTokenModel.deserialize(token_model), row)

@rpc("call_remote")
func add_tokens(player_id, token_models: Array):
	var player = player_a if player_a.peer_id == player_id else player_b
	var tokens: Array[TokenModel] = []
	tokens.assign(token_models.map(func(data): return SingleTokenModel.deserialize(data)))
	game_manager.add_units(player, tokens)

@rpc("call_remote")
func move_token(player_id, from_row: int, to_row: int):
	var player = player_a if player_a.peer_id == player_id else player_b
	game_manager.basic_move(player, from_row, to_row)

@rpc("call_remote")
func remove_token(player_id, row: int, col: int):
	var player = player_a if player_a.peer_id == player_id else player_b
	game_manager.basic_remove(player, row, col)

@rpc("call_remote")
func client_update_state(new_table_state: Dictionary):
	table_state = TableModel.deserialize(new_table_state)

@rpc("call_remote")
func begin_turn(player_id):
	game_manager.begin_turn(player_a if player_id == player_a.peer_id else player_b)

#Client and Server functions

#Helper functions

func other_player(this_player: PlayerData):
	return player_a if this_player == player_b else player_b
