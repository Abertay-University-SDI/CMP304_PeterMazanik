shader_type canvas_item;

uniform int[32] deer;
uniform int[32] wolves;
uniform int peak = 100;

void vertex() {
}

void fragment() {
	vec2 uv = UV;

	// find indices
	float scaled_x = uv.x * 31.0; // 31 steps, 32 samples
	int index_floor = int(floor(scaled_x));
	int index_ceil = int(ceil(scaled_x));

	index_floor = clamp(index_floor, 0, 31);
	index_ceil = clamp(index_ceil, 0, 31);

	// interpolation factor between the two indices
	float mixval = fract(scaled_x);

	// interpolate deer and wolf values linearly
	float deer_value_floor = float(deer[index_floor]) / float(peak);
	float deer_value_ceil  = float(deer[index_ceil])  / float(peak);
	float deer_value = mix(deer_value_floor, deer_value_ceil, mixval);

	float wolf_value_floor = float(wolves[index_floor]) / float(peak);
	float wolf_value_ceil  = float(wolves[index_ceil])  / float(peak);
	float wolf_value = mix(wolf_value_floor, wolf_value_ceil, mixval);

	// colors
	vec4 wolf_color = vec4(0.5, 0.5, 0.5, 1.0);
	vec4 deer_color = vec4(0.6, 0.4, 0.0, 1.0);

	// draw smaller bar first
	float min_value = min(deer_value, wolf_value);
	float max_value = max(deer_value, wolf_value);
	vec4 min_color = deer_value < wolf_value ? deer_color : wolf_color;
	vec4 max_color = deer_value >= wolf_value ? deer_color : wolf_color;

	vec4 color = vec4(0.0);

	// fill the lower (smaller) one
	if (uv.y < max_value)
		color = max_color;
		
	if (uv.y < min_value)
		color = min_color;

	if (abs(deer_value - wolf_value) < 0.005 && uv.y < deer_value)
		color = mix(wolf_color, deer_color, 0.5);
		
	COLOR = color;
}
