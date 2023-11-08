shader_type canvas_item;

uniform sampler2D main_tex: filter_nearest;
uniform ivec2 sprite_size;
uniform float progress: hint_range(0.0, 1.0, 0.01);
uniform vec4 glow_color: source_color;

uniform float disappear_prog: hint_range(0, 1.0, 0.01);

varying vec2 img_space_vertex;

int distance_to_opaque(vec2 uv, vec2 pixel_size) {
	if(texture(main_tex, uv).a > 0.1){
		return 0;
	}
	for(int x = -1; x <= 1; x++){
		for(int y = -1; y <= 1; y++){
			vec2 offset_uv = uv + vec2(float(x),float(y)) * pixel_size;
			if(texture(main_tex, offset_uv).a > 0.1){
				return 1;
			}
		}
	}
	
	return 1000;
}

void vertex() {
	img_space_vertex = VERTEX;
}

void fragment() {
	if(disappear_prog == 1.0) {
		discard;
	}
	
	ivec2 pixel_coord = ivec2(floor(img_space_vertex));
	float max_radius = distance(vec2(0.0), vec2(sprite_size / 2));
	float this_radius = length(vec2(pixel_coord));
	
	if(this_radius > max_radius * (1.0 - disappear_prog)){
		discard;
	}
	
	int dist = distance_to_opaque(UV, TEXTURE_PIXEL_SIZE);
	float intensity = progress * (1.5 - 0.5 * float(dist));

	COLOR = mix(texture(main_tex, UV), glow_color, intensity);
}
