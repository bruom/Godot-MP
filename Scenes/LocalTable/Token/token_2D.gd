class_name Token2D extends Node2D

var flipped: bool = false

func destroy_tween() -> Tween:
	var tween = create_tween()
	tween.tween_property(self, "opacity", 0.0, 0.1)
	return tween
