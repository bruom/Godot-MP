extends Control

@onready var host_button: Button = $VBoxContainer/host
@onready var join_button: Button = $VBoxContainer/join
@onready var start_button: Button = $VBoxContainer/start
@onready var exit_button: Button = $VBoxContainer/exit
@onready var status_label = $status_label
@onready var connections_label = $connections_label
@onready var text_input_field: LineEdit = $VBoxContainer2/HBoxContainer2/text_input_field
@onready var chatbox: RichTextLabel = $VBoxContainer2/Panel/chatbox

@onready var debug_scene = preload("res://Scenes/TableManager/table_manager.tscn")

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 9876
const DEFAULT_IP = "127.0.0.1"
const MAX_CONNECTIONS = 4

var peer: ENetMultiplayerPeer

var players: Dictionary = {}
var players_loaded = 0

var player_info: PlayerData

var chatbox_content: String = ""

func _ready():
	player_info = PlayerData.new()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta):
	if peer != null:
		start_button.visible = multiplayer.is_server()
	
	host_button.visible = peer == null
	join_button.visible = peer == null
	exit_button.visible = peer != null

# Networking connections

func join_game(address = DEFAULT_IP):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	status_label.text = "Connecting to server at " + address + "..."

func create_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error != OK:
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	player_info.peer_id = 1
	players[1] = player_info
	status_label.text = "Hosting server"
	update_connections_label()

func disconnect_client():
	remove_multiplayer_peer()
	players = {}
	update_connections_label()

func remove_multiplayer_peer():
	multiplayer.set_multiplayer_peer(null)
	peer = null

@rpc("any_peer", "reliable")
func register_player(player_id: int, serialized_player_data: Dictionary):
	var player_data = PlayerData.deserialize(serialized_player_data)
	players[player_id] = player_data
	update_connections_label()
	
	if multiplayer.is_server():
		for player_key in players.keys():
			register_player.rpc(player_key, players[player_key].serialize())
		system_message("-- " + players[player_id].player_name + " has connected --")

func _on_peer_connected(_id):
	update_connections_label()

func _on_peer_disconnected(_id):
	var player_name = players[_id].player_name
	players.erase(_id)
	update_connections_label()
	if multiplayer.is_server():
		system_message("-- " + player_name + " has disconnected --")

func _on_connected_to_server():
	var peer_id = multiplayer.get_unique_id()
	player_info.peer_id = peer_id
	register_player.rpc_id(1, peer_id, player_info.serialize())
	status_label.text = "Connected to server at " + DEFAULT_IP

func _on_connection_failed():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()
	status_label.text = "Not connected"

@rpc("authority", "call_local", "reliable")
func start_game():
	if players.size() == 3:
		var non_server_players: Array = players.values().filter(
			func(p): return p.peer_id != 1
		)
		
		var debug = debug_scene.instantiate()
		get_tree().root.add_child(debug)
		debug.setup(non_server_players[0], non_server_players[1])
		hide()

func return_to_lobby():
	show()

# INPUT

func _on_host_button_down():
	create_game()

func _on_join_button_down():
	join_game()

func _on_start_button_down():
	if multiplayer.is_server():
		start_game.rpc()

func _on_name_field_text_submitted(new_text):
	player_info.player_name = new_text
	update_player_info.rpc(multiplayer.get_unique_id(), player_info.serialize())

func _on_exit_button_down():
	disconnect_client()

func _on_text_input_field_text_submitted(new_text):
	send_message(new_text)

func _on_text_send_button_button_down():
	send_message(text_input_field.text)

# UI

func system_message(message: String):
	receive_message.rpc(message)

func send_message(message: String):
	text_input_field.clear()
	receive_message.rpc(player_info.player_name + ": " + message)

@rpc("any_peer", "call_local", "reliable", 1)
func receive_message(message: String):
	chatbox_content += "\n" + message
	chatbox.text = chatbox_content

func update_connections_label():
	if peer != null:
		connections_label.text = "Connected players:"
		for player_id in players.keys():
			if player_id == multiplayer.get_unique_id():
				connections_label.text += "\n" + players[player_id].player_name + " (you)"
			elif player_id == 1:
				connections_label.text += "\n" + players[player_id].player_name + " (host)"
			else:
				connections_label.text += "\n" + players[player_id].player_name
	else:
		connections_label.text = ""	

@rpc("call_local","any_peer")
func update_player_info(id, serialized_player_data: Dictionary):
	players[id] = PlayerData.deserialize(serialized_player_data)
	update_connections_label()
