shader_type canvas_item;

uniform vec3 top_color : source_color = vec3(0.2, 0.4, 0.8);
uniform vec3 bottom_color : source_color = vec3(0.6, 0.8, 1.0);

void fragment() {
	vec3 color = mix(top_color, bottom_color, clamp(UV.y, 0.0, 1.0));
	COLOR = vec4(color, 1.0);
}
