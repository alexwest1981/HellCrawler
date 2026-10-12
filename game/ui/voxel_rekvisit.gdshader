// BARA LÅGORNA LYSR (M115).
//
// Alex: *"dessutom 'lyser' hela kandelabern i taket, inte toppen på ljusen som jag bad om"* — emissionen
// satt på HELA modellen (ett material för alla celler), och då glödde metall, kedja, armar och stake med.
//
// Cellernas egen färg finns i vertexfärgen (modellen byggs ur arkets pixlar, `Voxel.ur_ark`), så en
// färgregel räcker: lågorna ritas i palettens 12/13/14 (EMBER, FLAME, GLOW i `tools/gen_props.py:_låga`)
// och de är de enda VARMA, LJUSA cellerna i en kandelaber. Regeln prövas i linjärt rum (Godot räknar om
// vertexfärgen), alltså på förhållanden och inte på exakta tal — då tål den att paletten justeras.
//
// Namnen är ASCII med flit: Godots shadertokenizer stannar på å/ä/ö (mätt i `voxel_fiende.gdshader`), och
// `--headless` kompilerar aldrig shaders, så sviten hade inte fångat det.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform float glod : hint_range(0.0, 1.0) = 0.06;   // samma faktor som `_fladdra` rör (LAGA_GLÖD * _ljus_f)

// Är cellen en låga? Varm och ljus nog — metall (mörk), vax (grå) och trä faller utanför.
float ar_laga(vec3 c) {
	float varm = step(c.b * 1.8, c.r);            // röd/orange: r klart över blå
	float gul = step(c.b * 1.2, c.g);             // och grön över blå (annars är det bara rött)
	float ljus = step(0.45, c.r);                 // trä och järn i korridoren ligger långt under
	return varm * gul * ljus;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	EMISSION = COLOR.rgb * (glod * ar_laga(COLOR.rgb));
}
