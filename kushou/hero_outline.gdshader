shader_type canvas_item;

varying vec4 actor_tint;

void vertex() {
	actor_tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE * 1.4;
	float outline = max(texture(TEXTURE, UV + vec2(texel.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(texel.x, 0.0)).a);
	outline = max(outline, texture(TEXTURE, UV + vec2(0.0, texel.y)).a);
	outline = max(outline, texture(TEXTURE, UV - vec2(0.0, texel.y)).a);
	float rim = outline * (1.0 - art.a) * 0.84;
	float alpha = art.a + rim;
	vec3 gold = vec3(1.0, 0.81, 0.43);
	vec3 rgb = (art.rgb * art.a + gold * rim) / max(alpha, 0.001);
	COLOR = vec4(rgb, alpha) * actor_tint;
}

