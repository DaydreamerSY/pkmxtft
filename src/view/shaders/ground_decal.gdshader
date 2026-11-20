shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Flat quad on the ground under a Pokémon: a soft blob shadow plus an optional
// team ring, both centred on the cell the Pokémon occupies.

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.42);
uniform vec4 ring_color : source_color = vec4(0.3, 0.6, 1.0, 0.0);
uniform float ring_radius = 0.82;
uniform float ring_width = 0.08;

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float shadow = shadow_color.a * (1.0 - smoothstep(0.25, 0.62, r));
	float ring = ring_color.a * (1.0 - smoothstep(ring_width * 0.5, ring_width, abs(r - ring_radius)));
	float a = max(shadow, ring);
	ALBEDO = mix(shadow_color.rgb, ring_color.rgb, ring / max(a, 0.001));
	ALPHA = a;
}
