extends ColorRect

var valid_color: Color = Color(0.4, 0.6, 0.75, 0.5)
var invalid_color: Color = Color(0.8, 0.3, 0.3, 0.5)

func update_color(valid: bool):
	color = valid_color if valid else invalid_color

func update_size(size_in_tiles: Vector2i):
	size = size_in_tiles * Constants.TILE_SIZE
