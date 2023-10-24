shader_type canvas_item;

uniform sampler2D main_tex;
uniform float intensity: hint_range(0.0, 1.0, 0.1);

void fragment() {
	vec4 main_color = texture(main_tex, UV);
	float gray_value = 0.299 * main_color.r + 0.587 * main_color.g + 0.114 * main_color.b;
	vec4 grayscale_color = vec4(gray_value, gray_value, gray_value, main_color.a);
	COLOR = mix(main_color, grayscale_color, intensity);
}
