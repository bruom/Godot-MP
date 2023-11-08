#Visual representation of the board, handles animating tokens on the board
class_name TokenGrid2D extends Node2D

@export var flipped: bool

@onready var token_scene = preload("res://Scenes/LocalTable/Token/Single/single_token_2d.tscn")
@onready var combo_scene = preload("res://Scenes/LocalTable/Token/Combo/combo_2d.tscn")

@onready var spawn_x: float = $spawn_x.position.x
@onready var grid_bg: Sprite2D = $grid_bg

var model: GridModel
var tokens: Array[Token2D] = []

var grid_tween: Tween
var active_tweens: Array[Tween] = []
var latest_event: GridEvent

var hover_row: int = -1
var hover_col: int = -1

var anim_duration_mult: float = 1.0

func setup(_model: GridModel):
	model = _model
	
	model.grid_events.connect(_on_grid_events)

#Event Handling

func _on_grid_events(events: Array[GridEvent]):
	if events.is_empty():
		return
	latest_event = events[0]
	if grid_tween && grid_tween.is_running():
		grid_tween.pause()
		grid_tween.custom_step(10.0)
		grid_tween.kill()
	grid_tween = create_tween()
	for event in events:
		grid_tween.set_parallel(event.get_script() == latest_event.get_script())
		if event is MoveTokenEvent:
			_on_token_moved(event.token, event.end_position.y, event.end_position.x)
		if event is AddTokenEvent:
			_on_token_added(event.token, event.position.y, event.position.x)
		if event is RemoveTokenEvent:
			_on_token_removed(event.token, event.position.y, event.position.x)
		if event is FormComboEvent:
			_on_combo_formed(event.combo, event.position)
		if event is FormNonbasicComboEvent:
			_on_nonbasic_combo_formed(event.combo, event.aux_tokens, event.position)
		if event is DefendEvent:
			_on_token_defending(event.token, event.wall)
		if event is AddDefenderEvent:
			_on_extra_defender_added(event.token)
		
		latest_event = event

func _on_token_moved(token_model: TokenModel, target_row: int, target_col: int):
	var token = get_token_from_model(token_model)
	if token:
		if grid_tween:
			#var out_pos = to_global(Vector2(spawn_x, token.position.y))
			#var in_pos = to_global(Vector2(spawn_x, get_y_for_row(target_row)))
			var end_pos = to_global(find_position_for_token(token_model, target_row, target_col))
			#grid_tween.tween_property(token, "global_position", out_pos, 0.1 * anim_duration_mult)
			#grid_tween.tween_property(token, "global_position", in_pos, 0.02 * anim_duration_mult)
			grid_tween.tween_property(token, "global_position", end_pos, 0.1 * anim_duration_mult)
			grid_tween.tween_callback(ui_done)

func _on_token_added(token_model: SingleTokenModel, _row: int, _col: int):
	var token = token_model.unit.scene.instantiate()
	add_child(token)
	token.flipped = flipped
	token.setup(token_model)
	tokens.append(token)
	token.position = Vector2(spawn_x - _col * Constants.TILE_SIZE, get_y_for_row(_row))
	if flipped:
		token.position.x *= -1
	if grid_tween:
		var final_pos = to_global(find_position_for_token(token_model, _row, _col))
		grid_tween.tween_property(token, "global_position", final_pos, 0.3 * anim_duration_mult)
		grid_tween.tween_callback(ui_done)

func _on_token_removed(token_model: TokenModel, _row: int, _col: int):
	var node = get_token_from_model(token_model)
	tokens.erase(node)
	if grid_tween && node:
		grid_tween.tween_callback(func():
			if node != null:
				node.destroy()
		)
		grid_tween.tween_interval(0.5)

