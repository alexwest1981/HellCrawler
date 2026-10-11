shader_type spatial;
// THE DECORATION (M84): grass, roots, moss and pebbles in the million. Alex: *"saker i miljon som
// inte skall ha nagon collision, men bidrar till mer... kansla"* ("little things in the millions that
// should have no collision, but add more... feel").
//
// THE GRASS DOES NOT GLOW BY ITSELF: render_mode is not `unshaded`. The room is dark and the lantern
// in your hand is what lights it (DECISION 007), so a tuft must fall into shadow when the light turns
// away -- otherwise it glows like a decal in the dark. The albedo is texture, no emission.
//
// THE GLOW (glod > 0) is the exception to that rule and applies to fire only: a candelabra and a
// crack in the floor with fire in it are LIGHT SOURCES, and in the reference (One More Dungeon) those
// are exactly what you see far away in the dark -- mushrooms, symbols and cauldrons that glow.
// Measured: 71 props + 24 real lights on a 50x50 floor still did not show up in the view, because one
// light reaches 4.5 m; a glowing sheet shows at any distance and costs nothing. The glow does not
// light the room (the lights do), it shows WHERE the light is.
//
// THE BILLBOARD is the same recipe as the enemy layer: the basis comes from the inverted view and the
// model's own translation is kept. It drops the model's scale, which does not matter here -- every
// instance is a QuadMesh in its own size.
//
// THE WIND: the tip sways, the root stands still. The swing is drawn from the world position
// (MODEL_MATRIX[3]) instead of INSTANCE_CUSTOM, so no per-instance data has to be pushed in.
render_mode cull_disabled, depth_draw_opaque, shadows_disabled, specular_disabled;

uniform sampler2D textur : source_color, filter_nearest, repeat_disable;
uniform float svep : hint_range(0.0, 0.08) = 0.012;
uniform float vind : hint_range(0.0, 4.0) = 1.4;
// The glow: floor decor has 0 (the albedo is texture, no emission), fire has a value above 1 so it
// shows at a distance in the dark.
uniform float glod : hint_range(0.0, 8.0) = 0.0;

void vertex() {
	// The per-instance scale is kept: the length of the basis axes is the instance's scale (M79 -- drop
	// it and the layer is drawn in a different size than the figure). The position comes from
	// MODEL_MATRIX[3].
	vec3 skala = vec3(length(MODEL_MATRIX[0]), length(MODEL_MATRIX[1]), length(MODEL_MATRIX[2]));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * skala.x, INV_VIEW_MATRIX[1] * skala.y,
		INV_VIEW_MATRIX[2] * skala.z, MODEL_MATRIX[3]);
	float fas = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
	VERTEX.x += sin(TIME * vind + fas) * svep * UV.y * UV.y;
}

void fragment() {
	vec4 c = texture(textur, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	EMISSION = c.rgb * glod;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
