class_name SingleToken2D extends Token2D

@onready var token_image: Sprite2D = $token_image
@onready var defend_icon: Sprite2D = $defend_icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var opacity: float = 1.0:
	set(new_value):
		opacity = new_value
		set_color()

var token_model: SingleTokenModel
var destroyed: bool = false

var target_size: Vector2:
	get:
		return token_model.dimensions * 100.0

func _process(_delta):
	if token_model:
		token_image.frame_coords.y = token_model.token_class
		pass

func debug_shake():
	var debug_tween = create_tween()
	debug_tween.tween_property(token_image, "position", Vector2(3,1), 0.05)
	debug_tween.tween_property(token_image, "position", Vector2(0,4), 0.05)
	debug_tween.tween_property(token_image, "position", Vector2(-2,-3), 0.05)
	debug_tween.tween_property(token_image, "position", Vector2(0,0), 0.05)

func setup(model: SingleTokenModel):
	token_model = model
	token_image.flip_h = flipped
#	var texture = load(model.unit.texture_path)
#	token_image.texture = texture
	var frame_size: Vector2 = Vector2(token_image.texture.get_width() / token_image.hframes, token_image.texture.get_height() / token_image.vframes)
	token_image.scale = target_size / frame_size
	defend_icon.scale = target_size / defend_icon.texture.get_size()
	
	if animation_player.has_animation("idle"):
		animation_player.play("idle")
		animation_player.advance(randf_range(0.0, 1.9))
	
	set_color()

func attack():
	destroyed = true
	if animation_player.has_animation("attack"):
		animation_player.play("attack")

func destroy():
	if !destroyed:
		destroyed = true
		if animation_player.has_animation("destroy"):
			animation_player.play("destroy")

func set_color():
	pass
#	match token_model.token_class:
#		0:
#			token_image.set_modulate(Color(0, 0.545098, 0.545098, opacity))
#		1:
#			token_image.set_modulate(Color(0.870588, 0.721569, 0.529412, opacity))
#		2:
#			token_image.set_modulate(Color(0.370588, 0.121569, 0.729412, opacity))
