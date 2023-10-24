# Responsible for handling player input and updating visuals/audio/UX; client-only
class_name LocalTable extends Node2D

enum InteractionState {
	IDLE = 0,
	MOVING_UNIT = 1,
	TARGETTING_EFFECT = 2
}

@onready var camera_2d = $Camera2D
@onready var row_indicator: Sprite2D = $row_indicator
@onready var preview_rect: ColorRect = $preview_rect
@onready var player_grid: TokenGrid2D = $lines/player_grid
@onready var opponent_grid: TokenGrid2D = $lines/opponent_grid
@onready var player_hero: Hero2D = $player_hero
@onready var opponent_hero: Hero2D = $opponent_hero

var in_turn: bool:
	get:
		return game_manager.turn_player && game_manager.turn_player.peer_id == multiplayer.get_unique_id()

var is_multiplayer: bool:
	get:
		return multiplayer.has_multiplayer_peer() && !(multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

var game_manager: GameManager
var model: TableModel

var interaction_state: InteractionState = InteractionState.IDLE
#This will be either the selected unit during a move, or the spell/effect
# during targetting
var interaction_source
var is_player_a: bool:
	get:
		return player.peer_id == game_manager.player_a.peer_id

var player: PlayerData

var player_grid_model: GridModel:
	get:
		if !is_multiplayer:
			return model.player_a_grid
		return model.player_a_grid if is_player_a else model.player_b_grid

#Array of Array[TokenEvent]
var token_event_queue: Array = []
var event_tween: Tween

#signals emitted for server communication
signal unit_moved(from_row: int, to_row: int)
signal unit_removed(row: int, col: int)
signal reinforcements_called
signal turn_ended

func _ready():
	if !is_multiplayer:
		var manager = GameManager.new()
		manager.table_state = TableModel.new()
		setup(manager, manager.player_a)
		player_grid_model.input_send_reinforcements()
		opponent_grid.model.input_send_reinforcements()

func setup(_game_manager: GameManager, _player: PlayerData):
	player = _player
	game_manager = _game_manager
	model = game_manager.table_state
	player_hero.setup(model.player_a_hero if is_player_a else model.player_b_hero)
	opponent_hero.setup(model.player_b_hero if is_player_a else model.player_a_hero)
	player_grid.setup(model.player_a_grid if is_player_a else model.player_b_grid)
	opponent_grid.setup(model.player_b_grid if is_player_a else model.player_a_grid)
	
	game_manager.token_events.connect(add_events_to_queue)

func _process(_delta):
	var mouse_pos = get_viewport().get_mouse_position()
	var hover_nodes = nodes_under_cursor(mouse_pos).map(func(n): return n.get_parent())
	handle_input(hover_nodes, mouse_pos)
	
	if !token_event_queue.is_empty() && (event_tween == null || !event_tween.is_running()):
		handle_events(token_event_queue.pop_front())

#Turns - these responsibilities will eventually be moved to GameManager

func attack(combo_model: ComboTokenModel, local_player: bool):
	var rows = combo_model.get_rows()
	var attacking_grid = player_grid if local_player else opponent_grid
	var defending_grid = opponent_grid if local_player else player_grid
	var destroyed_defender_units: Array[TokenModel] = []
	var combo_node = attacking_grid.get_token_from_model(combo_model)
	
	var attack_tween = create_tween()
	
	for col in range(0, Constants.NUM_COLS):
		var defenders: Array[TokenModel] = []
		for row in rows:
			var front_token = defending_grid.model.tokens[row][col]
			if front_token != null && !defenders.has(front_token) && front_token.cur_power > 0:
				defenders.append(front_token)
			if !defenders.is_empty():
				var target_x = defending_grid.to_global(defending_grid.get_position_for_tile(0, col)).x
				combo_node.append_attack_anim_to_tween(attack_tween, target_x)
			for defender in defenders:
				var aux_defender_power = defender.cur_power
				defender.cur_power -= combo_model.cur_power
				combo_model.cur_power -= aux_defender_power
				if defender.cur_power <= 0 && !destroyed_defender_units.has(defender):
					destroyed_defender_units.append(defender)
					var destroyed_node = defending_grid.get_token_from_model(defender)
					attack_tween.tween_callback(func():
						destroyed_node.destroy_tween()
					)
		if combo_model.cur_power <= 0:
			break
	
	if combo_model.cur_power > 0:
		combo_node.append_attack_anim_to_tween(attack_tween, get_viewport_rect().end.x)
		#damage opponent player
		print(str(combo_model.cur_power) + " damage dealt to player!")
	
	defending_grid.model.remove_tokens(destroyed_defender_units)
	attacking_grid.model.remove_token(combo_model)
	
	attack_tween.tween_callback(func():
		defending_grid.model.emit_events()
		attacking_grid.model.emit_events()
	)

func add_events_to_queue(events: Array[TokenEvent]):
	token_event_queue.append(events)

func handle_events(events: Array[TokenEvent]):
	if event_tween && event_tween.is_running():
		event_tween.pause()
		event_tween.custom_step(100.0)
		event_tween.kill()
	event_tween = create_tween()
	for event in events:
		if event is AttackEvent:
			var attacker_node = get_node_for_model(event.attacker)
			if attacker_node:
				var target_x
				if event.defender == null:
					target_x = 0.0 if attacker_node.flipped else get_viewport_rect().end.x
				else:
					target_x = get_node_for_model(event.defender).global_position.x
				attacker_node.append_attack_anim_to_tween(event_tween, target_x)
		if event is DestroyEvent:
			var destroyed_node = get_node_for_model(event.token)
			event_tween.tween_callback(func():
				if destroyed_node != null:
					destroyed_node.destroy_tween()
			)
	event_tween.tween_callback(func():
		if token_event_queue.is_empty():
			player_grid.model.emit_events()
			opponent_grid.model.emit_events()
	)

#Input

func nodes_under_cursor(mouse_pos: Vector2) -> Array:
	var results = mouse_intersect(mouse_pos)
	return results.map(func(r): return r["collider"])

func mouse_intersect(screen_pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = screen_pos
	var result = space_state.intersect_point(query)
	return result

func handle_input(_hover_nodes: Array, mouse_pos: Vector2):
	update_row_indicator(mouse_pos)
	
	if !in_turn:
		return
	
	var row = player_grid.get_row_for_y(mouse_pos.y)
	var col = player_grid.get_col_for_x(mouse_pos.x)
	
	if Input.is_action_just_pressed("Space"):
		if is_multiplayer:
			reinforcements_called.emit()
		else:
			game_manager.generate_reinforcements(player)
	if Input.is_action_just_pressed("LeftClick"):
		handle_click(mouse_pos)
	if Input.is_action_just_pressed("RightClick"):
		if interaction_state == InteractionState.IDLE:
			if row != -1 && col != -1:
				if is_multiplayer:
					unit_removed.emit(row, col)
				elif !player_grid_model.resolving:
					game_manager.basic_remove(player, row, col)
		else:
			cancel_interaction()
	if Input.is_action_just_pressed("Num_Three"):
		player_grid.force_sync_with_model()
		opponent_grid.force_sync_with_model()
	if Input.is_action_just_pressed("Debug_click"):
		cancel_interaction()
		if is_multiplayer:
			turn_ended.emit()
		else:
			game_manager.tick_turn()

func update_row_indicator(mouse_pos: Vector2):
	row_indicator.hide()
	preview_rect.hide()
	
	if in_turn:
		if interaction_state == InteractionState.IDLE:
			var row = player_grid.get_row_for_y(mouse_pos.y)
			if row >= 0 && row < Constants.NUM_ROWS:
				var row_pos = player_grid.to_global(player_grid.get_position_for_tile(row, 0))
				row_indicator.global_position.y = row_pos.y
				row_indicator.show()
		
		if interaction_state == InteractionState.MOVING_UNIT:
			#unit
			var unit_height = interaction_source.dimensions.y
			var row = player_grid.get_row_for_y(mouse_pos.y, unit_height)
			if row >= 0 && row < Constants.NUM_ROWS:
				var row_pos = player_grid.to_global(player_grid.get_position_for_tile(row, 0))
				var unit_node = get_node_for_model(interaction_source)
				if unit_node:
					var size_offset = (Constants.TILE_SIZE / 2.0) * (unit_height - 1)
					unit_node.global_position.y = row_pos.y + size_offset
			
			#preview
			preview_rect.show()
			var preview_col = player_grid_model.preview_col_for_unit(interaction_source, row)
			var preview_pos
			if preview_col < 0:
				preview_pos = player_grid.to_global(player_grid.get_position_for_tile(row, Constants.NUM_COLS - 1, true))
				preview_rect.update_color(false)
			else:
				preview_pos = player_grid.to_global(player_grid.get_position_for_tile(row, preview_col, true))
				preview_rect.update_color(true)
			preview_rect.update_size(interaction_source.dimensions)
			preview_rect.global_position = preview_pos

func handle_click(mouse_pos: Vector2):
	var row 
	if interaction_source is TokenModel:
		row = player_grid.get_row_for_y(mouse_pos.y, interaction_source.dimensions.y)
	else:
		row = player_grid.get_row_for_y(mouse_pos.y)
	var col = player_grid.get_col_for_x(mouse_pos.x)
	if col >= 0 && col <= Constants.NUM_COLS && row >= 0 && row < Constants.NUM_ROWS:
		if interaction_state == InteractionState.IDLE:
			var last_unit = player_grid_model.get_last_unit_in_row(row)
			if last_unit && last_unit is SingleTokenModel && !last_unit.defending:
				var node = get_node_for_model(last_unit)
				var tween = create_tween()
				var target_pos = player_grid.to_global(player_grid.get_position_for_tile(row, Constants.NUM_COLS + 1))
				target_pos.y = node.global_position.y
				tween.tween_property(node, "global_position", target_pos, 0.1)
				
				interaction_source = last_unit
				interaction_state = InteractionState.MOVING_UNIT
		elif interaction_state == InteractionState.MOVING_UNIT:
			if interaction_source is SingleTokenModel && row < Constants.NUM_ROWS - (interaction_source.dimensions.y - 1):
				if interaction_source.cur_row == row:
					cancel_interaction()
				else:
					var preview_col = player_grid_model.preview_col_for_unit(interaction_source, row)
					if preview_col > -1:
						if is_multiplayer:
							unit_moved.emit(interaction_source.cur_row, row)
						else:
							player_grid_model.input_move_token(interaction_source.cur_row, row)
						end_interaction()

func cancel_interaction():
	if interaction_state == InteractionState.MOVING_UNIT && interaction_source is TokenModel:
		var unit_node = get_node_for_model(interaction_source)
		if unit_node:
			unit_node.position = player_grid.find_position_for_token(interaction_source, interaction_source.cur_row, interaction_source.cur_col)
	end_interaction()

func end_interaction():
	interaction_source = null
	interaction_state = InteractionState.IDLE

#Utility

func get_node_for_model(token_model: TokenModel) -> Token2D:
	var node
	node = player_grid.get_token_from_model(token_model)
	if node:
		return node
	node = opponent_grid.get_token_from_model(token_model)
	if node:
		return node
	return null
