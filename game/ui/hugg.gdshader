// The slash. Alex linked procedural-cyclic-slash for the attack: "Vid attack, men behöver fler
// liknande denna, så det blir variation".
//
// PROCEDURAL: there is no texture here. The arc is a ring in polar coordinates on the quad, and a hot
// leading edge sweeps through it — which is what the reference does, and what makes variation cheap:
// four numbers (angle, direction, radius, span) are drawn at random for every hit, so no two slashes
// look the same without a single new file in assets/.
//
// The idea and the recipe come from godotshaders.com ("Procedural cyclic slash"); this file is our own
// writing of it. ASCII only in names: the Godot tokenizer stops at a-ring/a-umlaut/o-umlaut.

shader_type spatial;
// Additive and unshaded: a slash is light, not a surface. depth_draw_never keeps it from cutting into
// the figure it passes over, and cull_disabled lets it be seen from either side of the quad.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fram : hint_range(0.0, 1.0) = 0.0;        // 0 = the sweep has not started, 1 = done
uniform float vinkel = 0.0;                             // the arc's roll on the quad, radians
uniform float riktning = 1.0;                           // +1 one way, -1 the other
uniform float radie : hint_range(0.10, 0.80) = 0.46;    // the arc's radius, in quad units
uniform float svep : hint_range(1.0, 6.2) = 2.3;        // how much of the circle the arc spans
uniform float bredd : hint_range(0.01, 0.30) = 0.11;    // the band's thickness
uniform vec3 glod : source_color = vec3(1.0, 0.88, 0.66);
uniform vec3 kant_glod : source_color = vec3(1.0, 1.0, 0.94);
uniform float styrka : hint_range(0.0, 3.0) = 1.7;

// The quad always faces the camera, the same thing Sprite3D does for the figures. Without it the slash
// would be a flat plane in the world and read as a pane of glass from most angles.
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	// The arc's centre sits at the FEET, with a radius that reaches the chest: what shows on the quad
	// is then the top of the ring — a shallow arc across the body, which is a slash. (Centred in the
	// quad it painted a halo around the head, which is not a slash; seen in a render and corrected.)
	vec2 p = UV - vec2(0.5, 0.88);
	float c = cos(vinkel);
	float s = sin(vinkel);
	p = mat2(vec2(c, -s), vec2(s, c)) * p;

	float r = length(p);
	// The angle is measured from the TOP of the ring, not from the 3 o'clock direction. The centre sits
	// at the feet, so "up" is the chest — and an arc parameted from a = 0 starts at the corner of the
	// quad, off the body, where nothing is seen (measured: two renders showed no slash at all while the
	// code was "correct"). vinkel turns the whole ring, which is what makes the slash diagonal.
	float a = atan(p.y, p.x) * riktning;
	a += 1.5707963;
	while (a > 3.1415927) { a -= TAU; }
	while (a < -3.1415927) { a += TAU; }
	// t = where along the arc this pixel sits: 0 at one end, 1 at the other end of the sweep.
	float t = clamp((a + svep * 0.5) / svep, 0.0, 1.0);

	// The band around the radius, and the part the head has already passed.
	float band = smoothstep(bredd, 0.0, abs(r - radie) * 2.6);
	float nast = step(t, fram);
	// The hot leading edge: white at the head, the warm glow behind it.
	float huvud = 1.0 - smoothstep(0.0, 0.18, fram - t);
	// And the whole thing dies out at the end instead of blinking off.
	float liv = 1.0 - smoothstep(0.70, 1.0, fram);

	// The tail is not dim: measured in a render, a faint tail left only the head's handful of saturated
	// pixels visible and the sweep read as a dot. 0,45 keeps the whole arc readable while the head
	// (1,05 on top) is still the brightest part.
	float k = band * nast * liv * (0.45 + 1.05 * huvud) * styrka;
	ALBEDO = mix(glod, kant_glod, huvud) * k;
	ALPHA = 1.0;                       // additive: the intensity lives in ALBEDO
}
