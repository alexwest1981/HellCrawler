// The card's own effects, in ONE overlay on top of the card.
//
// Idea and recipe from godotshaders.com: "2d Burn/dissolve from point" by DimensionAlmios (enekoassets)
// and "Highlight Shader (Good version)" by oLe Studios. This file is our own writing of both — the
// pages' own licence could not be read from the HTML, so the credit stands in full: keep their names
// here if the file is ever reused elsewhere.
//
// Alex wanted two things from the shaders he sent: a shine when the pointer is over a card
// ("highlight-shader-good-version" — a mild version), and the card burning away when it is used
// ("2d-burn-dissolve-from-point"). Both live here, and they are drawn by a single node sitting ON TOP
// of the card.
//
// WHY AN OVERLAY AND NOT A MATERIAL ON THE CARD'S PARTS: a card is a tree (banner, icon, name, effect
// text). A canvas shader runs per draw call, and UV is that part's own rect — a burning spot would land
// in a different place on every part. One node over the whole card gets one coordinate system.
//
// NO SCREEN TEXTURE (changed 11/10 after Alex's screenshot). The first version read SCREEN_TEXTURE —
// everything drawn under the overlay, which IS the card — and dissolved that. In a render here it
// looked right; in Alex's window the same card came out with a white frame and a PITCH BLACK inside:
// a screen copy that resolves to black in his viewport/canvas setup, and the overlay is opaque, so it
// painted the card out. A screen texture also costs a full copied frame every time it is drawn, and its
// coordinates depend on the canvas transform — the effect must not depend on either. The overlay now
// draws its OWN light and its OWN burn, needs nothing underneath it, and is transparent where nothing
// happens. Fewer uniforms, no backbuffer copy, and no way for a window size to turn a card black.
//
// ASCII only: the Godot tokenizer stops at a-ring/a-umlaut/o-umlaut in a NAME, and headless never
// compiles shaders — a broken shader would only show in a render run.

shader_type canvas_item;

uniform vec2 storlek = vec2(130.0, 180.0);        // the overlay's own size in px (the card's size)

// THE SHINE (hover): a light band that follows the pointer.
uniform float glans : hint_range(0.0, 1.0) = 0.0;
uniform vec2 glans_pos = vec2(65.0, 90.0);        // pointer, in the overlay's own px
uniform float glans_vidd : hint_range(1.0, 60.0) = 12.0;
// MILD (Alex ville ha "en mild version"): 0,30 mot nästan vitt tvättade kortet och lästes som
// genomskinlighet — precis det han inte vill ha. 0,14 är en glimt, inte en slöja, och tonen är
// papperets egen varma ton i stället för vitt.
uniform float glans_styrka : hint_range(0.0, 1.0) = 0.14;

// THE BURN (played): a noise-driven dissolve from the point where the card was clicked.
uniform float brand : hint_range(0.0, 1.2) = 0.0; // 0 = whole card, >= 1 = gone
uniform vec2 brand_punkt = vec2(65.0, 90.0);      // the click, in the overlay's own px
uniform float brand_kant : hint_range(0.0, 30.0) = 7.0;
uniform vec3 brand_glod : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 brand_aska : source_color = vec3(0.05, 0.03, 0.03);

float slump(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Value noise: cheap, and the card is 130x180 px, so two octaves read as a torn edge.
float brus(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = slump(i);
	float b = slump(i + vec2(1.0, 0.0));
	float c = slump(i + vec2(0.0, 1.0));
	float d = slump(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = UV * storlek;
	// The overlay starts EMPTY: nothing is drawn unless something happens. It never needs to know what
	// the card looks like underneath — the burn covers it with ash, the shine adds light to it.
	vec3 rgb = vec3(0.0);
	float alfa = 0.0;

	if (glans > 0.001) {
		// A diagonal band: the band's own axis is turned 45 degrees, so the light sweeps like a
		// reflection over a glossy surface instead of a vertical stripe.
		float axel = (p.x * 0.7 + p.y * 0.7);
		float mal = (glans_pos.x * 0.7 + glans_pos.y * 0.7);
		float band = 1.0 - smoothstep(0.0, glans_vidd, abs(axel - mal));
		if (band > 0.0) {
			// The palette's own warm highlight, added as light: the card keeps its colours, it is
			// only brighter where the band passes.
			rgb = mix(rgb, vec3(0.92, 0.90, 0.82), band);
			alfa = max(alfa, band * glans_styrka * glans);
		}
	}

	if (brand > 0.001) {
		float n = brus(p * 0.07) * 0.6 + brus(p * 0.16) * 0.4;
		float d = distance(p, brand_punkt) + (n - 0.5) * 22.0;
		float radie = brand * max(storlek.x, storlek.y) * 1.15;
		if (d < radie) {
			// Burnt away. ASH, not a hole with alpha 0: the overlay sits ON the card, so a transparent
			// spot would simply show the card again and nothing would look burnt.
			rgb = brand_aska;
			alfa = 1.0;
		} else if (d < radie + brand_kant + n * 7.0) {
			rgb = brand_glod;                              // the glowing edge of the burn
			alfa = max(alfa, 0.85);
		}
	}

	COLOR = vec4(rgb, clamp(alfa, 0.0, 1.0));
}
