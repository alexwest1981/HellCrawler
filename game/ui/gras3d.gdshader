shader_type spatial;
// KIT-GRÄSET (Quaternius Stylized Nature MegaKit, CC0): blad som GEOMETRI, inte som billboard.
//
// VARFÖR DEN HÄR FINNS VID SIDAN AV `dekor.gdshader`: den shadern bygger en billboard (MODELVIEW ur
// INV_VIEW_MATRIX), alltså en platt lapp som alltid vänder sig mot kameran. Det fungerar för en tuva
// ritad i 2D, men kitets gräs är 166 riktiga blad — och då är det HELA poängen att bladen står i
// världen och syns från sidan när kameran tippar 30°. Här rörs bara vertexen; basen står still.
//
// SVENSKNINGEN: källan är mörk och len (målad textur, 737 färger). Filter NEAREST + palett- och
// kvantisering sker i `tools/gen_gras_kit.py` — shadern antar att texturen redan är pixelkonst.
render_mode cull_disabled, depth_draw_opaque, specular_disabled, diffuse_lambert_wrap;

uniform sampler2D textur : source_color, filter_nearest, repeat_disable;
uniform float vind : hint_range(0.0, 4.0) = 1.1;
uniform float svep : hint_range(0.0, 0.4) = 0.10;   // meter vid toppen
uniform float hojd = 1.9;                            // källans egen höjd (mätt ur glTF: 1,84)

void vertex() {
	float t = clamp(VERTEX.y / hojd, 0.0, 1.0);
	float fas = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
	// Toppen svajar, roten står still — samma princip som dekor.gdshader.
	VERTEX.x += sin(TIME * vind + fas) * svep * t * t;
	VERTEX.z += cos(TIME * vind * 0.87 + fas) * svep * 0.6 * t * t;
}

void fragment() {
	// COLOR är kitets egna vertexfärger: de bär variationen mellan blad (källans textur är en rand).
	vec4 c = texture(textur, UV) * COLOR;
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
