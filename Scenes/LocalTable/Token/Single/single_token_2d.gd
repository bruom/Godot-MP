class_name SingleToken2D extends Token2D

@onready var token_image: Sprite2D = $token_image
@onready var defend_icon: Sprite2D = $token_image/defend_icon

var opacity: float = 1.0:
	set(new_value):
		opacity = new_value
		set_color()

var token_model: SingleTokenModel

var target_size: Vector2:
	get:
		return token_model.dimensions * 100.0

func debug_shake():
	var debug_tween = create_tween()
	debug_tween.tween_property(token_image, "position", Vector2(3,1), 0.05)
	debug_tween.tween_property(token_image, "position", Vector2(0,4), 0.05)
	debug_tween.tween_property(token_image, "position", Vector2(-2,-3), 0.05)
	debug_tween.tween_property(token_image, "position", Vector2(0,0), 0.05)

func setup(model: SingleTokenModel):
	token_model = model
	var texture = load(model.unit.texture_path)
	token_image.texture = texture
	token_image.scale = Vector2(target_size.x / texture.get_width(), target_size.y / texture.get_height())
	set_color()

func set_color():
	match token_model.token_class:
		0:
			token_image.set_modulate(Color(0, 0.545098, 0.545098, opacity))
		1:
			token_image.set_modulate(Color(0.870588, 0.721569, 0.529412, opacity))
		2:
			token_image.set_modulate(Color(0.370588, 0.121569, 0.729412, opacity))
