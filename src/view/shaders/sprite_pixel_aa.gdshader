shader_type spatial;
// Pokémon sprites (UnitView: material_override of the AnimatedSprite3D). It is the material SpriteBase3D makes for
// itself (BaseMaterial3D.get_material_for_2d: unshaded, both faces, no depth test, alpha blend, billboard keeping the
// node scale, the modulate from the vertex colour in sRGB) but the texture is sampled "sharp bilinear": a texel
// stays a crisp square at any zoom and only the screen pixel across a texel edge is blended. NEAREST at an odd zoom
// (2.3 screen pixels a texel...) draws texels 2 or 3 pixels wide that swap as the sprite moves, breathes or the
// camera turns: the sprite shimmers. This one moves by fractions of a pixel without changing shape.
// SpriteBase3D does not hand its texture to an override: UnitView sets texture_albedo (the sheet of the Pokémon;
// every frame is a region of it, UV are in the sheet).
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, depth_test_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear, repeat_disable;
uniform int billboard_mode = 1; // BaseMaterial3D.BillboardMode: 0 none, 1 enabled, 2 fixed Y

void vertex() {
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92),
				lessThan(COLOR.rgb, vec3(0.04045)));
	}
	if (billboard_mode != 0) {
		if (billboard_mode == 2) {
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
					vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
					vec4(0.0, 1.0, 0.0, 0.0),
					vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
					MODEL_MATRIX[3]);
		} else {
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		}
		// keep the scale of the node (UnitView squashes and stretches the sprite)
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 size = vec2(textureSize(texture_albedo, 0));
	vec2 p = UV * size; // in texels
	vec2 edge = floor(p + 0.5); // the texel edge nearest to this pixel
	vec2 texels_per_pixel = max(fwidth(p), vec2(1e-4));
	// inside a texel: its centre; within half a screen pixel of an edge: the linear blend of the two texels
	vec2 uv = (edge - 0.5 + clamp((p - edge) / texels_per_pixel + 0.5, 0.0, 1.0)) / size;
	vec4 c = texture(texture_albedo, uv) * COLOR;
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