func _on_token_defending(token_model: SingleTokenModel, wall_model: SingleTokenModel):
	var token = get_token_from_model(token_model)
	if token:
		var coords = token_model.position
		#play defend animation here
		#token.defend_icon.show()

		tokens.erase(token)
		var wall_unit = JsonLoader.all_units[3]
		var wall_token = wall_unit.scene.instantiate()
		add_child(wall_token)
		wall_token.flipped = flipped
		wall_token.setup(wall_model)
		tokens.append(wall_token)
		wall_token.position = get_position_for_tile(coords.y, coords.x)
		wall_token.hide()
		
		if grid_tween:
			grid_tween.tween_callback(func():
				remove_child(token)
				wall_token.show()
			)

func _on_combo_formed(combo: ComboTokenModel, combo_position: Vector2i):
	var new_combo = combo_scene.instantiate()
	var top_left_pos = get_position_for_tile(combo_position.y, combo_position.x)
	new_combo.flipped = flipped
	if flipped:
		top_left_pos.x -= (combo.dimensions.x - 1) * Constants.TILE_SIZE
	add_child(new_combo)
	new_combo.position = top_left_pos
	new_combo.position -= Vector2(Constants.TILE_SIZE / 2.0, Constants.TILE_SIZE / 2.0)
	new_combo.setup(combo, get_tokens_from_models(combo.tokens))
	for token_in_combo in get_tokens_from_models(combo.tokens):
		tokens.erase(token_in_combo)
	tokens.append(new_combo)
	new_combo.combo_frame.hide()
	if grid_tween:
		grid_tween.tween_callback(func():
			new_combo.combo_frame.show()
		)

func _on_nonbasic_combo_formed(combo: ComboTokenModel, aux_units: Array[SingleTokenModel], combo_position: Vector2i):
	_on_combo_formed(combo, combo_position)
	aux_units.map(
		func(t): 
			if t.is_basic:
				_on_token_removed(t, t.cur_row, t.cur_col)
	)

func _on_extra_defender_added(token_model: SingleTokenModel):
	var token = token_scene.instantiate()
	add_child(token)
	token.setup(token_model)
	tokens.append(token)
	token.position = get_position_for_tile(token_model.cur_row, token_model.cur_col)
	print("Extra defender not implemented")
	#_on_token_defending(token_model)

func force_sync_with_model():
	for token in tokens:
		token.queue_free()
		for child in get_children():
			if child is Token2D:
				child.queue_free()
	tokens = []
	for token_model in model.all_unique_tokens:
		if token_model is SingleTokenModel:
			add_single_token_directly(token_model)
		elif token_model is ComboTokenModel:
			add_combo_token_directly(token_model)

func _physics_process(_delta):
	var mouse_pos = get_viewport().get_mouse_position()
	hover_row = get_row_for_y(mouse_pos.y)
	if hover_row < 0 || hover_row >= Constants.NUM_ROWS:
		hover_row = -1
	
	hover_col = get_col_for_x(mouse_pos.x)
	if hover_col < 0 || hover_col >= Constants.NUM_COLS:
		hover_col = -1

