shader_type canvas_item;

uniform float progress: hint_range(0.0, 1.0, 0.001);
uniform sampler2D mainTex;
uniform float line_skew: hint_range(0.0, 1.0, 0.1);
uniform int steps: hint_range(1, 10, 1);

bool check_pixel(int step_num, vec2 uv) {
	if(step_num == steps) {
		return false;
	}
	float step_size = 1.1 / float(steps);
	float step_threshold = float(step_num) * step_size;
	float skew_term = step_num % 2 == 0 ? uv.x : 1.0 - uv.x;
	return uv.y + (line_skew * skew_term) > step_threshold;
}

void vertex() {
	
}

void fragment() {
	float step_size =  1.0 / float(steps);
	int cur_step = int(progress / step_size);
	if(check_pixel(cur_step + 1, UV)) {
		discard;
	}
	float cur_step_progress = mod(progress, step_size) / step_size;
	float x_term = cur_step % 2 == 0 ? UV.x : 1.0 - UV.x;
	if(check_pixel(cur_step, UV)) {
		if(x_term > cur_step_progress) {
			discard;
		}
	}
	COLOR.rgba = texture(mainTex, UV);
}
