shader_type spatial;
render_mode unshaded, cull_disabled;

// Painted ground around the arena (Don't Starve style: flat 2D painting on the
// ground plane). A soft dark band around the platform fakes its height.

uniform vec4 grass_a : source_color = vec4(0.30, 0.42, 0.24, 1.0);
uniform vec4 grass_b : source_color = vec4(0.22, 0.33, 0.19, 1.0);
uniform vec4 dirt : source_color = vec4(0.42, 0.34, 0.24, 1.0);
uniform vec4 ink : source_color = vec4(0.08, 0.07, 0.06, 1.0);
uniform float scale = 0.45;
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.35;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
// platform half size in world units (x, z) and its centre z, for the contact shadow
uniform vec2 platform_half = vec2(4.35, 4.1);
uniform float platform_center_z = 0.72;
uniform float contact_shadow : hint_range(0.0, 1.0) = 0.55;
// > 0: snap to a pixel grid (pixels per world unit), see board.gdshader
uniform float pixel_density = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 wp = world_pos.xz;
	if (pixel_density > 0.0) {
		wp = (floor(wp * pixel_density) + 0.5) / pixel_density;
	}
	vec2 p = wp * scale;
	float n = fbm(p);
	vec3 col = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.35, 0.65, n));
	// posterised dirt patches, like painted blobs
	float d = fbm(p * 0.6 + 17.0);
	col = mix(col, dirt.rgb, step(1.0 - dirt_amount * 0.6, d) * 0.85);
	// short grass strokes
	float strokes = vnoise(vec2(p.x * 9.0, p.y * 2.2));
	col *= 0.9 + strokes * 0.2;
	// small dark flowers / pebbles
	float speck = step(0.992, hash21(floor(wp * 6.0)));
	col = mix(col, ink.rgb, speck * 0.25);
	// contact shadow around the platform
	vec2 q = abs(wp - vec2(0.0, platform_center_z)) - platform_half;
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	col *= 1.0 - contact_shadow * (1.0 - smoothstep(0.0, 1.2, dist));
	// vignette far from the board
	float r = length(wp * vec2(0.09, 0.12));
	col *= 1.0 - vignette * smoothstep(0.6, 1.4, r);
	ALBEDO = col;
}
