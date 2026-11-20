shader_type spatial;
render_mode unshaded, cull_disabled;

// Painted battle board, seen through the 3D camera (the "2D ground faking 3D" look): a field of
// pointy-top hexagons (BattleBoard: odd rows shifted half a cell to the right) with a Poké Ball painted
// in the middle, thin lines between the cells, the bench slots and the cell highlights, all in this one
// shader; Arena.gd feeds the highlight / hole textures.
//
// 1 cell = cell_size world units = the width of a hexagon. Board coordinates b (like BattleBoard.center):
// x to the right, y toward the enemy (world -z); the board centre is the world origin.
//   board  |x| <= half width, |z| <= half depth (the points of the first / last rows)
//   bench  z in [half depth + bench_gap, + bench_rows * bench_slot] (rows of 8 square slots)

uniform float cell_size = 1.0;
uniform vec2 board_size = vec2(7.0, 8.0); // columns, rows
uniform float bench_gap = 0.4;
uniform int bench_rows = 1;
uniform float bench_slot = 0.9375;
uniform float rim_margin = 0.3;
// 8 x (board rows + bench_rows) texels: texel (x, y) = board cell (x, y), then the bench rows (x = slot).
// rgb = colour, a = strength.
uniform sampler2D highlight_tex : filter_nearest, repeat_disable;
// same texels as highlight_tex: r = depth of the Ground hole of the cell (0 = none, 1 = deepest).
uniform sampler2D hole_tex : filter_nearest, repeat_disable;
uniform float time_offset = 0.0;

uniform vec4 stone_light : source_color = vec4(0.80, 0.72, 0.57, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.74, 0.66, 0.52, 1.0);
uniform vec4 player_tint : source_color = vec4(0.30, 0.52, 0.95, 1.0);
uniform vec4 enemy_tint : source_color = vec4(0.95, 0.38, 0.32, 1.0);
uniform float side_tint : hint_range(0.0, 1.0) = 0.12;
uniform float paint_noise : hint_range(0.0, 1.0) = 0.16;
// lines between the cells: thin and faint (at least one floor pixel wide)
uniform bool show_grid = true;
uniform vec4 grid_color : source_color = vec4(0.12, 0.08, 0.06, 1.0);
uniform float grid_strength : hint_range(0.0, 1.0) = 0.22;
uniform float grid_width : hint_range(0.0, 0.2) = 0.03;
// white paint: the line between the two halves (along the cells) and the circle around the ball
uniform vec4 field_line_color : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform float field_line_strength : hint_range(0.0, 1.0) = 0.7;
// the Poké Ball in the middle (radius in cells); an image replaces the drawn one when given
uniform float ball_radius = 2.35;
uniform float ball_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec4 ball_red : source_color = vec4(0.86, 0.2, 0.18, 1.0);
uniform vec4 ball_white : source_color = vec4(0.97, 0.96, 0.93, 1.0);
uniform vec4 ball_black : source_color = vec4(0.13, 0.12, 0.14, 1.0);
uniform bool use_ball_tex = false;
uniform sampler2D ball_tex : source_color, filter_linear, repeat_disable;
uniform vec4 bench_color : source_color = vec4(0.55, 0.47, 0.38, 1.0);
uniform vec4 rim_color : source_color = vec4(0.36, 0.30, 0.26, 1.0);
// > 0: snap the painting to a pixel grid (pixels per cell) so the floor looks
// like pixel art of the same density as the PMD sprites. 0 = smooth.
uniform float pixel_density = 0.0;

const float ROW = 0.8660254; // distance between two rows, in cells

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
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Axial (q, r) of the hexagon containing fractional axial coordinates (cube rounding), as whole floats.
vec2 hex_round(vec2 qr) {
	vec3 c = vec3(qr.x, qr.y, -qr.x - qr.y);
	vec3 r = floor(c + 0.5);
	vec3 d = abs(r - c);
	if (d.x > d.y && d.x > d.z) {
		r.x = -r.y - r.z;
	} else if (d.y > d.z) {
		r.y = -r.x - r.z;
	}
	return r.xy;
}

