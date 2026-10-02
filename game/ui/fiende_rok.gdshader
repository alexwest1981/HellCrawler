// Per-enemy smoke shader (wish list item 13, "fienderna far egna shaders").
//
// This is the OVERRIDE path: an enemy may name its own shader in the bestiary
// (`shader` field). The default is "no shader" — no overlay layer is added and
// the figure renders byte-identical to Godot's own material. Only an enemy that
// actually names a shader gets this layer, drawn ON TOP of its own sprite.
//
// The pixel art is untouched: the shader samples the same enemy sheet and only
// ADDS a soft, translucent veil. It does not redraw the figure.
//
// Effect: smoke. The silhouette's alpha is dilated outward (the max of 8
// neighbours) so the veil bleeds a soft fringe JUST OUTSIDE the contour, and it
// sits as a translucent, desaturated haze over the body. Measurable: pixels
// whose source alpha is transparent but whose dilated alpha is opaque = pixels
// outside the silhouette's contour.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D ark : source_color, filter_nearest;
uniform vec3 rok_farg : source_color = vec3(0.62, 0.60, 0.58);
uniform float rok_vidd = 0.02;     // bleed radius in UV (fraction of the frame)
uniform float rok_alfa = 0.40;     // translucency of the veil
uniform float rok_styrka = 1.0;

void fragment() {
	vec4 konst = texture(ark, UV);
	// Dilated silhouette: the strongest neighbour decides how far the smoke bleeds.
	float bred = 0.0;
	for (int i = 0; i < 8; i++) {
		float v = float(i) * 0.7853981634;
		bred = max(bred, texture(ark, UV + vec2(cos(v), sin(v)) * rok_vidd).a);
	}
	// The veil is strongest just outside the contour (konst.a ~ 0, bred ~ 1) and
	// fades to a thin haze over the body.
	float dens = clamp(bred - konst.a * 0.5, 0.0, 1.0) * rok_styrka;
	ALBEDO = rok_farg * dens;
	ALPHA = dens * rok_alfa;
}
