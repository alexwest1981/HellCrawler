// THE ENEMY'S MATERIAL LAYER (M73): a THIN layer on top of the art, driven by a MASK.
//
// NOTE: the comments in this file are English on purpose. Godot's shader tokenizer stops at a/a/o
// (measured: "SHADER ERROR: Tokenizer: Unknown character"), and then the shader does not compile at
// all -- and because `--headless` never compiles shaders, nothing in the test suite catches it. The
// same trap has hit `ui/dekor.gdshader`: a uniform NAMED `glod` (with a ring over the o) meant no
// props were ever drawn. Keep declaration names ASCII.
//
// WHY A LAYER AND NOT A MATERIAL ON THE FIGURE: a `material_override` on a Sprite3D removes Godot's
// own grid computation (hframes) AND its whole lighting loop. Measured along the way:
//   - override on the figure: the sheet was squeezed into the quad, the figure became a 16 px strip
//     (73 px against 22 641, M59)
//   - a home-made lighting loop in the shader: the figure came out 55 steps darker than with Godot's
//     own material (black silhouette with a single highlight), and even a completely empty pass-through
//     shader differed by 19 445 px from Godot's own -- the lighting model is not worth copying just to
//     get a highlight.
// The layer therefore does NOT touch the figure: it keeps Godot's material, grid, billboard and light
// exactly as before, and the highlight is added on top. If the layer breaks, the figure stays intact.
//
// The frames are cut out of an AtlasTexture (the same frame the figure shows), so the shader needs no
// frame maths of its own: UV is 0..1 over the frame.
//
// The mask channels, the same file format for the generator and for the material editor:
//   R = wet (glossy)   G = metal (mirror)   B = glass (rim light)   A = aura (emission)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D ark : source_color, filter_nearest;
uniform sampler2D mask : source_color, filter_nearest;
uniform vec3 vat_farg : source_color = vec3(0.85, 0.93, 1.0);
uniform vec3 metall_farg : source_color = vec3(0.80, 0.88, 1.0);
uniform vec3 glas_farg : source_color = vec3(0.75, 0.90, 1.0);
// THE AURA (M74): a COLD RIM. It used to be warm (1.0, 0.72, 0.40) and sat as a filled layer over the
// WHOLE body (the mask's band 0.0-1.0): a pale white creature with warm haze over it reads as STEAM.
// Alex: *"Spokena ser ut som de angar, det skall bara vara minimal aura runtom som ger en kansla av
// etheritet"* ("The ghosts look like they are steaming, it should only be a minimal aura around them
// that gives a feeling of ethereality"). A pale cold rim reads as ether.
uniform vec3 aura_farg : source_color = vec3(0.68, 0.80, 1.00);
uniform float aura_vidd = 0.016;     // ring radius as a fraction of the frame (~1.3 texel in an 80 px frame)
uniform float aura_styrka = 0.55;    // measured up, see tools/mat_aura.py: a higher value burns out the rim
uniform float styrka = 1.0;

void vertex() {
	// THE BILLBOARD BELONGS TO THE FIGURE, NOT TO THE SHADER (M79, Alex: *"det blir som en dubbel, vit
	// fiende"* -- "it becomes like a double, white enemy").
	//
	// The line that used to sit here was Godot's own recipe from the documentation:
	//
	//     MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
	//                                           INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	//
	// It faces the layer's basis towards the camera but DROPS the model's scale, so the layer ended up
	// offset and slightly mis-scaled against the figure -- measured as a pale double over the enemy.
	// The layer is a CHILD of the figure and now has `BILLBOARD_ENABLED` just like it (set in
	// `_fiende_lager`), so the two quads land on top of each other with no maths of their own.
}

void fragment() {
	vec4 konst = texture(ark, UV);
	vec4 m = texture(mask, UV);
	// The layer follows the art's silhouette: no highlight on transparent frames.
	float yta = konst.a;
	// Glass is a rim light along the silhouette, water a soft sheen, metal a tight and cold one.
	// The numbers were toned down after measuring: the bands cover the WHOLE body (the generator's mask
	// is a band, not a painted surface), and 0.75 all over made the figure TWICE as bright (mean 159
	// against 75) -- a full-body halo, not a highlight. A mask painted in the editor puts the sheen on
	// the shoulder instead.
	float kant = pow(1.0 - abs(UV.x - 0.5) * 2.0, 1.5);
	vec3 farg = vat_farg * m.r * 0.30
		+ metall_farg * m.g * 0.32
		+ glas_farg * m.b * kant * 0.70;
	// THE AURA (M74): a RIM along the silhouette, not a fill over the body.
	// The mask's A says WHERE the aura may sit (the band), and the rim comes from how BLENDED a ring of
	// samples around the pixel is: fully inside the silhouette = 1 (no aura), half inside (on the edge
	// itself) = 0, fully outside = 0. Sampling ONLY your own pixel is not enough -- then the whole band
	// becomes a fill, and that was exactly what Alex saw ("the ghosts look like they are steaming").
	// The branch costs nothing for an enemy without an aura: m.a is 0 everywhere and the ring is skipped.
	float aura = 0.0;
	if (m.a > 0.004) {
		float nara = 0.0;
		for (int i = 0; i < 8; i++) {
			float v = float(i) * 0.7853981634;
			nara += textureLod(ark, UV + vec2(cos(v), sin(v)) * aura_vidd, 0.0).a;
		}
		float kantighet = clamp(1.0 - abs(2.0 * (nara * 0.125) - 1.0), 0.0, 1.0);
		aura = kantighet * clamp(m.a * 2.0, 0.0, 1.0);
	}
	ALBEDO = (farg + aura_farg * aura * aura_styrka) * styrka * yta;
	ALPHA = 1.0;
}