// 0 at the centre of a hexagon one cell wide, 0.5 on its sides.
float hex_metric(vec2 d) {
	vec2 a = abs(d);
	return max(a.x, a.x * 0.5 + a.y * ROW);
}

// 1 within `w` of a border at distance `dist`, fading out over half a floor pixel.
float line_mask(float dist, float w, float px) {
	return 1.0 - smoothstep(w, w + px * 0.5, dist);
}

// The painted Poké Ball; o = from the board centre, in cells (y toward the enemy: the red half).
vec3 apply_ball(vec3 col, vec2 o) {
	float R = ball_radius;
	float r = length(o);
	if (r > R + 0.4) {
		return col;
	}
	vec4 paint = vec4(0.0);
	if (use_ball_tex) {
		paint = texture(ball_tex, vec2(o.x, -o.y) / (2.0 * R) + 0.5);
	} else {
		vec3 c = o.y > 0.0 ? ball_red.rgb : ball_white.rgb;
		// a soft shine on the red half, a shade at the bottom of the white one
		float shine = 1.0 - step(0.2 * R, length((o - vec2(-0.45, 0.5) * R) * vec2(1.0, 1.6)));
		c = mix(c, ball_white.rgb, 0.35 * shine * step(0.0, o.y));
		c *= 1.0 - 0.12 * step(0.0, -o.y) * smoothstep(0.55 * R, R, length(o - vec2(0.15, 0.1) * R));
		c = mix(c, ball_black.rgb, step(abs(o.y), 0.13 * R / 2.35));             // band
		c = mix(c, ball_black.rgb, step(r, 0.27 * R));                            // button ring
		c = mix(c, ball_white.rgb, step(r, 0.2 * R));                             // button
		c = mix(c, mix(ball_white.rgb, ball_black.rgb, 0.3), step(abs(r - 0.12 * R), 0.015 * R));
		c = mix(c, ball_black.rgb, step(R - 0.09, r));                            // outline
		paint = vec4(c, step(r, R));
	}
	col = mix(col, paint.rgb, paint.a * ball_strength);
	// white circle around it, like the centre circle of a field
	float ring = step(abs(r - (R + 0.2)), 0.045);
	return mix(col, field_line_color.rgb, ring * field_line_strength);
}

// Ground hole: a pit of dug earth under the Pokémon, wider and darker the deeper it is.
vec3 apply_hole(vec3 col, vec2 texel, vec2 d) {
	float depth = texture(hole_tex, (texel + 0.5) / vec2(8.0, board_size.y + float(bench_rows))).r;
	if (depth <= 0.001) {
		return col;
	}
	float dist = length(d);
	float radius = 0.16 + 0.26 * depth;
	float pit = 1.0 - smoothstep(radius - 0.04, radius, dist);
	float rim = clamp((1.0 - smoothstep(radius, radius + 0.05, dist)) - pit, 0.0, 1.0);
	vec3 dirt = vec3(0.47, 0.34, 0.2);
	vec3 dark = mix(vec3(0.26, 0.16, 0.09), vec3(0.06, 0.035, 0.02), depth);
	dark *= 0.65 + 0.35 * smoothstep(0.0, radius, dist);
	col = mix(col, dirt, rim * 0.85);
	return mix(col, dark, pit * 0.92);
}

vec4 highlight_of(vec2 texel) {
	return texture(highlight_tex, (texel + 0.5) / vec2(8.0, board_size.y + float(bench_rows)));
}

// Highlight of a cell shaped like the cell: `edge` = distance to its sides (in cells).
vec3 apply_highlight(vec3 col, vec4 h, float edge, float px) {
	if (h.a <= 0.001) {
		return col;
	}
	float pulse = 0.85 + 0.15 * sin(TIME * 5.0 + time_offset);
	float fill = 1.0 - line_mask(edge, 0.05, px);
	float border = fill * line_mask(edge, 0.11, px);
	col = mix(col, h.rgb, h.a * fill * 0.45 * pulse);
	return mix(col, mix(h.rgb, vec3(1.0), 0.35), h.a * border);
}

