shader_type canvas_item;

uniform vec2 source_scale = vec2(1.0);
uniform vec2 source_origin = vec2(0.0);
uniform float breath = 0.0;
uniform vec2 gesture = vec2(0.0);
uniform float glow = 0.0;
uniform bool spectral = false;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float body = 1.0 - smoothstep(0.05, 0.64, length((UV - vec2(0.52, 0.56)) * vec2(1.5, 1.0)));
	uv = uv * (0.965 - glow * 0.04) - vec2(gesture.x * 0.026 + breath * body * 0.009, gesture.y * 0.028 + breath * body * 0.010);
	vec4 art = texture(TEXTURE, source_origin + (uv + vec2(0.5)) * source_scale);
	float light = pow(max(0.0, 1.0 - length((UV - vec2(0.36, 0.31)) * vec2(1.2, 0.8))), 3.0);
	art.rgb += vec3(0.18, 0.12, 0.06) * light * glow;
	if (spectral) {
		float edge = length((UV - vec2(0.5, 0.42)) * vec2(1.60, 0.80));
		art.a *= 1.0 - smoothstep(0.31, 0.67, edge);
		art.a *= smoothstep(0.0, 0.16, UV.y);
		art.a *= 1.0 - smoothstep(0.56, 0.98, UV.y);
		art.rgb += vec3(0.045, 0.11, 0.15) * (0.65 + glow * 0.35);
	}
	COLOR = art * tint;
}