func mouse_intersect(screen_pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = screen_pos
	var result = space_state.intersect_point(query)
	return result

func add_single_token_directly(token_model: SingleTokenModel) -> SingleToken2D:
	var token = token_scene.instantiate()
	add_child(token)
	token.flipped = flipped
	token.setup(token_model)
	tokens.append(token)
	token.position = find_position_for_token(token_model, token_model.cur_row, token_model.cur_col)
	if token_model.defending:
		token.defend_icon.show()
	return token

func add_combo_token_directly(token_model: ComboTokenModel) -> Combo2D:
	var new_combo = combo_scene.instantiate()
	var top_left_pos = get_position_for_tile(token_model.cur_row, token_model.cur_col)
	new_combo.flipped = flipped
	if flipped:
		top_left_pos.x -= (token_model.dimensions.x - 1) * Constants.TILE_SIZE
	add_child(new_combo)
	new_combo.position = top_left_pos
	new_combo.position -= Vector2(Constants.TILE_SIZE / 2.0, Constants.TILE_SIZE / 2.0)
	var combo_members: Array[Token2D] = []
	for member_model in token_model.tokens:
		var combo_member = token_scene.instantiate()
		add_child(combo_member)
		combo_member.flipped = flipped
		combo_member.setup(member_model)
		combo_member.position = find_position_for_token(member_model, token_model.cur_row + member_model.cur_row, token_model.cur_col + member_model.cur_col)
		combo_members.append(combo_member)
	new_combo.setup(token_model, combo_members)
	tokens.append(new_combo)
	return new_combo

func get_tokens_from_models(token_models: Array[SingleTokenModel]) -> Array[Token2D]:
	var result: Array[Token2D] = []
	for token_model in token_models:
		var token = get_token_from_model(token_model)
		if token != null && !result.has(token):
			result.append(token)
	return result

func get_token_from_model(token_model: TokenModel):
	if token_model == null:
		return null
	for token in tokens:
		if token != null && token.token_model == token_model:
			return token
	return null

func get_last_unit_in_row(row: int) -> Token2D:
	return get_token_from_model(model.get_last_unit_in_row(row))

func ui_done():
	pass
	#model.emit_events()

# Coordinates and conversions

func find_position_for_token(token: TokenModel, row: int, col: int) -> Vector2:
	var half_tile = Constants.TILE_SIZE / 2.0
	var dimensions = token.dimensions
	var tile_center = get_position_for_tile(row, col)
	if token is SingleTokenModel:
		var offset = (dimensions - Vector2i.ONE) * (half_tile) * Vector2(-1.0 if flipped else 1.0, 1.0)
		return tile_center + offset
	else:
		if flipped:
			tile_center.x -= (token.dimensions.x - 1) * Constants.TILE_SIZE
		return tile_center - Vector2(half_tile, half_tile)

func get_col_for_x(mouse_x: float, _clamp: bool = false) -> int:
	var local_mouse_x = mouse_x - position.x
	var col_zero_x = Constants.TILE_SIZE * (Constants.NUM_COLS - 1) / 2.0
	var x_relative = col_zero_x - local_mouse_x
	var col = roundi(x_relative / Constants.TILE_SIZE)
	if _clamp:
		col = clampi(col, 0, Constants.NUM_COLS - 1)
	if flipped:
		return (Constants.NUM_COLS - 1) - col
	else:
		return col

#func get_row_for_y(mouse_y: float, _block_size: int = 1, _clamp: bool = false) -> int:
#	var local_mouse_y = mouse_y - position.y
#	var row_zero_y = -Constants.TILE_SIZE * (Constants.NUM_ROWS - 1) / 2.0
#	var y_relative = local_mouse_y - row_zero_y
#	if _block_size > 1:
#		y_relative -= Constants.TILE_SIZE / (_block_size - 1)
#	var row = roundi(y_relative / Constants.TILE_SIZE)
#	if _clamp:
#		row = clampi(row, 0, Constants.NUM_ROWS - 1)
#	return row

func get_row_for_y(mouse_y: float, _clamp: bool = false) -> int:
	var local_mouse_y = mouse_y - position.y
	var row_zero_y = -Constants.TILE_SIZE * (Constants.NUM_ROWS - 1) / 2.0
	var y_relative = local_mouse_y - row_zero_y
	var row = roundi(y_relative / Constants.TILE_SIZE)
	if _clamp:
		row = clampi(row, 0, Constants.NUM_ROWS - 1)
	return row

func get_x_for_col(col: int) -> float:
	var col_zero_x = Constants.TILE_SIZE * (Constants.NUM_COLS - 1) / 2.0
	return (col_zero_x - col * Constants.TILE_SIZE) * (-1 if flipped else 1)

func get_y_for_row(row: int) -> float:
	var row_zero_y = -Constants.TILE_SIZE * (Constants.NUM_ROWS - 1) / 2.0
	return row_zero_y + row * Constants.TILE_SIZE

func get_position_for_tile(row: int, col: int, corner: bool = false) -> Vector2:
	var center = Vector2(get_x_for_col(col), get_y_for_row(row))
	if corner:
		return center - Vector2(Constants.TILE_SIZE / 2.0, Constants.TILE_SIZE / 2.0)
	return center