void fragment() {
	vec2 p = world_pos.xz / cell_size; // in cells, z grows toward the camera
	if (pixel_density > 0.0) {
		p = (floor(p * pixel_density) + 0.5) / pixel_density;
	}
	float px = pixel_density > 0.0 ? 1.0 / pixel_density : 0.02; // one floor pixel, in cells
	vec2 centre = vec2((board_size.x - 0.5) * 0.5, (board_size.y - 1.0) * 0.5 * ROW);
	float half_w = (board_size.x + 0.5) * 0.5;
	float half_d = centre.y + 0.57735027;
	vec2 b = vec2(p.x, -p.y) + centre;
	float rr = b.y / ROW;
	vec2 ax = hex_round(vec2(b.x - rr * 0.5, rr));
	float row = ax.y;
	float odd = mod(row, 2.0); // 1 on the rows shifted to the right
	float column = ax.x + (row - odd) * 0.5;
	float bench_x = (p.x + half_w) / bench_slot;
	float bench_z = (p.y - half_d - bench_gap) / bench_slot;
	float line_w = max(grid_width * 0.5, px * 0.5);
	vec3 col;

	if (column > -0.5 && column < board_size.x - 0.5 && row > -0.5 && row < board_size.y - 0.5) {
		vec2 cell_centre = vec2(column + 0.5 * odd, row * ROW);
		vec2 d = b - cell_centre;
		float edge = 0.5 - hex_metric(d);
		// 3 clay shades, no two neighbours alike ((q - r) mod 3), tinted toward the team of the side
		float shade = mod(ax.x - ax.y, 3.0) * 0.5;
		col = mix(stone_light.rgb, stone_dark.rgb, shade);
		float side_rows = board_size.y * 0.5;
		col = mix(col, row < side_rows - 0.5 ? player_tint.rgb : enemy_tint.rgb, side_tint);
		col *= 1.0 + (fbm(b * 2.3) - 0.5) * paint_noise;
		col = apply_ball(col, b - centre);
		if (show_grid) {
			col = mix(col, grid_color.rgb, grid_strength * line_mask(edge, line_w, px));
		}
		// the line between the two halves runs along the sides of the front rows
		float slant = 0.5 - (abs(d.x) * 0.5 + abs(d.y) * ROW);
		bool toward_other_half = (abs(row - (side_rows - 1.0)) < 0.5 && d.y > 0.0) || (abs(row - side_rows) < 0.5 && d.y < 0.0);
		if (toward_other_half && slant <= edge + 1e-4) {
			col = mix(col, field_line_color.rgb, field_line_strength * line_mask(slant, line_w * 1.6, px));
		}
		vec2 texel = vec2(column, row);
		col = apply_hole(col, texel, d);
		col = apply_highlight(col, highlight_of(texel), edge, px);
	} else if (bench_x >= 0.0 && bench_x < 8.0 && bench_z >= 0.0 && bench_z < float(bench_rows)) {
		vec2 texel = vec2(floor(bench_x), board_size.y + floor(bench_z));
		vec2 f = vec2(fract(bench_x), fract(bench_z));
		col = bench_color.rgb * (1.0 + (hash21(texel + 3.1) - 0.5) * 0.08);
		col *= 1.0 + (fbm((texel + f) * 2.7) - 0.5) * paint_noise;
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * bench_slot;
		if (show_grid) {
			col = mix(col, grid_color.rgb, grid_strength * line_mask(edge, line_w, px));
		}
		col = apply_highlight(col, highlight_of(texel), edge, px);
	} else {
		// platform rim around the board and between board and bench
		float n = fbm(p * 1.7);
		col = rim_color.rgb * (0.85 + n * 0.3);
		float edge_x = half_w + rim_margin - abs(p.x);
		float edge_z = min(p.y + half_d + rim_margin,
			half_d + bench_gap + float(bench_rows) * bench_slot + rim_margin - p.y);
		col *= 0.75 + 0.25 * smoothstep(0.0, rim_margin * 0.8, min(edge_x, edge_z));
	}
	ALBEDO = col;
}
