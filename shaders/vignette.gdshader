shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float radius : hint_range(0.0, 1.0) = 0.75;
uniform float softness : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float alpha = smoothstep(radius - softness, radius, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha * intensity);
}
